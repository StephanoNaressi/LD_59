extends MarginContainer


@onready var rocks: Label = $VBoxRoot/HBoxContainer/Rocks
@onready var metal: Label = $VBoxRoot/HBoxContainer/Metal
@onready var player_coords: Label = $VBoxRoot/PlayerCoords
@onready var tower_coords: Label = $VBoxRoot/TowerCoords
@onready var ship_speed: Label = $VBoxRoot/ShipSpeed
@onready var antenna_repair_panel: PanelContainer = $VBoxRoot/AntennaRepairPanel
@onready var antenna_repair_label: Label = $VBoxRoot/AntennaRepairPanel/MarginContainer/AntennaRepairLabel

var antenna_hud_target: Antenna = null


func _ready() -> void:
	GlobalValues.update_ui.connect(on_inventory_changed)
	GlobalValues.antenna_repair_hud_changed.connect(on_antenna_repair_target_changed)
	GlobalValues.update_ui.emit()


func _process(_delta: float) -> void:
	update_navigation_readout()


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
	var text: String = "Repair %s\nRocks %d / %d\nMetal %d / %d" % [a.name, r_have, a.rock_cost, m_have, a.metal_cost]
	if GlobalValues.can_afford_items(a.metal_cost, a.rock_cost):
		text += "\nRight-click to fire repair"
	antenna_repair_label.text = text
	antenna_repair_panel.visible = true


func on_inventory_changed() -> void:
	var rock_n: int = GlobalValues.count_item_of_type(Item.Item_Type.ROCK)
	var metal_n: int = GlobalValues.count_item_of_type(Item.Item_Type.METAL)
	rocks.text = "Rocks  %d" % rock_n
	metal.text = "Metal  %d" % metal_n
	refresh_antenna_repair_panel()


func update_navigation_readout() -> void:
	if player_coords == null or tower_coords == null:
		return
	var nav: Node3D = null
	if GlobalValues.player != null:
		if GlobalValues.player.vehicle != null:
			nav = GlobalValues.player.vehicle
		else:
			nav = GlobalValues.player
	if nav != null:
		var p: Vector3 = nav.global_position
		player_coords.text = "Position   X %d   Y %d   Z %d" % [roundi(p.x), roundi(p.y), roundi(p.z)]
	if ship_speed != null:
		if GlobalValues.player != null and GlobalValues.player.vehicle != null:
			var s: SpaceShip = GlobalValues.player.vehicle
			ship_speed.visible = true
			var spd: float = s.velocity.length()
			ship_speed.text = "Speed  %.0f / %.0f   (mouse wheel sets cruise)" % [spd, s.cruise_speed]
		else:
			ship_speed.visible = false
	var lines: PackedStringArray = GlobalValues.tower_list_lines()
	if lines.size() == 0:
		tower_coords.text = "Towers — none registered"
	else:
		var tower_text: String = "Towers\n"
		for i in range(lines.size()):
			if i > 0:
				tower_text += "\n"
			tower_text += lines[i]
		tower_coords.text = tower_text
