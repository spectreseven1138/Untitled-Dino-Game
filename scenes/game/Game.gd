extends Node2D
class_name Game

signal player_info_received(from_id, info)
signal player_joined(player)
signal player_left(player)

var simple_mode: bool = OS.get_name().to_lower() in ["android", "ios"]
var is_server: bool = false
var server_info: Dictionary = null

const CONNECTION_TIMEOUT: float = 5.0
const DEFAULT_SERVER: String = "https://godot-dino-game.herokuapp.com/"
const DEFAULT_PORT: int = 44444
const SEGMENT_DIRECTORY: String = "res://scenes/game/segments/"
const SEGMENT_FILENAME: String = "segment.tscn"
const SERVER_MAX_CLIENTS: int = 4095

const player_base_scale: Vector2 = Vector2(1.5, 1.5)
const player_scene: PackedScene = preload("res://scenes/game/Player.tscn")
var local_player: Player
var players: Dictionary = {}

onready var segment_container: Node2D = $Segments
var all_segments: Dictionary = {}

const TARGET_MAP_WIDTH: float = 1000.0
const PREVIOUS_SEGMENTS_TO_CONSIDER: int = 5
var segment_history: ExArray = ExArray.new([], PREVIOUS_SEGMENTS_TO_CONSIDER).fill_to_limit(null)
var current_width: float = 0.0

onready var camera: Camera2D = $Camera2D
onready var camera_lower_limit: float = camera.global_position.y
onready var camera_upper_limit: float = camera_lower_limit - 90

export(float, 0.1, 200) var time_scale: float = 1.0

