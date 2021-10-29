tool
extends Area2D

enum TYPES {NORMAL, SPECIAL}
export(TYPES) var type: int = TYPES.NORMAL setget set_type

var opened: bool = false

func set_type(value: int):
	type = value
	$AnimatedSprite.play(TYPES.keys()[type])
	_ready()

func _ready():
	$AnimatedSprite.playing = false
	$AnimatedSprite.frame = 0

func _on_Chest_body_entered(body: PhysicsBody2D):
	if not body is Player or opened:
		return
	
	opened = true
	$AnimatedSprite.play(TYPES.keys()[type])
	
	if body.is_network_master():
		$Upgrade.acquire(body)
