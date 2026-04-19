extends Node

var player: Player

var radar_ping_until_sec: float = 0.0
var radar_ping_start_sec: float = 0.0

var inventory: Array[Item]

var game_over_occurred: bool = false

signal update_ui
signal antenna_repair_hud_changed(antenna: Antenna)
signal game_over(reason: String)
signal loot_toast(text: String)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not game_over_occurred:
		return
	if event.is_action_pressed(&"RestartGame"):
		restart_game()
		get_viewport().set_input_as_handled()


func restart_game() -> void:
	game_over_occurred = false
	inventory.clear()
	radar_ping_until_sec = 0.0
	radar_ping_start_sec = 0.0
	player = null
	get_tree().paused = false
	var err: Error = get_tree().reload_current_scene()
	if err != OK:
		push_error("Failed to reload scene: %s" % error_string(err))


func play_sfx_at(
	stream: AudioStream,
	world_position: Vector3,
	volume_db: float = -14.0,
	pitch_scale: float = 1.0,
	max_distance: float = 320.0
) -> void:
	if stream == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var sfx_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	scene.add_child(sfx_player)
	sfx_player.stream = stream
	sfx_player.volume_db = volume_db
	sfx_player.pitch_scale = pitch_scale
	sfx_player.max_distance = max_distance
	sfx_player.global_position = world_position
	sfx_player.finished.connect(sfx_player.queue_free)
	sfx_player.play()


func start_radar_ping(duration_sec: float = 3.4) -> void:
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	radar_ping_start_sec = now_sec
	radar_ping_until_sec = now_sec + duration_sec


func show_meteor_reward_toast(resource: Item.Item_Type, pickup_count: int) -> void:
	if game_over_occurred:
		return
	var suffix: String = "  +Fuel"
	match resource:
		Item.Item_Type.OXYGEN, Item.Item_Type.WATER:
			suffix = "  +Fuel  (life support)"
		_:
			pass
	loot_toast.emit("+%s %d%s" % [Item.type_name(resource), pickup_count, suffix])


func add_fuel_from_meteor(amount: float = 0.07) -> void:
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


func count_items(item_type: Item.Item_Type) -> int:
	var total: int = 0
	for entry in inventory:
		if entry.type == item_type:
			total += 1
	return total


func remove_items(item_type: Item.Item_Type, amount: int) -> void:
	var removed: int = 0
	var index: int = inventory.size() - 1
	while index >= 0 and removed < amount:
		if inventory[index].type == item_type:
			inventory.remove_at(index)
			removed += 1
		index -= 1


func try_remove_one_item(item_type: Item.Item_Type) -> bool:
	for inventory_index in range(inventory.size()):
		if inventory[inventory_index].type == item_type:
			inventory.remove_at(inventory_index)
			update_ui.emit()
			return true
	return false


func has_items_for_cost(
	metal_needed: int,
	rock_needed: int,
	oxygen_needed: int = 0,
	water_needed: int = 0
) -> bool:
	return (
		metal_needed >= 0
		and rock_needed >= 0
		and oxygen_needed >= 0
		and water_needed >= 0
		and count_items(Item.Item_Type.METAL) >= metal_needed
		and count_items(Item.Item_Type.ROCK) >= rock_needed
		and count_items(Item.Item_Type.OXYGEN) >= oxygen_needed
		and count_items(Item.Item_Type.WATER) >= water_needed
	)


func spend_items_if_possible(
	metal_needed: int,
	rock_needed: int,
	oxygen_needed: int = 0,
	water_needed: int = 0
) -> bool:
	if not has_items_for_cost(metal_needed, rock_needed, oxygen_needed, water_needed):
		return false
	remove_items(Item.Item_Type.METAL, metal_needed)
	remove_items(Item.Item_Type.ROCK, rock_needed)
	remove_items(Item.Item_Type.OXYGEN, oxygen_needed)
	remove_items(Item.Item_Type.WATER, water_needed)
	update_ui.emit()
	return true
