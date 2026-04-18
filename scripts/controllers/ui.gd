extends MarginContainer

const HUD_MAIN := Color(0.55, 0.62, 0.7, 0.95)
const HUD_MUTED := Color(0.45, 0.52, 0.58, 0.88)
const HUD_HINT := Color(0.4, 0.47, 0.54, 0.82)

@onready var rocks: Label = $VBoxRoot/HBoxContainer/Rocks
@onready var metal: Label = $VBoxRoot/HBoxContainer/Metal
@onready var oxygen_carry: Label = $VBoxRoot/HBoxContainer/Oxygen
@onready var water_carry: Label = $VBoxRoot/HBoxContainer/Water
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
var _loot_toast_hide_sec: float = 0.0


func _ready() -> void:
	_apply_hud_visuals()
	GlobalValues.update_ui.connect(on_inventory_changed)
	GlobalValues.antenna_repair_hud_changed.connect(on_antenna_repair_target_changed)
	GlobalValues.game_over.connect(_on_game_over)
	GlobalValues.loot_toast.connect(_on_loot_toast)
	GlobalValues.update_ui.emit()


func _apply_hud_visuals() -> void:
	for lb: Label in [rocks, metal, oxygen_carry, water_carry, player_coords, ship_speed]:
		if lb == null:
			continue
		lb.add_theme_color_override(&"font_color", HUD_MAIN)
	if tower_coords != null:
		tower_coords.add_theme_color_override(&"font_color", HUD_MUTED)
	if hints != null:
		hints.add_theme_color_override(&"font_color", HUD_HINT)
		hints.add_theme_font_size_override(&"font_size", 12)
	if player_coords != null:
		player_coords.add_theme_font_size_override(&"font_size", 14)
	if tower_coords != null:
		tower_coords.add_theme_font_size_override(&"font_size", 12)
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
	if _loot_toast_hide_sec > 0.0:
		_loot_toast_hide_sec -= delta
		if _loot_toast_hide_sec <= 0.0 and loot_toast != null:
			loot_toast.visible = false


func _on_loot_toast(text: String) -> void:
	if loot_toast == null:
		return
	loot_toast.text = text
	loot_toast.visible = true
	_loot_toast_hide_sec = 2.2


func _on_game_over(reason: String) -> void:
	if game_over_label != null:
		game_over_label.text = "Game over\n%s" % reason
	if game_over_overlay != null:
		game_over_overlay.visible = true


func on_antenna_repair_target_changed(antenna: Antenna) -> void:
	antenna_hud_target = antenna
	refresh_antenna_repair_panel()


func refresh_antenna_repair_panel() -> void:
	if antenna_repair_panel == null or antenna_repair_label == null:
		return
	if antenna_hud_target == null or not is_instance_valid(antenna_hud_target) or antenna_hud_target.is_repaired:
		antenna_repair_panel.visible = false
		return
	var a: Antenna = antenna_hud_target
	var m_have: int = GlobalValues.count_item_of_type(Item.Item_Type.METAL)
	var r_have: int = GlobalValues.count_item_of_type(Item.Item_Type.ROCK)
	var text: String = "%s\nR %d/%d  M %d/%d" % [a.name, r_have, a.rock_cost, m_have, a.metal_cost]
	if GlobalValues.can_afford_items(a.metal_cost, a.rock_cost):
		text += "\nRMB"
	antenna_repair_label.text = text
	antenna_repair_panel.visible = true


func on_inventory_changed() -> void:
	var rock_n: int = GlobalValues.count_item_of_type(Item.Item_Type.ROCK)
	var metal_n: int = GlobalValues.count_item_of_type(Item.Item_Type.METAL)
	var o2_n: int = GlobalValues.count_item_of_type(Item.Item_Type.OXYGEN)
	var h2o_n: int = GlobalValues.count_item_of_type(Item.Item_Type.WATER)
	rocks.text = "R %d" % rock_n
	metal.text = "M %d" % metal_n
	oxygen_carry.text = "O %d" % o2_n
	water_carry.text = "W %d" % h2o_n
	refresh_antenna_repair_panel()


func update_navigation_readout() -> void:
	if player_coords == null or tower_coords == null:
		return
	var p: Player = GlobalValues.player
	var nav: Node3D = p.vehicle if p != null and p.vehicle != null else p
	if nav != null:
		var pos: Vector3 = nav.global_position
		player_coords.text = "%d  %d  %d" % [roundi(pos.x), roundi(pos.y), roundi(pos.z)]
	if ship_speed != null:
		var s: SpaceShip = p.vehicle if p != null else null
		if s != null:
			ship_speed.visible = true
			var spd: float = s.velocity.length()
			var o2p: int = int(roundf(100.0 * s.oxygen_tank_fill / s.TANK_CAPACITY))
			var h2op: int = int(roundf(100.0 * s.water_tank_fill / s.TANK_CAPACITY))
			var fuelp: int = int(roundf(100.0 * s.fuel))
			ship_speed.text = "%.0f | %.0f  ·  F %d%%  O₂ %d%%  H₂O %d%%" % [spd, s.cruise_speed, fuelp, o2p, h2op]
		else:
			ship_speed.visible = false
	var lines: PackedStringArray = TowerRegistry.sorted_labels()
	if lines.size() == 0:
		tower_coords.text = "—"
		return
	tower_coords.text = "\n".join(lines)
