extends RefCounted
class_name ShipFlightModel


var smoothed_yaw: float = 0.0


func reset_smoothing() -> void:
	smoothed_yaw = 0.0


func apply_arcade_thrust(
	ship: CharacterBody3D,
	delta: float,
	cruise_speed: float,
	velocity_response: float,
	raw_mouse_yaw_accum: float,
	mouse_sensitivity: float,
	yaw_smoothing: float
) -> void:
	var raw_yaw: float = -raw_mouse_yaw_accum * mouse_sensitivity
	smoothed_yaw = lerpf(smoothed_yaw, raw_yaw, clampf(yaw_smoothing * delta, 0.0, 1.0))
	ship.rotate_y(smoothed_yaw)

	var vertical: float = 0.0
	if Input.is_action_pressed("FlyUp") or Input.is_physical_key_pressed(KEY_SPACE):
		vertical += 1.0
	if Input.is_action_pressed("FlyDown") or Input.is_physical_key_pressed(KEY_CTRL):
		vertical -= 1.0
	var forward: Vector3 = -ship.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	var input_dir: Vector2 = Input.get_vector("Left", "Right", "Forward", "Backward")
	var wish: Vector3 = forward * (-input_dir.y) + Vector3.UP * vertical
	var blend: float = clampf(velocity_response * delta, 0.0, 1.0)
	if wish.length_squared() < 0.0001:
		ship.velocity = ship.velocity.lerp(Vector3.ZERO, blend)
		return
	wish = wish.normalized()
	ship.velocity = ship.velocity.lerp(wish * cruise_speed, blend)
