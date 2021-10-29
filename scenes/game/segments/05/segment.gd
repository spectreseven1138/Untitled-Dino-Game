extends Segment

func _ready():
	var player: AnimationPlayer = $MashySpikePlates/AnimationPlayer
	player.advance(player.current_animation_length * randf())
	print(player.current_animation_position)

func _on_CollisionExcludeArea_body_entered(body: PhysicsBody2D):
	if not body is Player:
		return
	$MashySpikePlates/TileMap/StaticBody2D.add_collision_exception_with(body)

func _on_CollisionExcludeArea_body_exited(body: PhysicsBody2D):
	if not body is Player:
		return
	
	$MashySpikePlates/TileMap/StaticBody2D.remove_collision_exception_with(body)
