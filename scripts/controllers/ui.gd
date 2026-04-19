extends MarginContainer

const HUD_MAIN: Color = Color(0.55, 0.62, 0.7, 0.95)
const HUD_MUTED: Color = Color(0.45, 0.52, 0.58, 0.88)
const HUD_HINT: Color = Color(0.66, 0.73, 0.8, 0.95)
const LIFE_SUPPORT_WARNING_PCT: int = 15

@onready var rocks: Label = $VBoxRoot/HBoxContainer/Rocks
@onready var metal: Label = $VBoxRoot/HBoxContainer/Metal
@onready var resource_row: HBoxContainer = $VBoxRoot/HBoxContainer
@onready var antenna_info: Label = $"../AntennaInfo"
@onready var player_coords: Label = $VBoxRoot/PlayerCoords
@onready var antenna_coords: Label = $VBoxRoot/AntennaCoords
@onready var ship_speed: Label = $VBoxRoot/ShipSpeed
@onready var antenna_repair_panel: PanelContainer = $VBoxRoot/AntennaRepairPanel
@onready var antenna_repair_progress: ProgressBar = (
	$VBoxRoot/AntennaRepairPanel/MarginContainer/RepairVBox/RepairProgressBar
)
@onready var antenna_repair_label: Label = (
	$VBoxRoot/AntennaRepairPanel/MarginContainer/RepairVBox/AntennaRepairLabel
)
@onready var markers_label: Label = $VBoxRoot/MarkersLabel
@onready var hints: Label = $VBoxRoot/Hints
@onready var game_over_overlay: ColorRect = $"../GameOverOverlay"
@onready var game_over_label: Label = $"../GameOverOverlay/GameOverLabel"
@onready var loot_toast: Label = $"../LootToast"

var antenna_hud_target: Antenna = null
var loot_toast_hide_seconds_remaining: float = 0.0


func _ready() -> void:
	apply_hud_visuals()
	GlobalValues.update_ui.connect(on_inventory_changed)
	GlobalValues.antenna_repair_hud_changed.connect(on_antenna_repair_target_changed)
	GlobalValues.game_over.connect(on_game_over)
	GlobalValues.loot_toast.connect(on_loot_toast)
	GlobalValues.map_markers_changed.connect(refresh_map_markers)
	GlobalValues.update_ui.emit()
	refresh_map_markers()
	call_deferred("refresh_antenna_info")


func apply_hud_visuals() -> void:
	for label: Label in [rocks, metal, player_coords, ship_speed]:
		label.add_theme_color_override(&"font_color", HUD_MAIN)
	resource_row.visible = false
	antenna_coords.visible = false
	hints.add_theme_color_override(&"font_color", HUD_HINT)
	hints.add_theme_font_size_override(&"font_size", 12)
	player_coords.add_theme_font_size_override(&"font_size", 14)
	ship_speed.add_theme_font_size_override(&"font_size", 14)
	antenna_info.add_theme_color_override(&"font_color", HUD_MAIN)
	antenna_info.add_theme_font_size_override(&"font_size", 11)
	if game_over_label != null:
		game_over_label.add_theme_color_override(&"font_color", Color(0.62, 0.68, 0.74, 1))
		game_over_label.add_theme_font_size_override(&"font_size", 22)
	antenna_repair_progress.add_theme_color_override(&"font_color", HUD_MAIN)
	antenna_repair_label.add_theme_color_override(&"font_color", HUD_MAIN)
	antenna_repair_label.add_theme_font_size_override(&"font_size", 15)
	if loot_toast != null:
		loot_toast.add_theme_color_override(&"font_color", Color(0.94, 0.97, 0.92, 1))
		loot_toast.add_theme_color_override(&"font_outline_color", Color(0.05, 0.07, 0.06, 1))
		loot_toast.add_theme_constant_override(&"outline_size", 5)
		loot_toast.add_theme_font_size_override(&"font_size", 22)
		loot_toast.z_index = 95
	markers_label.add_theme_color_override(&"font_color", HUD_MUTED)
	markers_label.add_theme_font_size_override(&"font_size", 11)


func _process(delta: float) -> void:
	update_navigation_readout()
	sync_repair_progress_bar()
	if loot_toast_hide_seconds_remaining > 0.0:
		loot_toast_hide_seconds_remaining -= delta
		if loot_toast_hide_seconds_remaining <= 0.0 and loot_toast != null:
			loot_toast.visible = false


func on_loot_toast(text: String) -> void:
	if loot_toast == null:
		return
	loot_toast.text = text
	loot_toast.visible = true
	loot_toast_hide_seconds_remaining = 2.2


func on_game_over(reason: String) -> void:
	if game_over_label != null:
		game_over_label.text = "Game over\n%s\n\nR — restart" % reason
	if game_over_overlay != null:
		game_over_overlay.visible = true


func on_antenna_repair_target_changed(antenna: Antenna) -> void:
	antenna_hud_target = antenna
	refresh_antenna_repair_panel()
	refresh_antenna_info()


