extends StaticBody3D
class_name Antenna

@export var metal_cost: int = 1
@export var rock_cost: int = 1
@export var crosshair_marker: Marker3D
@export var repair_charge_per_hit: float = 0.05

signal was_repaired

var is_repaired: bool = false
var repair_progress: float = 0.0

@onready var broken_mesh: Node3D = $BrokenMesh
@onready var fixed_mesh: Node3D = $FixedMesh
@onready var repair_progress_root: Node3D = $RepairProgressRoot
@onready var repair_viewport: SubViewport = $RepairProgressRoot/RepairSubViewport
@onready var repair_progress_bar: ProgressBar = $RepairProgressRoot/RepairSubViewport/ProgressRoot/RepairProgressBar
@onready var repair_billboard: Sprite3D = $RepairProgressRoot/RepairBillboard


func _ready() -> void:
	if crosshair_marker:
		crosshair_marker.visible = false
	repair_progress_root.visible = false
	call_deferred("connect_repair_billboard_texture")


func connect_repair_billboard_texture() -> void:
	if repair_billboard and repair_viewport:
		repair_billboard.texture = repair_viewport.get_texture()


func get_weapon_aim_position() -> Vector3:
	if crosshair_marker:
		return crosshair_marker.global_position
	return global_position + Vector3(0, 2.0, 0)


func reset_repair_progress() -> void:
	if is_repaired:
		return
	repair_progress = 0.0
	update_repair_ui()


func untarget_destroyable() -> void:
	if crosshair_marker:
		crosshair_marker.visible = false
	reset_repair_progress()


func target_destroyable() -> void:
	if crosshair_marker and not is_repaired:
		crosshair_marker.visible = true


func update_repair_ui() -> void:
	if repair_progress_bar:
		repair_progress_bar.value = repair_progress * 100.0
	var show_bar: bool = repair_progress > 0.001 and repair_progress < 0.999 and not is_repaired
	repair_progress_root.visible = show_bar


func apply_repair_hit() -> void:
	if is_repaired:
		return
	repair_progress = minf(repair_progress + repair_charge_per_hit, 1.0)
	update_repair_ui()
	if repair_progress < 1.0:
		return
	complete_repair()


func complete_repair() -> void:
	if is_repaired:
		return
	if not GlobalValues.try_spend_items(metal_cost, rock_cost):
		repair_progress = 0.85
		update_repair_ui()
		return
	is_repaired = true
	broken_mesh.visible = false
	fixed_mesh.visible = true
	repair_progress_root.visible = false
	RepairProyectile.despawn_all_in_tree(get_tree())
	untarget_destroyable()
	was_repaired.emit()
