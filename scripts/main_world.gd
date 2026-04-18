extends Node3D


func _ready() -> void:
	GlobalValues.refresh_towers_from_scene(get_tree())
