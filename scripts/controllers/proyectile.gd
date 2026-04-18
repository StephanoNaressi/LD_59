extends Node3D
class_name Proyectile

var target: Meteor
var speed: float = 30.0
var hit_distance: float = 0.5


func configure_homing(target_meteor: Meteor, muzzle: Node3D) -> void:
	target = target_meteor
	global_position = muzzle.global_position


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return

	var aim: Vector3 = target.get_weapon_aim_position()
	global_position = global_position.move_toward(aim, speed * delta)

	if global_position.distance_to(aim) <= hit_distance:
		target.take_damage(10.0)
		queue_free()
