extends RigidBody3D
class_name Destroyable

@export var crosshair_marker: Marker3D
@export var resource_drop: Item.Item_Type

var being_targeted: bool = false
var dead: bool = false

var health: float = 100.0
var drop_rate: int = 3
signal destroyed


func _ready() -> void:
	if crosshair_marker:
		crosshair_marker.visible = false


func get_weapon_aim_position() -> Vector3:
	if crosshair_marker:
		return crosshair_marker.global_position
	return global_position


func take_damage(damage: float) -> void:
	if dead:
		return
	health -= damage
	if health <= 0.0:
		dead = true
		if _drops_inventory_on_death():
			for drop_index in range(drop_rate):
				var drop: Item = Item.new()
				drop.type = resource_drop
				GlobalValues.inventory.append(drop)
			GlobalValues.update_ui.emit()
		destroyed.emit()
		_on_destroyable_destroyed()
		queue_free()


func _drops_inventory_on_death() -> bool:
	return true


func _on_destroyable_destroyed() -> void:
	pass


func untarget_destroyable() -> void:
	being_targeted = false
	if crosshair_marker:
		crosshair_marker.visible = false


func target_destroyable() -> void:
	being_targeted = true
	if crosshair_marker:
		crosshair_marker.visible = true
