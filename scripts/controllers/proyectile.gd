extends Node3D
class_name Proyectile

var target : Node3D
var speed : float = 5.0

func _process(delta: float) -> void:
	if target:
		position = position.move_toward(target.position, speed * delta)
