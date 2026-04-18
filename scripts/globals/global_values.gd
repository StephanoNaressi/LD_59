extends Node

var player: Player

var inventory: Array[Item]

signal update_ui
signal antenna_repair_hud_changed(antenna: Antenna)

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


func can_afford_items(metal_needed: int, rock_needed: int) -> bool:
	if metal_needed < 0 or rock_needed < 0:
		return false
	if count_item_of_type(Item.Item_Type.METAL) < metal_needed:
		return false
	if count_item_of_type(Item.Item_Type.ROCK) < rock_needed:
		return false
	return true


func try_spend_items(metal_needed: int, rock_needed: int) -> bool:
	if not can_afford_items(metal_needed, rock_needed):
		return false
	remove_items_of_type(Item.Item_Type.METAL, metal_needed)
	remove_items_of_type(Item.Item_Type.ROCK, rock_needed)
	update_ui.emit()
	return true