func _ready():
	randomize()
	Engine.time_scale = time_scale
	Global.game = self
	$LandingPage.init(self)
	local_player = $LandingPage.player_selector.player
	$CanvasLayer/Scoreboard.init(self)
	$CanvasLayer/Scoreboard.visible = false
	
	get_tree().connect("network_peer_connected", self, "on_network_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "on_player_left")
	
	$CanvasLayer/Node2D/ColorRect.rect_position = Vector2.ZERO
	$CanvasLayer/Node2D/ColorRect.rect_size = get_viewport_rect().size
	
	var dir: Directory = Directory.new()
	
	var err: int = dir.open(SEGMENT_DIRECTORY)
	if err != OK:
		push_error("Couldn't open segments directory (" + str(err) + ")")
		return
	
	dir.list_dir_begin(true, true)
	var file_name: String = dir.get_next()
	while file_name != "":
		
		if dir.current_is_dir():
			var subdir: Directory = Directory.new()
			subdir.open(SEGMENT_DIRECTORY.plus_file(file_name))
			
			if subdir.file_exists(SEGMENT_FILENAME):
				var scene: PackedScene = load(subdir.get_current_dir().plus_file(SEGMENT_FILENAME))
				all_segments[file_name] = {"scene": scene}
				scene.set_meta("id", file_name)
				
				var segment_state: SceneState = scene.get_state()
				var properties_to_get: Array = ["weight", "is_treasure"]
				
				for node_prop_idx in segment_state.get_node_property_count(0):
					var property: String = segment_state.get_node_property_name(0, node_prop_idx)
					if property in properties_to_get:
						properties_to_get.erase(property)
						all_segments[file_name][property] = segment_state.get_node_property_value(0, node_prop_idx)
						
						if properties_to_get.empty():
							break
				
				if not properties_to_get.empty():
					var script_instance: Segment = Segment.new()
					for property in properties_to_get:
						all_segments[file_name][property] = script_instance.get(property)
					script_instance.free()
		file_name = dir.get_next()
	
	set_fade_closed(true, false)
	yield(get_tree().create_timer(0.5), "timeout")
	connect_to_server(true, DEFAULT_PORT)

func get_screen_left_edge() -> float:
	var camera_center: Vector2 = camera.get_camera_screen_center()
	return camera_center.x - ((get_viewport_rect().size.x * camera.zoom.x) / 2)

const segment_speed: float = 150.0
func _process(delta: float):
	
#	if is_instance_valid(local_player) and local_player.state == Player.STATES.PLAYING:
#		camera.global_position.y = max(min(local_player.global_position.y, camera_lower_limit), camera_upper_limit)
	
	if is_server:
		if current_width < TARGET_MAP_WIDTH:
			var segments_to_add: PoolStringArray = PoolStringArray([get_next_segment_id()])
			while current_width < TARGET_MAP_WIDTH:
				current_width += place_segments(segments_to_add)
			
			rpc("place_segments", segments_to_add)
		
		for segment in segment_container.get_children():
			segment.position.x -= segment_speed*delta
		
		var first: Segment = segment_container.get_child(0)
		if (first.global_position.x + first.get_meta("end_width")) < get_screen_left_edge():
			current_width -= first.get_meta("connection_width")
			rpc("remove_segment", 0)
	else:
		for segment in segment_container.get_children():
			segment.position.x -= segment_speed*delta
	
	for player in players.values():
		player.distance_travelled += segment_speed*delta
	
	$Background/ParallaxBackground.scroll_base_offset.x -= segment_speed*delta

remote func place_segments(segment_ids: PoolStringArray) -> float:
	var added_width: float = 0.0
	for segment_id in segment_ids:
		var segment: Segment = all_segments[segment_id]["scene"].instance()
		segment.init()
		var previous_segment: Segment = segment_container.get_child(segment_container.get_child_count() - 1) if segment_container.get_child_count() > 0 else null
		segment_container.add_child(segment)
		segment.global_position.x = previous_segment.connection_position_node.global_position.x if previous_segment else segment_container.global_position.x
		segment.set_meta("id", segment_id)
		segment.set_meta("end_width", segment.end_position_node.global_position.x - segment.global_position.x)
		segment.set_meta("connection_width", segment.connection_position_node.global_position.x - segment.global_position.x)
		added_width += segment.get_meta("connection_width")
		segment_history.append(segment_id)
	return added_width

sync func remove_segment(index: int):
	segment_container.get_child(index).queue_free()

func get_next_segment_id():
	var segments: Dictionary = all_segments.duplicate(true)
	var previous_was_treasure: bool = segments[segment_history.back()]["is_treasure"] if segment_history.back() != null else false
	
	var total_weight: float = 0.0
	for segment in segments:
		if previous_was_treasure and segments[segment]["is_treasure"]:
			segments.erase(segment)
			continue
		if segment in segment_history.array:
			var position: int = 0
			for _i in segment_history.count(segment):
				position = segment_history.find(segment, position)
				segments[segment]["weight"] /= position + 1
			
		total_weight += segments[segment]["weight"]
	
	var selected_position: float = Global.RNG.randf_range(0.0, total_weight)
	var selected_segment: String
	for segment in segments:
		selected_position -= segments[segment]["weight"]
		if selected_position <= 0.0:
			selected_segment = segment
			break
	
	return selected_segment

func connect_to_server(local: bool, port: int, address: String = null) -> int:
	yield(set_fade_closed(true), "completed")
	set_process(false)
	set_physics_process(false)
	
	if is_instance_valid(get_tree().network_peer) and get_tree().network_peer.get_connection_status() == NetworkedMultiplayerENet.CONNECTION_CONNECTED:
		get_tree().network_peer.close_connection()
	
	for segment in segment_container.get_children():
		segment.queue_free()
	for player in $Players.get_children():
		player.queue_free()
	current_width = 0.0
	
	is_server = false
	server_info = null
	
	var peer: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	get_tree().set_network_peer(null)
	var error: int
	if local:
		error = peer.create_server(port, SERVER_MAX_CLIENTS)
		get_tree().set_network_peer(peer)
	else:
		error = peer.create_client(address, port)
		
		if peer.get_connection_status() == peer.CONNECTION_DISCONNECTED:
			return ERR_CANT_CONNECT
		
		get_tree().set_network_peer(peer)
		
		var time: float = 0.0
		while peer.get_connection_status() == peer.CONNECTION_CONNECTING:
			time += yield(Global, "process")
			
			if time >= CONNECTION_TIMEOUT:
				return ERR_TIMEOUT
		
		if peer.get_connection_status() == peer.CONNECTION_DISCONNECTED:
			return ERR_CANT_CONNECT
	
	if error != OK:
		return error
	
	is_server = local
	server_info = {"address": address, "port": port}
	
	set_process(true)
	set_physics_process(true)
	yield(set_fade_closed(false), "completed")
	
	return OK

remote func test():
	return "AAA"

func _input(event: InputEvent):
	
	if event is InputEventKey and event.pressed and event.scancode == KEY_F11:
		OS.window_fullscreen = !OS.window_fullscreen

var fade_closed: bool = false setget set_fade_closed
func set_fade_closed(value: bool, animate: bool = true):
	if value == fade_closed:
		if $FadeTween.is_active():
			yield($FadeTween, "tween_all_completed")
		else:
			yield(get_tree(), "idle_frame")
		return
	fade_closed = value
	
	$CanvasLayer/Node2D/ColorRect.rect_rotation = 0.0 if fade_closed else 180.0
	$CanvasLayer/Node2D/ColorRect.rect_position = Vector2.ZERO if fade_closed else $CanvasLayer/Node2D/ColorRect.rect_size
	
	if animate:
		$CanvasLayer/Node2D/ColorRect.visible = true
		$FadeTween.stop_all()
		$FadeTween.interpolate_property($CanvasLayer/Node2D/ColorRect.material, "shader_param/progress", $CanvasLayer/Node2D/ColorRect.material.get("shader_param/progress"), 0.73 if fade_closed else 0.0, 1.0, Tween.TRANS_SINE)
		$FadeTween.start()
		yield($FadeTween, "tween_all_completed")
	else:
		$CanvasLayer/Node2D/ColorRect.material.set("shader_param/progress", 0.73 if fade_closed else 0.0)
	
	$CanvasLayer/Node2D/ColorRect.visible = fade_closed


func _on_PlaygameButton_pressed():
	var player_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse().xform(local_player.global_position)
	var player_scale: Vector2 = Global.get_node_global_scale(local_player)
	
	Global.reparent_node(local_player, $Players)
	local_player.init(self)
	local_player.z_index += 1
	local_player.global_position = player_position
	Global.set_node_global_scale(local_player, player_scale*camera.zoom)
	local_player.set_state(Player.STATES.PLAYING)
	local_player.name = str(get_tree().get_network_unique_id())
	local_player.set_network_master(get_tree().get_network_unique_id())
	
	rpc("on_player_joined", get_tree().get_network_unique_id())
	
	$LandingPageFadeTween.interpolate_property($LandingPage/Control, "modulate:a", $LandingPage/Control.modulate.a, 0, 0.25)
	$LandingPageFadeTween.start()
	yield($LandingPageFadeTween, "tween_all_completed")
	$LandingPage/Control.visible = false
#	yield(get_tree().create_timer(0.25), "timeout")
	$CanvasLayer/Scoreboard.modulate.a = 0.0
	$CanvasLayer/Scoreboard.visible = true
	$LandingPageFadeTween.interpolate_property($CanvasLayer/Scoreboard, "modulate:a", 0, 0.75, 0.5)
	$LandingPageFadeTween.start()

remote func client_init(player_ids: PoolIntArray, segment_ids: PoolStringArray, segment_positions: Array):
	for id in player_ids:
		var player: Player = player_scene.instance()
		player.init(self)
		players[id] = player
		player.name = str(id)
		player.set_network_master(id)
		player.scale = player_base_scale * camera.zoom
		$Players.add_child(player)
	
	place_segments(segment_ids)
	for i in segment_container.get_child_count():
		segment_container.get_child(i).position.x = segment_positions[i]

remote func send_player_info(to_id: int):
	var info: Dictionary = {
		"colour": local_player.colour,
		"username": local_player.username,
		"type": local_player.type
	}
	rpc_id(to_id, "receive_player_info", get_tree().get_network_unique_id(), info)

remote func receive_player_info(from_id: int, info: Dictionary):
	emit_signal("player_info_received", from_id, info)

func on_network_peer_connected(id: int):
	if id == 1:
		return
	if get_tree().is_network_server():
		
		var segment_ids: PoolStringArray = PoolStringArray()
		var segment_positions: Array = []
		for segment in segment_container.get_children():
			segment_ids.append(segment.get_meta("id"))
			segment_positions.append(segment.position.x)
		
		rpc_id(id, "client_init", players.keys(), segment_ids, segment_positions)

sync func on_player_joined(id: int):
	if id == get_tree().get_network_unique_id():
		players[id] = local_player
		emit_signal("player_joined", local_player)
	else:
		var player: Player = player_scene.instance()
		player.init(self)
		players[id] = player
		player.name = str(id)
		player.scale = player_base_scale * camera.zoom
		player.set_network_master(id)
		$Players.add_child(player)
		emit_signal("player_joined", player)

func on_player_left(id: int):
	if not id in players:
		return
	
	var player: Player = players[id]
	players.erase(id)
	emit_signal("player_left", player)
	player.queue_free()


func _on_GameArea_body_exited(body: PhysicsBody2D):
	if not body is Player:
		return
	
	on_player_left(body.get_network_master())
