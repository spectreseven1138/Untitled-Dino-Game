extends Node

signal process(delta)

var RNG: RandomNumberGenerator
var game: Game

func _process(delta: float):
	emit_signal("process", delta)

func _init():
	RNG = RandomNumberGenerator.new()
	RNG.randomize()

func random_array_item(array: Array, rng: RandomNumberGenerator = RNG):
	return array[rng.randi() % len(array)]

func random_colour(r: float = null, g: float = null, b: float = null, a: float = null, rng: RandomNumberGenerator = RNG) -> Color:
	var ret: Color = Color(rng.randf(), rng.randf(), rng.randf())
	for property in ["r", "g", "b", "a"]:
		if get(property) != null:
			ret[property] = get(property)
	return ret

func reparent_node(node: Node, new_parent: Node, retain_global_position: bool = false):
	var original_global_position: Vector2
	if retain_global_position:
		original_global_position = get_node_position(node, true)
	
	if node.is_inside_tree():
		node.get_parent().remove_child(node)
	new_parent.add_child(node)
	
	if retain_global_position:
		set_node_position(node, original_global_position, true)

func get_node_global_scale(node: Node) -> Vector2:
	var scale: Vector2 = Vector2.ONE
	while node != get_tree().root:
		if node is Node2D:
			scale *= node.scale
		elif node is Control:
			scale *= node.rect_scale
		
		node = node.get_parent()
	
	return scale

func set_node_global_scale(node: Node, scale: Vector2):
	var parent_node: Node = node.get_parent()
	while parent_node != get_tree().root:
		if parent_node is Node2D:
			scale /= parent_node.scale
		elif parent_node is Control:
			scale /= parent_node.rect_scale
		
		parent_node = parent_node.get_parent()
	
	if node is Node2D:
		node.scale = scale
	elif node is Control:
		node.rect_scale = scale
	else:
		push_error("Passed node has no scale property")

func to_local(node: Node, relative_to: Node):
	return get_node_position(node, true) - get_node_position(relative_to, true)

func get_node_position(node: Node, global: bool = false) -> Vector2:
	if node is Node2D:
		return node.global_position if global else node.position
	elif node is Control:
		return node.rect_global_position if global else node.rect_position
	else:
		push_error("Node '" + str(node) + "' isn't a Node2D or Control")
		return Vector2.ZERO

func set_node_position(node: Node, position: Vector2, global: bool = false):
	if node is Node2D:
		node.set("global_position" if global else "position", position)
	elif node is Control:
		node.set("rect_global_position" if global else "rect_position", position)
	else:
		push_error("Node '" + str(node) + "' isn't a Node2D or Control")
