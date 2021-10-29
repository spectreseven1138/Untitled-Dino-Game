class_name Player
extends KinematicBody2D

const USERNAME_MAX_LENGTH: int = 15

signal puppet_initialised
signal distance_travelled_changed(distance_travelled, player)

const GRAVITY: float = 1100.0
const FALL_SPEED_CAP: float = 3000.0

const MAX_RUN_SPEED: float = 110.0
const RUN_ACCELERATION: float = 850.0

const JUMP_SPEED: float = 350.0
const JUMP_MAX_HEIGHT_FROM_GROUND: float = 30.0 # Max distance from ground from which player can jump
const MAX_JUMP_CAPACITY: int = 4
var jump_capacity: int = 1
var remaining_jumps: int = 1

const DASH_SPEED: float = 300.0
const DASH_MAX_DURATION: float = 0.25
var dash_time: float = 0.0
var dash_on_floor: bool = false
const MAX_DASH_CAPACITY: int = 3
var dash_capacity: int = 0
var remaining_dashes: int = 1

const types: Dictionary = {
	"1": {"spriteframes": preload("res://scenes/game/player/Spriteframes_type_1.tres")},
	"2": {"spriteframes": preload("res://scenes/game/player/Spriteframes_type_2.tres")},
	"3": {"spriteframes": preload("res://scenes/game/player/Spriteframes_type_3.tres")},
	"4": {"spriteframes": preload("res://scenes/game/player/Spriteframes_type_4.tres")},
}

var game: Node
onready var sprite: AnimatedSprite = $AnimatedSprite
onready var dash_sprite: Node2D = $AnimatedSprite/Dash
onready var username_label: Label = $AnimatedSprite/Control/UsernameLabel

enum STATES {NONE, DEPLOYING, PLAYING}
sync var state: int = STATES.NONE
onready var colour: Color = sprite.self_modulate setget set_colour
var type: String = types.keys()[0] setget set_type
var username: String = null setget set_username

puppet var run_animation_speed: float = 1.0 setget set_run_animation_speed
puppet var puppet_position: Vector2
puppet var crouching: bool = false# setget set_crouching
puppet var flip_sprite: bool = false setget set_flip_sprite
puppet var dash_sprite_visible: bool = false setget set_dash_sprite_visible

var distance_travelled: float = 0.0 setget set_distance_travelled

func init(_game):
	game = _game

func _init():
	visible = false
	set_physics_process(false)
	set_process_input(false)

func _ready():
	sprite.play("run")
	dash_sprite.visible = false
	if not get_tree().has_network_peer() or is_network_master():
		visible = true
		set_physics_process(true)
		set_process_input(true)
		username_label.visible = false
	else:
		username_label.visible = true
		modulate.a = 0.5
		rpc_id(get_network_master(), "request_init_puppet", get_tree().get_network_unique_id())

remote func request_init_puppet(puppet_id: int):
	var info: Dictionary = {
		"colour": colour,
		"type": type,
		"state": state,
		"position": position,
		"username": username,
		"run_animation_speed": run_animation_speed
	}
	rpc_id(puppet_id, "init_puppet", info)

remote func init_puppet(info: Dictionary):
	for property in info:
		set(property, info[property])
	
	visible = true
	set_physics_process(true)
	emit_signal("puppet_initialised")

var vel: Vector2 = Vector2.ZERO
var was_on_floor: bool = true

