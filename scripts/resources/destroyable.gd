extends RigidBody3D
class_name Destroyable

@export var target : Sprite3D
var being_targeted : bool = false

var health : float = 100.0
var _dead: bool = false
signal destroyed

func _ready() -> void:
	if target:
		target.hide()
	
func take_damage(damage: float) -> void:
	if _dead:
		return
	health -= damage
	if health <= 0:
		_dead = true
		queue_free()
		destroyed.emit()

func untarget_destroyable() -> void:
	being_targeted = false
	if target:
		target.hide()

func target_destroyable() -> void:
	being_targeted = true
	if target:
		target.show()
