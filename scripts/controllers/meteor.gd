extends Destroyable
class_name Meteor

const DRIFT_INTERVAL_MIN: float = 2.0
const DRIFT_INTERVAL_MAX: float = 5.5
const DRIFT_IMPULSE_MIN: float = 0.12
const DRIFT_IMPULSE_MAX: float = 0.55

const OUTLINE_BY_DROP: Dictionary = {
	Item.Item_Type.ROCK: Color(0.72, 0.58, 0.42),
	Item.Item_Type.METAL: Color(0.82, 0.9, 1.0),
	Item.Item_Type.OXYGEN: Color(0.35, 0.92, 1.0),
	Item.Item_Type.WATER: Color(0.2, 0.48, 1.0),
}

@onready var drift_timer: Timer = $DriftTimer


func _ready() -> void:
	super._ready()
	call_deferred("_apply_stencil_outline_for_resource")
	drift_timer.timeout.connect(_on_drift_timer_timeout)
	_randomize_drift_wait_time()
	drift_timer.start()


func _apply_stencil_outline_for_resource() -> void:
	var c: Color = OUTLINE_BY_DROP.get(resource_drop, Color(0, 1, 0.14))
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = node as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		for i: int in m.mesh.get_surface_count():
			var src: Material = m.get_active_material(i)
			if not (src is StandardMaterial3D):
				continue
			var mat: StandardMaterial3D = src.duplicate(true)
			mat.stencil_color = c
			if mat.next_pass is StandardMaterial3D:
				var outline: StandardMaterial3D = (mat.next_pass as StandardMaterial3D).duplicate(true)
				outline.albedo_color = c
				mat.next_pass = outline
			m.set_surface_override_material(i, mat)


func _on_destroyable_destroyed() -> void:
	GlobalValues.grant_fuel_from_meteor_destroyed()
	GlobalValues.notify_meteor_rewards(resource_drop, drop_rate)


func _randomize_drift_wait_time() -> void:
	drift_timer.wait_time = randf_range(DRIFT_INTERVAL_MIN, DRIFT_INTERVAL_MAX)


func _on_drift_timer_timeout() -> void:
	var dir: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if dir.length_squared() < 0.0001:
		dir = Vector3(1, 0, 0)
	dir = dir.normalized()
	apply_central_impulse(dir * randf_range(DRIFT_IMPULSE_MIN, DRIFT_IMPULSE_MAX))
	_randomize_drift_wait_time()
