extends StaticBody3D
class_name ResourceTank

enum Kind { OXYGEN, WATER }

@export var kind: Kind = Kind.OXYGEN
@export var units_per_use: int = 1


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0


func try_deposit_from_inventory() -> bool:
	var ship: SpaceShip = get_parent() as SpaceShip
	if ship == null:
		return false
	var moved: int = 0
	for i in range(units_per_use):
		var is_o2: bool = kind == Kind.OXYGEN
		var item_type: Item.Item_Type = Item.Item_Type.OXYGEN if is_o2 else Item.Item_Type.WATER
		var has_room: bool = ship.oxygen_tank_remaining_capacity() >= 1.0 if is_o2 else ship.water_tank_remaining_capacity() >= 1.0
		if not has_room or not GlobalValues.try_remove_one_item(item_type):
			break
		if is_o2:
			ship.add_oxygen_to_tank(1.0)
		else:
			ship.add_water_to_tank(1.0)
		moved += 1
	return moved > 0
