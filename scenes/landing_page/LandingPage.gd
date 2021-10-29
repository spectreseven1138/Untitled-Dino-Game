extends Node

var game: Game

onready var host_server_button: NinePatchRectTextureButton = $Control/VSplitContainer/HSplitContainer/PlayerSelector/MarginContainer/HBoxContainer/MarginContainer2/VBoxContainer/HostServerButton
onready var join_server_button: NinePatchRectTextureButton = $Control/VSplitContainer/HSplitContainer/PlayerSelector/MarginContainer/HBoxContainer/MarginContainer2/VBoxContainer/JoinServerButton
onready var player_selector: PlayerSelector = $Control/VSplitContainer/HSplitContainer/PlayerSelector
var confirmationdialog_accept_button: Button

func init(_game: Game):
	game = _game
	$Control/VSplitContainer/HSplitContainer/Scoreboard.init(game)

func _ready():
	$Control/ConfirmationDialog.get_ok().visible = false
	$Control/ConfirmationDialog.get_cancel().visible = false
	$Control/ConfirmationDialog.get_close_button().visible = false
	
	confirmationdialog_accept_button = $Control/ConfirmationDialog.add_button("Join", true, "accept")
	$Control/ConfirmationDialog.add_button("Cancel", false, "cancel")
	
	yield(get_tree().create_timer(0.5), "timeout")
	game.connect_to_server(false, Game.DEFAULT_PORT, Game.DEFAULT_SERVER)

func get_local_ips() -> Array:
	var ret: Array = []
	
	for address in IP.get_local_addresses():
		if ":" in address:
			continue
		elif address == "127.0.0.1":
			continue
		ret.append(address)
	
	return ret

func _on_HostServerButton_pressed():
	if game.is_server:
		
		var addresses: String = ""
		for ip in get_local_ips():
			addresses += ip + ", \n"
		
		$Control/AcceptDialog.dialog_text = "Address(es): " + addresses.trim_suffix(", \n") + "\n\nPort: " + str(game.server_info["port"])
		$Control/AcceptDialog.window_title = "Already hosting server"
		$Control/AcceptDialog.popup_centered()
	else:
		
		$Control/ConfirmationDialog/VBoxContainer/IpLineEdit.visible = false
		$Control/ConfirmationDialog/VBoxContainer/PortLineEdit.text = str(Game.DEFAULT_PORT)
		$Control/ConfirmationDialog.window_title = "Input server details"
		confirmationdialog_accept_button.text = "Host"
		$Control/ConfirmationDialog.popup_centered()
		
		var action: String = yield($Control/ConfirmationDialog, "custom_action")
		$Control/ConfirmationDialog.visible = false
		
		if action == "accept":
			var port_text: String = $Control/ConfirmationDialog/VBoxContainer/PortLineEdit.text
			if not port_text.is_valid_integer() or int(port_text) < 0 or int(port_text) > 65535:
				$Control/AcceptDialog.window_title = "Couldn't host sever"
				$Control/AcceptDialog.dialog_text = "Port must be a valid integer between 0 and 65535"
				$Control/AcceptDialog.popup_centered()
			else:
				game.connect_to_server(true, int(port_text))

func _on_JoinServerButton_pressed():
	
	$Control/ConfirmationDialog/VBoxContainer/IpLineEdit.visible = true
	$Control/ConfirmationDialog/VBoxContainer/PortLineEdit.visible = true
	$Control/ConfirmationDialog/VBoxContainer/PortLineEdit.text = str(Game.DEFAULT_PORT)
	$Control/ConfirmationDialog.window_title = "Input server details"
	confirmationdialog_accept_button.text = "Join"
	$Control/ConfirmationDialog.popup_centered()
	
	var action: String = yield($Control/ConfirmationDialog, "custom_action")
	$Control/ConfirmationDialog.visible = false
	
	if action == "accept":
		$Control/AcceptDialog.window_title = "Couldn't join sever"
		var port_text: String = $Control/ConfirmationDialog/VBoxContainer/PortLineEdit.text
		if not port_text.is_valid_integer() or int(port_text) < 0 or int(port_text) > 65535:
			$Control/AcceptDialog.dialog_text = "Port must be a valid integer between 0 and 65535"
			$Control/AcceptDialog.popup_centered()
			return
		
		var ip_text: String = $Control/ConfirmationDialog/VBoxContainer/IpLineEdit.text

		var error = game.connect_to_server(false, int(port_text), ip_text)
		while error is GDScriptFunctionState:
			error = yield(error, "completed")
		
		if error != OK:
			
			var error_text: String
			match error:
				ERR_TIMEOUT:
					error_text = "Connection timed out"
				ERR_CANT_CONNECT:
					error_text = "Invalid server addess"
				_: error_text = "Error code: " + str(error)
			
			$Control/AcceptDialog.dialog_text = "An error occurred while trying to join the server:\n" + error_text
			$Control/AcceptDialog.popup_centered()
