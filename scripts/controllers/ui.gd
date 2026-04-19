extends MarginContainer

const HUD_MAIN := Color(0.55, 0.62, 0.7, 0.95)
const HUD_MUTED := Color(0.45, 0.52, 0.58, 0.88)
const HUD_HINT := Color(0.66, 0.73, 0.8, 0.95)
const LIFE_SUPPORT_WARNING_PCT: int = 15

@onready var rocks: Label = $VBoxRoot/HBoxContainer/Rocks
@onready var metal: Label = $VBoxRoot/HBoxContainer/Metal
@onready var player_coords: Label = $VBoxRoot/PlayerCoords
@onready var tower_coords: Label = $VBoxRoot/TowerCoords
@onready var ship_speed: Label = $VBoxRoot/ShipSpeed
@onready var antenna_repair_panel: PanelContainer = $VBoxRoot/AntennaRepairPanel
@onready var antenna_repair_label: Label = $VBoxRoot/AntennaRepairPanel/MarginContainer/AntennaRepairLabel
@onready var hints: Label = $VBoxRoot/Hints
@onready var game_over_overlay: ColorRect = $"../GameOverOverlay"
@onready var game_over_label: Label = $"../GameOverOverlay/GameOverLabel"
@onready var loot_toast: Label = $"../LootToast"

var antenna_hud_target: Antenna = null
var loot_toast_hide_seconds_remaining: float = 0.0


func _ready() -> void:
	_apply_hud_visuals()
	GlobalValues.update_ui.connect(on_inventory_changed)
	GlobalValues.antenna_repair_hud_changed.connect(on_antenna_repair_target_changed)
	GlobalValues.game_over.connect(_on_game_over)
	GlobalValues.loot_toast.connect(_on_loot_toast)
	GlobalValues.update_ui.emit()


func _apply_hud_visuals() -> void:
	for label: Label in [rocks, metal, player_coords, ship_speed]:
		if label == null:
			continue
		label.add_theme_color_override(&"font_color", HUD_MAIN)
	if tower_coords != null:
		tower_coords.visible = false
	if hints != null:
		hints.add_theme_color_override(&"font_color", HUD_HINT)
		hints.add_theme_font_size_override(&"font_size", 12)
	if player_coords != null:
		player_coords.add_theme_font_size_override(&"font_size", 14)
	if ship_speed != null:
		ship_speed.add_theme_font_size_override(&"font_size", 14)
	if game_over_label != null:
		game_over_label.add_theme_color_override(&"font_color", Color(0.62, 0.68, 0.74, 1))
		game_over_label.add_theme_font_size_override(&"font_size", 22)
	if antenna_repair_label != null:
		antenna_repair_label.add_theme_color_override(&"font_color", HUD_MAIN)
		antenna_repair_label.add_theme_font_size_override(&"font_size", 15)
	if loot_toast != null:
		loot_toast.add_theme_color_override(&"font_color", Color(0.52, 0.72, 0.58, 0.96))
		loot_toast.add_theme_font_size_override(&"font_size", 16)


func _process(delta: float) -> void:
	update_navigation_readout()
	if loot_toast_hide_seconds_remaining > 0.0:
		loot_toast_hide_seconds_remaining -= delta
		if loot_toast_hide_seconds_remaining <= 0.0 and loot_toast != null:
			loot_toast.visible = false


func _on_loot_toast(text: String) -> void:
	if loot_toast == null:
		return
	loot_toast.text = text
	loot_toast.visible = true
	loot_toast_hide_seconds_remaining = 2.2


func _on_game_over(reason: String) -> void:
	if game_over_label != null:
		game_over_label.text = "Game over\n%s\n\nR — restart" % reason
	if game_over_overlay != null:
		game_over_overlay.visible = true


func on_antenna_repair_target_changed(antenna: Antenna) -> void:
	antenna_hud_target = antenna
	refresh_antenna_repair_panel()


func refresh_antenna_repair_panel() -> void:
	if antenna_repair_panel == null or antenna_repair_label == null:
		return
	if (
		antenna_hud_target == null
		or not is_instance_valid(antenna_hud_target)
		or antenna_hud_target.is_repaired
	):
		antenna_repair_panel.visible = false
		return
	var target_antenna: Antenna = antenna_hud_target
	var rock_count: int = GlobalValues.count_item_of_type(Item.Item_Type.ROCK)
	var metal_count: int = GlobalValues.count_item_of_type(Item.Item_Type.METAL)
	var text: String = "%s\nRock %d/%d  Metal %d/%d" % [
		target_antenna.name,
		rock_count,
		target_antenna.rock_cost,
		metal_count,
		target_antenna.metal_cost,
	]
	if GlobalValues.can_afford_items(target_antenna.metal_cost, target_antenna.rock_cost):
		text += "\nRight Mouse Button to repair"
	antenna_repair_label.text = text
	antenna_repair_panel.visible = true


func on_inventory_changed() -> void:
	var rock_count: int = GlobalValues.count_item_of_type(Item.Item_Type.ROCK)
	var metal_count: int = GlobalValues.count_item_of_type(Item.Item_Type.METAL)
	rocks.text = "Rock %d" % rock_count
	metal.text = "Metal %d" % metal_count
	refresh_antenna_repair_panel()


func update_navigation_readout() -> void:
	if player_coords == null:
		return
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
	if ship_speed != null:
		var ship: SpaceShip = player.vehicle if player != null else null
		if ship != null:
			ship_speed.visible = true
			var speed: float = ship.velocity.length()
			var oxygen_percent: int = int(roundf(100.0 * ship.oxygen_tank_fill / ship.TANK_CAPACITY))
			var water_percent: int = int(roundf(100.0 * ship.water_tank_fill / ship.TANK_CAPACITY))
			var fuel_percent: int = int(roundf(100.0 * ship.fuel))
			ship_speed.text = "Speed %.0f m/s  |  Cruise %.0f m/s\nFuel %d%%  |  O₂ %d%%  |  H₂O %d%%" % [
				speed,
				ship.cruise_speed,
				fuel_percent,
				oxygen_percent,
				water_percent,
			]
			if oxygen_percent <= LIFE_SUPPORT_WARNING_PCT or water_percent <= LIFE_SUPPORT_WARNING_PCT:
				ship_speed.text += "\nWARNING: LIFE SUPPORT LOW"
		else:
			ship_speed.visible = false
