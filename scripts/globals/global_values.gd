extends Node

var player: Player

var inventory: Array[Item]

var game_over_occurred: bool = false

signal update_ui
signal antenna_repair_hud_changed(antenna: Antenna)
signal game_over(reason: String)
signal loot_toast(text: String)


func notify_meteor_rewards(resource: Item.Item_Type, pickup_count: int) -> void:
	if game_over_occurred:
		return
	loot_toast.emit("+%s %d  +Fuel" % [Item.type_name(resource), pickup_count])


func grant_fuel_from_meteor_destroyed(amount: float = 0.14) -> void:
	if game_over_occurred:
		return
	var ship: Node = get_tree().get_first_node_in_group("rideable_ship")
	if ship is SpaceShip:
		(ship as SpaceShip).add_fuel_amount(amount)


func trigger_game_over(reason: String) -> void:
	if game_over_occurred:
		return
	game_over_occurred = true
	game_over.emit(reason)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func count_item_of_type(item_type: Item.Item_Type) -> int:
	var total: int = 0
	for entry in inventory:
		if entry.type == item_type:
			total += 1
	return total


func remove_items_of_type(item_type: Item.Item_Type, amount: int) -> void:
	var removed: int = 0
	var index: int = inventory.size() - 1
	while index >= 0 and removed < amount:
		if inventory[index].type == item_type:
			inventory.remove_at(index)
			removed += 1
		index -= 1


func try_remove_one_item(item_type: Item.Item_Type) -> bool:
	for i in range(inventory.size()):
		if inventory[i].type == item_type:
			inventory.remove_at(i)
			update_ui.emit()
			return true
	return false


func can_afford_items(metal_needed: int, rock_needed: int) -> bool:
	return (
		metal_needed >= 0
		and rock_needed >= 0
		and count_item_of_type(Item.Item_Type.METAL) >= metal_needed
		and count_item_of_type(Item.Item_Type.ROCK) >= rock_needed
	)


func try_spend_items(metal_needed: int, rock_needed: int) -> bool:
	if not can_afford_items(metal_needed, rock_needed):
		return false
	remove_items_of_type(Item.Item_Type.METAL, metal_needed)
	remove_items_of_type(Item.Item_Type.ROCK, rock_needed)
	update_ui.emit()
	return true