func refresh_antenna_repair_panel() -> void:
	if (
		antenna_hud_target == null
		or not is_instance_valid(antenna_hud_target)
		or antenna_hud_target.is_repaired
	):
		antenna_repair_panel.visible = false
		antenna_repair_progress.value = 0.0
		return
	var target_antenna: Antenna = antenna_hud_target
	antenna_repair_progress.value = target_antenna.repair_progress * 100.0
	var rock_count: int = GlobalValues.count_items(Item.Item_Type.ROCK)
	var metal_count: int = GlobalValues.count_items(Item.Item_Type.METAL)
	var pilot_ship: SpaceShip = (
		GlobalValues.player.vehicle
		if GlobalValues.player != null and GlobalValues.player.vehicle is SpaceShip
		else null
	)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Resources needed to fix")
	lines.append(target_antenna.name)
	lines.append("")
	lines.append("Rock %d / %d" % [rock_count, target_antenna.rock_cost])
	lines.append("Metal %d / %d" % [metal_count, target_antenna.metal_cost])
	if target_antenna.oxygen_cost > 0 or target_antenna.water_cost > 0:
		if pilot_ship != null:
			if target_antenna.oxygen_cost > 0:
				lines.append("Oxygen %d%%" % target_antenna.oxygen_cost)
			if target_antenna.water_cost > 0:
				lines.append("Water %d%%" % target_antenna.water_cost)
		else:
			lines.append("Board the ship for oxygen & water")
	var text: String = "\n".join(lines)
	if GlobalValues.has_items_for_cost(
		target_antenna.metal_cost,
		target_antenna.rock_cost,
		target_antenna.oxygen_cost,
		target_antenna.water_cost
	):
		text += "\nRight Mouse Button to repair"
	antenna_repair_label.text = text
	antenna_repair_panel.visible = true


func sync_repair_progress_bar() -> void:
	if not antenna_repair_panel.visible:
		return
	if (
		antenna_hud_target == null
		or not is_instance_valid(antenna_hud_target)
		or antenna_hud_target.is_repaired
	):
		return
	antenna_repair_progress.value = antenna_hud_target.repair_progress * 100.0


func refresh_antenna_info() -> void:
	var antennas: Array[Antenna] = []
	for node in get_tree().get_nodes_in_group(TowerRegistry.GROUP_ANTENNAS):
		if node is Antenna:
			antennas.append(node as Antenna)
	antennas.sort_custom(func(a: Antenna, b: Antenna) -> bool: return str(a.name) < str(b.name))
	var total: int = antennas.size()
	var fixed_count: int = 0
	var repaired_names: PackedStringArray = PackedStringArray()
	for antenna in antennas:
		if antenna.is_repaired:
			fixed_count += 1
			repaired_names.append(antenna.name)
	var header: String = "Antennas: %d / %d fixed" % [fixed_count, total]
	if repaired_names.is_empty():
		antenna_info.text = header
	else:
		antenna_info.text = header + "\n" + "\n".join(repaired_names)


func refresh_map_markers() -> void:
	if GlobalValues.map_marker_positions.is_empty():
		markers_label.text = ""
		markers_label.visible = false
		return
	var lines: PackedStringArray = PackedStringArray()
	var index: int = 0
	for marker_position in GlobalValues.map_marker_positions:
		index += 1
		lines.append(
			"%d. X %d  Y %d  Z %d"
			% [index, roundi(marker_position.x), roundi(marker_position.y), roundi(marker_position.z)]
		)
	markers_label.text = "Markers (max %d)\n%s" % [GlobalValues.MAX_MAP_MARKERS, "\n".join(lines)]
	markers_label.visible = true


func on_inventory_changed() -> void:
	var rock_count: int = GlobalValues.count_items(Item.Item_Type.ROCK)
	var metal_count: int = GlobalValues.count_items(Item.Item_Type.METAL)
	rocks.text = "Rock %d" % rock_count
	metal.text = "Metal %d" % metal_count
	refresh_antenna_repair_panel()
	refresh_antenna_info()


func update_navigation_readout() -> void:
	var player: Player = GlobalValues.player
	var navigation_root: Node3D = (
		player.vehicle if player != null and player.vehicle != null else player
	)
	if navigation_root != null:
		var world_position: Vector3 = navigation_root.global_position
		player_coords.text = "X %d  Y %d  Z %d" % [
			roundi(world_position.x),
			roundi(world_position.y),
			roundi(world_position.z),
		]
	var ship: SpaceShip = player.vehicle if player != null else null
	if ship != null:
		ship_speed.visible = true
		var speed: float = ship.velocity.length()
		var oxygen_percent: int = int(roundf(100.0 * ship.oxygen_tank_fill / ship.TANK_CAPACITY))
		var water_percent: int = int(roundf(100.0 * ship.water_tank_fill / ship.TANK_CAPACITY))
		var fuel_percent: int = int(roundf(100.0 * ship.fuel))
		var rock_count: int = GlobalValues.count_items(Item.Item_Type.ROCK)
		var metal_count: int = GlobalValues.count_items(Item.Item_Type.METAL)
		ship_speed.text = (
			"Speed %.0f m/s  |  Cruise %.0f m/s\nFuel %d%%  |  O₂ %d%%  |  H₂O %d%%  |  Rock %d  |  Metal %d"
			% [
				speed,
				ship.cruise_speed,
				fuel_percent,
				oxygen_percent,
				water_percent,
				rock_count,
				metal_count,
			]
		)
		if oxygen_percent <= LIFE_SUPPORT_WARNING_PCT or water_percent <= LIFE_SUPPORT_WARNING_PCT:
			ship_speed.text += "\nWARNING: LIFE SUPPORT LOW"
	else:
		ship_speed.visible = false
