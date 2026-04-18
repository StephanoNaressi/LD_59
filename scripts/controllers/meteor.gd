extends Destroyable
class_name Meteor

const DRIFT_INTERVAL_MIN: float = 2.0
const DRIFT_INTERVAL_MAX: float = 5.5
const DRIFT_IMPULSE_MIN: float = 0.12
const DRIFT_IMPULSE_MAX: float = 0.55

@onready var drift_timer: Timer = $DriftTimer

func _ready() -> void:
	super._ready()
	drift_timer.timeout.connect(_on_drift_timer_timeout)
	_randomize_drift_wait_time()
	drift_timer.start()

func _randomize_drift_wait_time() -> void:
	drift_timer.wait_time = randf_range(DRIFT_INTERVAL_MIN, DRIFT_INTERVAL_MAX)

func _on_drift_timer_timeout() -> void:
	var dir: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if dir.length_squared() < 0.0001:
		dir = Vector3(1, 0, 0)
	dir = dir.normalized()
	apply_central_impulse(dir * randf_range(DRIFT_IMPULSE_MIN, DRIFT_IMPULSE_MAX))
	_randomize_drift_wait_time()
