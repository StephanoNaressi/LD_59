extends Node3D
class_name Proyectile

var target: Meteor
var speed: float = 30.0
var hit_distance: float = 0.5

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return

	global_position = global_position.move_toward(target.global_position, speed * delta)

	if global_position.distance_to(target.global_position) <= hit_distance:
		target.take_damage(10.0)
		queue_free()
