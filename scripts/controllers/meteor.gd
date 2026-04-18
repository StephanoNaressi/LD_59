extends RigidBody3D
class_name Meteor

var health : float = 100.0

func take_damage(damage : float) -> void:
	health -= damage
	if health < 0:
		queue_free()
