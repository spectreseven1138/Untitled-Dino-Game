class_name Segment
extends Node2D

export var weight: float = 1.0
export var is_treasure: bool = false
export var end_position_nodepath: NodePath
var end_position_node: Node2D
export var connection_position_nodepath: NodePath
var connection_position_node: Node2D

var id: String = name

func init():
	end_position_node = get_node(end_position_nodepath)
	
	if has_node(connection_position_nodepath):
		connection_position_node = get_node(connection_position_nodepath)
	else:
		connection_position_node = end_position_node

func _on_Spike_body_entered(body: PhysicsBody2D):
	if not body is Player:
		return
	body.on_spike_touched()
