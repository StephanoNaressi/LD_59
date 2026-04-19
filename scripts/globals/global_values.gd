extends Node

var player: Player

var radar_ping_until_sec: float = 0.0
var radar_ping_start_sec: float = 0.0

var inventory: Array[Item]

var game_over_occurred: bool = false

const MAX_MAP_MARKERS: int = 8
var map_marker_positions: Array[Vector3] = []

signal update_ui
signal antenna_repair_hud_changed(antenna: Antenna)
signal game_over(reason: String)
signal loot_toast(text: String)
signal map_markers_changed


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
	map_marker_positions.clear()
	map_markers_changed.emit()
	radar_ping_until_sec = 0.0
	radar_ping_start_sec = 0.0
	player = null
	get_tree().paused = false
	var err: Error = get_tree().reload_current_scene()
	if err != OK:
		push_error("Failed to reload scene: %s" % error_string(err))


func play_sfx_at(
	audio_stream: AudioStream,
	world_position: Vector3,
	volume_db: float = AudioLevels.SFX_DEFAULT_VOLUME_DB,
	pitch_scale: float = 1.0,
	max_distance: float = 320.0
) -> void:
	if audio_stream == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var sfx_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	scene.add_child(sfx_player)
	sfx_player.stream = audio_stream
	sfx_player.volume_db = volume_db
	sfx_player.pitch_scale = pitch_scale
	sfx_player.max_distance = max_distance
	sfx_player.unit_size = 48.0
	sfx_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	sfx_player.global_position = world_position
	sfx_player.finished.connect(sfx_player.queue_free)
	sfx_player.play()


func play_break_sfx(
	audio_stream: AudioStream,
	volume_db: float = AudioLevels.SFX_BREAK_VOLUME_DB,
	pitch_scale: float = 1.0
) -> void:
	if audio_stream == null:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	scene.add_child(player)
	player.stream = audio_stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.finished.connect(player.queue_free)
	player.play()


func push_map_marker(world_position: Vector3) -> void:
	map_marker_positions.append(world_position)
	while map_marker_positions.size() > MAX_MAP_MARKERS:
		map_marker_positions.pop_front()
	map_markers_changed.emit()


func start_radar_ping(duration_sec: float = 3.4) -> void:
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	radar_ping_start_sec = now_sec
	radar_ping_until_sec = now_sec + duration_sec


func show_meteor_reward_toast(resource: Item.Item_Type, pickup_count: int) -> void:
	if game_over_occurred:
		return
	loot_toast.emit("+%s %d  +Fuel" % [Item.type_name(resource), pickup_count])


func get_next_antenna_to_repair() -> Antenna:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var antennas: Array[Antenna] = []
	for node in tree.get_nodes_in_group(TowerRegistry.GROUP_ANTENNAS):
		if node is Antenna:
			antennas.append(node as Antenna)
	antennas.sort_custom(func(a: Antenna, b: Antenna) -> bool: return str(a.name) < str(b.name))
	for antenna in antennas:
		if not antenna.is_repaired:
			return antenna
	return null


func add_fuel_from_meteor(amount: float = 0.052) -> void:
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


func get_piloted_ship() -> SpaceShip:
	if player == null or not (player.vehicle is SpaceShip):
		return null
	return player.vehicle as SpaceShip


func has_items_for_cost(
	metal_needed: int,
	rock_needed: int,
	oxygen_pct_of_current: int = 0,
	water_pct_of_current: int = 0
) -> bool:
	if metal_needed < 0 or rock_needed < 0 or oxygen_pct_of_current < 0 or water_pct_of_current < 0:
		return false
	if count_items(Item.Item_Type.METAL) < metal_needed or count_items(Item.Item_Type.ROCK) < rock_needed:
		return false
	if oxygen_pct_of_current == 0 and water_pct_of_current == 0:
		return true
	var ship: SpaceShip = get_piloted_ship()
	if ship == null:
		return false
	return ship.can_afford_life_support_percent_cost(oxygen_pct_of_current, water_pct_of_current)


func spend_items_if_possible(
	metal_needed: int,
	rock_needed: int,
	oxygen_pct_of_current: int = 0,
	water_pct_of_current: int = 0
) -> bool:
	if not has_items_for_cost(metal_needed, rock_needed, oxygen_pct_of_current, water_pct_of_current):
		return false
	remove_items(Item.Item_Type.METAL, metal_needed)
	remove_items(Item.Item_Type.ROCK, rock_needed)
	var ship: SpaceShip = get_piloted_ship()
	if ship != null and (oxygen_pct_of_current > 0 or water_pct_of_current > 0):
		ship.apply_life_support_percent_cost(oxygen_pct_of_current, water_pct_of_current)
	update_ui.emit()
	return true
