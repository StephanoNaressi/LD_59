extends StaticBody3D
class_name Antenna

#region exports
const WELL_DONE_SFX: AudioStream = preload("res://game/audios/well_done.ogg")

@export var metal_cost: int = 2
@export var rock_cost: int = 2
@export var oxygen_cost: int = 0
@export var water_cost: int = 0
@export var crosshair_marker: Marker3D
@export var repair_charge_per_hit: float = 0.05
@export var music_stream: AudioStream
@export var planet_spin_deg_per_sec: float = 2.2
#endregion

#region signals
signal was_repaired
#endregion

#region state
var is_repaired: bool = false
var repair_progress: float = 0.0
#endregion

#region nodes
@onready var broken_mesh: Node3D = $BrokenMesh
@onready var fixed_mesh: Node3D = $FixedMesh
@onready var repair_progress_root: Node3D = $RepairProgressRoot
@onready var repair_viewport: SubViewport = $RepairProgressRoot/RepairSubViewport
@onready var repair_progress_bar: ProgressBar = $RepairProgressRoot/RepairSubViewport/ProgressRoot/RepairProgressBar
@onready var repair_billboard: Sprite3D = $RepairProgressRoot/RepairBillboard
@onready var tower_music: AudioStreamPlayer3D = $TowerMusic
#endregion

var _tower_music_max_distance_base: float = 20000.0


func _ready() -> void:
	add_to_group(TowerRegistry.GROUP_ANTENNAS)
	if crosshair_marker:
		crosshair_marker.visible = false
	repair_progress_root.visible = false
	if music_stream != null:
		tower_music.stream = music_stream
	tower_music.volume_db = -16.0
	_tower_music_max_distance_base = tower_music.max_distance
	tower_music.max_distance = minf(_tower_music_max_distance_base, 900.0)
	call_deferred("connect_repair_billboard_texture")


func planet_surface_radius() -> float:
	if crosshair_marker:
		var d: float = global_position.distance_to(crosshair_marker.global_position)
		if d > 1.0:
			return d
	return 80.0


static func closest_to(world_position: Vector3, tree: SceneTree) -> Antenna:
	var best: Antenna = null
	var best_distance: float = INF
	for node in tree.get_nodes_in_group(TowerRegistry.GROUP_ANTENNAS):
		var antenna: Antenna = node as Antenna
		if antenna == null:
			continue
		var distance: float = world_position.distance_to(antenna.global_position)
		if distance < best_distance:
			best_distance = distance
			best = antenna
	return best


func set_tower_music_playing(playing: bool) -> void:
	if music_stream == null:
		if tower_music.playing:
			tower_music.stop()
		return
	if not playing:
		tower_music.stop()
		return
	if not tower_music.playing:
		tower_music.play()


func connect_repair_billboard_texture() -> void:
	if repair_billboard != null and repair_viewport != null:
		repair_billboard.texture = repair_viewport.get_texture()


func _process(delta: float) -> void:
	global_rotate(Vector3.UP, deg_to_rad(planet_spin_deg_per_sec) * delta)


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
	if is_repaired:
		return
	if crosshair_marker:
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
	if not GlobalValues.spend_items_if_possible(metal_cost, rock_cost, oxygen_cost, water_cost):
		repair_progress = 0.85
		update_repair_ui()
		return
	is_repaired = true
	GlobalValues.play_sfx_at(WELL_DONE_SFX, global_position, -12.0, 1.0, 900.0)
	tower_music.max_distance = maxf(_tower_music_max_distance_base, 22000.0)
	broken_mesh.visible = false
	fixed_mesh.visible = true
	repair_progress_root.visible = false
	RepairProyectile.despawn_all_in_tree(get_tree())
	untarget_destroyable()
	GlobalValues.antenna_repair_hud_changed.emit(null)
	was_repaired.emit()
