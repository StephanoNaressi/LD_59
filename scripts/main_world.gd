extends Node3D


func _ready() -> void:
	TowerRegistry.refresh_from_tree(get_tree())
