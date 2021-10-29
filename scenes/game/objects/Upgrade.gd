tool
extends Node2D
class_name Upgrade

const SHOW_DURATION: float = 3.0

enum TYPES {DASH, AIR_JUMP}
export(TYPES) var type: int = TYPES.DASH setget set_type

onready var title_label: Label = $CanvasLayer/Control/Title
onready var description_label: Label = $CanvasLayer/Control/Title/Description

func _ready():
	$Icons.visible = false
	title_label.percent_visible = 0.0
	description_label.percent_visible = 0.0
	$CanvasLayer/Control.visible = false
	
	set_type(type)

const upgrade_data: Dictionary = {
	TYPES.DASH: {
		false: {
			"title": "Hyper Dash",
			"description": "Press TAB to dash left or right"
		},
		true: {
			"title": "+1 Aerial Hyper Dash",
			"description": "Dash 1 more time in the air before touching the ground"
		}
	},
	TYPES.AIR_JUMP: {
		false: {
			"title": "Air Jump",
			"description": "Jump once while in the air"
		},
		true: {
			"title": "+1 Air Jump",
			"description": "Jump 1 more time in the air before touching the ground"
		}
	},
}

func set_type(value: int):
	type = value
	
	if is_inside_tree():
		for icon in $Icons.get_children():
			icon.visible = icon.name == TYPES.keys()[type]

func acquire(player: Player, random: bool = true):
	
	var type: int = type
	
	if random:
		var available_types: Array = TYPES.values()
		
		# TYPES.AIR_JUMP
		if player.jump_capacity >= player.MAX_JUMP_CAPACITY:
			available_types.erase(TYPES.AIR_JUMP)
		
		# TYPES.DASH
		if player.dash_capacity >= player.MAX_DASH_CAPACITY:
			available_types.erase(TYPES.DASH)
		
		if available_types.empty():
			return
		
		type = Global.random_array_item(available_types)
	
	var has_upgrade: bool
	var suffix: String = ""
	match type:
		TYPES.AIR_JUMP:
			has_upgrade = player.jump_capacity != 1
			player.jump_capacity += 1
			if has_upgrade:
				suffix = "\nTotal: " + str(player.jump_capacity - 1)
		TYPES.DASH:
			has_upgrade = player.dash_capacity != 0
			player.dash_capacity += 1
			if has_upgrade:
				suffix = "\nTotal: " + str(player.dash_capacity)
	
	$CanvasLayer/Control.visible = true
	var icon: Node2D = $Icons.get_node(TYPES.keys()[type])
	var icon_canvas_transform: Transform2D = icon.get_global_transform_with_canvas()
	icon.visible = false
	
	Global.reparent_node(self, Global)
	Global.reparent_node(icon, $CanvasLayer/Control)
	
	var data: Dictionary = upgrade_data[type][has_upgrade]
	title_label.text = data["title"]
	description_label.text = data["description"] + suffix
	
	icon.global_transform = icon_canvas_transform
	icon.visible = true
	$Tween.interpolate_property(icon, "modulate:a", 0, 1, 0.25)
	$Tween.start()
	yield($Tween, "tween_all_completed")
	
	$Tween.interpolate_property(icon, "position", icon.position, Global.to_local($CanvasLayer/Control/Title/Description/Control/Position2D, $CanvasLayer/Control), 0.5, Tween.TRANS_EXPO, Tween.EASE_OUT)
	
	$Tween.interpolate_property(title_label, "percent_visible", 0.0, 1.0, 0.5)
	$Tween.interpolate_property(description_label, "percent_visible", 0.0, 1.0, 0.5)
	$Tween.start()
	
	yield(get_tree().create_timer(SHOW_DURATION), "timeout")
	
	$Tween.interpolate_property(title_label, "percent_visible", 1.0, 0.0, 0.5)
	$Tween.interpolate_property(description_label, "percent_visible", 1.0, 0.0, 0.5)
	$Tween.interpolate_property(icon, "modulate:a", 1, 0, 0.25)
	$Tween.start()
	yield($Tween, "tween_all_completed")
	$CanvasLayer/Control.visible = false
