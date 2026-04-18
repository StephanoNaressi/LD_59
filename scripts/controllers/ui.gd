extends MarginContainer

@onready var rocks: Label = $VBoxRoot/HBoxContainer/Rocks
@onready var metal: Label = $VBoxRoot/HBoxContainer/Metal
@onready var antenna_repair_panel: PanelContainer = $VBoxRoot/AntennaRepairPanel
@onready var antenna_repair_label: Label = $VBoxRoot/AntennaRepairPanel/MarginContainer/AntennaRepairLabel

var _antenna_hud_target: Antenna = null


func _ready() -> void:
	GlobalValues.update_ui.connect(on_update_ui)
	GlobalValues.antenna_repair_hud_changed.connect(_on_antenna_repair_hud_changed)
	GlobalValues.update_ui.emit()


func _on_antenna_repair_hud_changed(antenna: Antenna) -> void:
	_antenna_hud_target = antenna
	refresh_antenna_repair_hud()


func refresh_antenna_repair_hud() -> void:
	if antenna_repair_panel == null or antenna_repair_label == null:
		return
	if _antenna_hud_target == null or not is_instance_valid(_antenna_hud_target) or _antenna_hud_target.is_repaired:
		antenna_repair_panel.visible = false
		return
	var a: Antenna = _antenna_hud_target
	var m_have: int = GlobalValues.count_item_of_type(Item.Item_Type.METAL)
	var r_have: int = GlobalValues.count_item_of_type(Item.Item_Type.ROCK)
	var lines: String = "ROCKS %d/%d\nMETAL %d/%d" % [r_have, a.rock_cost, m_have, a.metal_cost]
	if GlobalValues.can_afford_items(a.metal_cost, a.rock_cost):
		lines += "\nRight click to repair"
	antenna_repair_label.text = lines
	antenna_repair_panel.visible = true


func on_update_ui() -> void:
	var rock_n: int = GlobalValues.count_item_of_type(Item.Item_Type.ROCK)
	var metal_n: int = GlobalValues.count_item_of_type(Item.Item_Type.METAL)
	rocks.text = "ROCKS: " + str(rock_n)
	metal.text = "METAL: " + str(metal_n)
	refresh_antenna_repair_hud()
