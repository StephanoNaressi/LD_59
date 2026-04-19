extends RigidBody3D
class_name Destroyable

const BREAK_SFX: AudioStream = preload("res://game/audios/break.ogg")

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
		process_mode = Node.PROCESS_MODE_DISABLED
		visible = false
		freeze = true
		collision_layer = 0
		collision_mask = 0
		GlobalValues.play_break_sfx(BREAK_SFX, AudioLevels.SFX_BREAK_VOLUME_DB, randf_range(0.96, 1.04))
		if should_drop_loot():
			if resource_drop == Item.Item_Type.OXYGEN:
				route_drop_to_life_support(true, drop_rate)
			elif resource_drop == Item.Item_Type.WATER:
				route_drop_to_life_support(false, drop_rate)
			else:
				for drop_index in range(drop_rate):
					var drop: Item = Item.new()
					drop.type = resource_drop
					GlobalValues.inventory.append(drop)
			GlobalValues.update_ui.emit()
		destroyed.emit()
		on_destroyed()
		call_deferred("queue_free")


func should_drop_loot() -> bool:
	return true


func route_drop_to_life_support(oxygen: bool, units: int) -> void:
	var ship: Node = get_tree().get_first_node_in_group("rideable_ship")
	if not (ship is SpaceShip):
		return
	var space_ship: SpaceShip = ship as SpaceShip
	var amount: float = float(units) * 2.35
	if oxygen:
		space_ship.add_oxygen_to_tank(amount)
	else:
		space_ship.add_water_to_tank(amount)


func on_destroyed() -> void:
	pass


func untarget_destroyable() -> void:
	being_targeted = false
	if crosshair_marker:
		crosshair_marker.visible = false


func target_destroyable() -> void:
	being_targeted = true
	if crosshair_marker:
		crosshair_marker.visible = true