func _physics_process(delta: float):
	
	if not get_tree().has_network_peer() or state == STATES.NONE:
		return
	
	if is_network_master():
		if state == STATES.PLAYING:
			
			var new_is_on_floor: bool = null
			if is_on_floor() != was_on_floor:
				was_on_floor = is_on_floor()
				new_is_on_floor = was_on_floor
			
			if new_is_on_floor == true:
				remaining_dashes = dash_capacity
			
			if game.simple_mode:
				if Input.is_key_pressed(KEY_RIGHT):
					vel.x = move_toward(vel.x, MAX_RUN_SPEED, RUN_ACCELERATION*delta)
					set_flip_sprite(false)
				elif Input.is_key_pressed(KEY_LEFT):
					vel.x = move_toward(vel.x, -MAX_RUN_SPEED, RUN_ACCELERATION*delta)
					set_flip_sprite(true)
				else:
					vel.x = move_toward(vel.x, 0, RUN_ACCELERATION*delta)
			else:
				if Input.is_key_pressed(KEY_RIGHT):
					vel.x = move_toward(vel.x, MAX_RUN_SPEED, RUN_ACCELERATION*delta)
					set_flip_sprite(false)
				elif Input.is_key_pressed(KEY_LEFT):
					vel.x = move_toward(vel.x, -MAX_RUN_SPEED - game.segment_speed, RUN_ACCELERATION*delta)
					set_flip_sprite(true)
				else:
					vel.x = move_toward(vel.x, -game.segment_speed, RUN_ACCELERATION*delta)
			
			if not crouching and sprite.animation != "hurt" and Input.is_action_just_pressed("jump") and (remaining_jumps > 0 or get_distance_to_ground() <= JUMP_MAX_HEIGHT_FROM_GROUND):
				if get_distance_to_ground() <= JUMP_MAX_HEIGHT_FROM_GROUND:
					remaining_jumps = jump_capacity
					remaining_dashes = dash_capacity
				remaining_jumps -= 1
				dash_time = 0.0
				set_dash_sprite_visible(false)
				vel.y =  -JUMP_SPEED
				sprite.speed_scale = 1.0
				sprite.play("jump")
				sprite.frame = 0
			elif sprite.animation == "jump" and new_is_on_floor == true:
				sprite.speed_scale = run_animation_speed
				sprite.play("run")
				remaining_jumps = jump_capacity
				remaining_dashes = dash_capacity
			else:
				if Input.is_action_just_pressed("dash") and remaining_dashes > 0:
					dash_on_floor = is_on_floor()
					sprite.play("run_crouch")
					dash_time = DASH_MAX_DURATION - delta
					set_dash_sprite_visible(true)
					vel.x = -DASH_SPEED if flip_sprite else DASH_SPEED
					if not dash_on_floor:
						remaining_dashes -= 1
						vel.y = 0
				elif dash_time > 0.0:
					dash_time -= delta
					if dash_time <= 0.0 or not Input.is_action_pressed("dash"):
						dash_time = 0.0
						vel.y = move_toward(vel.y, FALL_SPEED_CAP, GRAVITY*delta)
						sprite.play("run")
						set_dash_sprite_visible(false)
					else:
						vel.x = -DASH_SPEED - game.segment_speed if flip_sprite else DASH_SPEED
						if not dash_on_floor:
							vel.y = 0
			
			vel.y = move_toward(vel.y, FALL_SPEED_CAP, GRAVITY*delta)
			vel.y = move_and_slide(vel, Vector2.UP).y
#			set_flip_sprite(vel.x < 0)
		
		elif state == STATES.DEPLOYING:
			vel.y = move_toward(vel.y, FALL_SPEED_CAP, GRAVITY*delta)
			vel = move_and_slide(vel, Vector2.UP)
			
			if is_on_floor():
				set_state(STATES.PLAYING)
		
		rset_unreliable("puppet_position", position)
		
	else:
		position = puppet_position

#func _process(delta: float):
#	if not get_tree().has_network_peer() or state == STATES.NONE or not is_network_master():
#		return
#
#	if sprite.animation != "hurt":
#		set_crouching(Input.is_action_pressed("crouch"))

func set_colour(value: Color):
	value.a = 1.0
	colour = value
	sprite.self_modulate = colour
	dash_sprite.modulate = colour
	dash_sprite.modulate.a = 0.5

func set_type(value: String):
	type = value
	sprite.frames = types[type]["spriteframes"]

func set_username(value: String):
	username = value.left(USERNAME_MAX_LENGTH)
	username_label.text = username

func set_state(value: int):
	rset("state", value)

#func set_crouching(value: bool):
#	if value == crouching:
#		return
#	print("SET ", value)
#	crouching = value
#	if crouching:
#		sprite.play("run_crouch")
#	else:
#		sprite.play("run")
#	if is_network_master():
#		rset("crouching", value)

func set_run_animation_speed(value: float):
	if run_animation_speed == value:
		return
	run_animation_speed = value
	if sprite.animation in ["run", "run_crouch"]:
		sprite.speed_scale = run_animation_speed
	if is_network_master():
		rset("run_animation_speed", run_animation_speed)

func set_flip_sprite(value: bool):
	if flip_sprite == value:
		return
	flip_sprite = value
	sprite.flip_h = flip_sprite
	dash_sprite.scale.x = -1 if flip_sprite else 1
	if is_network_master():
		rset("flip_sprite", flip_sprite)

func set_distance_travelled(value: float):
	distance_travelled = value
	emit_signal("distance_travelled_changed", distance_travelled, self)

func get_distance_to_ground() -> float:
	$RayCast2D.cast_to.y = JUMP_MAX_HEIGHT_FROM_GROUND + 10
	$RayCast2D.force_raycast_update()
	if not $RayCast2D.is_colliding():
		return INF
	else:
		return $RayCast2D.get_collision_point().y - $RayCast2D.global_position.y

func set_dash_sprite_visible(value: bool):
	if dash_sprite_visible == value:
		return
	dash_sprite_visible = value
	dash_sprite.visible = dash_sprite_visible
	if is_network_master():
		rset("dash_sprite_visible", dash_sprite_visible)

var hurt_id: int
func on_spike_touched():
	var time: int = OS.get_ticks_msec()
	hurt_id = time
	sprite.play("hurt")
	yield(sprite, "animation_finished")
	if sprite.animation == "hurt" and hurt_id == time:
		sprite.play("run_crouch" if crouching else "run")
