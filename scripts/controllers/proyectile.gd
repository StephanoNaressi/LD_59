extends Node3D
class_name Proyectile

var target: Node3D
var speed: float = 30.0
var hit_distance: float = 0.5

func _process(delta: float) -> void:
	if target == null:
		queue_free()
		return

	position = position.move_toward(target.position, speed * delta)

	if position.distance_to(target.position) <= hit_distance:
		queue_free()
