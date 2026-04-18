extends RigidBody3D
class_name Destroyable

@export var target : Sprite3D
@export var resource_drop : Item.Item_Type

var being_targeted : bool = false
var _dead: bool = false

var health : float = 100.0
var drop_rate : int = 10
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
		for i in range(drop_rate):
			var drop : Item = Item.new()
			drop.type = resource_drop
			GlobalValues.inventory.append(drop)
		destroyed.emit()
		queue_free()

func untarget_destroyable() -> void:
	being_targeted = false
	if target:
		target.hide()

func target_destroyable() -> void:
	being_targeted = true
	if target:
		target.show()
