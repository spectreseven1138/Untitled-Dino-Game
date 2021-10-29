extends Node2D

func _ready():
	$AnimatedSprite.play("break")
	$AnimatedSprite.playing = false
	$AnimatedSprite.frame = 0


func _on_Pot_body_entered(body: PhysicsBody2D):
	if not body is Player:
		return
	$AnimatedSprite.play("break")
	yield($AnimatedSprite, "animation_finished")
	queue_free()
