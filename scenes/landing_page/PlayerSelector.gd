extends Control
class_name PlayerSelector

onready var player: Player = $MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/Control/Player
onready var type_container: HBoxContainer = $MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/TypeHBoxContainer
onready var username_textbox: LineEdit = $MarginContainer/HBoxContainer/MarginContainer2/VBoxContainer/UsernameTextBox
onready var speed_slider: HSlider = $MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/SpeedSlider

func _ready():
	_on_randomise_button_pressed()
	player.username_label.visible = false
	player.username = username_textbox.text
	
	username_textbox.max_length = Player.USERNAME_MAX_LENGTH
	$MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/ColorPickerButton.color = player.colour
	for type in Player.types:
		var button: NinePatchRectTextureButton = NinePatchRectTextureButton.new()
		button.texture_normal = preload("res://sprites/UI/button/normal.png")
		button.texture_pressed = preload("res://sprites/UI/button/pressed.png")
		button.texture_hover = preload("res://sprites/UI/button/normal.png")
		button.texture_disabled = preload("res://sprites/UI/button/disabled.png")
		button.focus_mode = Control.FOCUS_NONE
		button.rect_min_size = Vector2(30, 30)
		button.connect("pressed", self, "on_player_type_selected", [type])
		
		var sprite: TextureRect = TextureRect.new()
		sprite.texture = Player.types[type]["spriteframes"].get_frame("run", 0)
		sprite.rect_position = Vector2(2, 1)
		button.nodes_to_offset.append(sprite)
		button.node_pressed_offset = 2.0
		button.add_child(sprite)
		type_container.add_child(button)
	type_container.set("custom_constants/separation", 13)

func _on_ColorPickerButton_color_changed(colour: Color):
	player.colour = colour

func on_player_type_selected(type: String):
	player.type = type

func _on_randomise_button_pressed():
	player.type = Global.random_array_item(Player.types.keys())
	player.colour = Global.random_colour()
	speed_slider.value = Global.RNG.randf_range(speed_slider.min_value, speed_slider.max_value)
	$MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/ColorPickerButton.color = player.colour

func _on_SpeedSlider_value_changed(value: float):
	player.run_animation_speed = value

func _on_Player_gui_input(event: InputEvent):
	
	if event is InputEventMouseButton and event.pressed and event.button_index in [BUTTON_LEFT, BUTTON_RIGHT, BUTTON_MIDDLE] and player.sprite.animation != "hurt":
		var animations: Array = player.sprite.frames.get_animation_names()
		animations.erase("run")
		animations.erase("jump")
		player.sprite.speed_scale = 1.0
		player.sprite.play(Global.random_array_item(animations))
		yield(player.sprite, "animation_finished")
		player.sprite.speed_scale = speed_slider.value
		player.sprite.play("run")

func _on_UsernameTextBox_text_changed(new_text: String):
	player.username = new_text
