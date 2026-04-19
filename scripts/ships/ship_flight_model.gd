extends RefCounted
class_name ShipFlightModel


var smoothed_yaw: float = 0.0


func reset_smoothing() -> void:
	smoothed_yaw = 0.0


func get_move_input_vector(ship: CharacterBody3D) -> Vector3:
	var vertical: float = 0.0
	if Input.is_action_pressed("FlyUp") or Input.is_physical_key_pressed(KEY_SPACE):
		vertical += 1.0
	if Input.is_action_pressed("FlyDown") or Input.is_physical_key_pressed(KEY_CTRL):
		vertical -= 1.0
	var forward: Vector3 = -ship.global_transform.basis.z
	var right: Vector3 = ship.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	if right.length_squared() > 0.0001:
		right = right.normalized()
	var input_dir: Vector2 = Input.get_vector("Left", "Right", "Forward", "Backward")
	return forward * (-input_dir.y) + right * input_dir.x + Vector3.UP * vertical


func is_accelerating(ship: CharacterBody3D) -> bool:
	return get_move_input_vector(ship).length_squared() > 0.0001


func apply_flight_controls(
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

	var wish: Vector3 = get_move_input_vector(ship)
	var blend: float = clampf(velocity_response * delta, 0.0, 1.0)
	if wish.length_squared() < 0.0001:
		ship.velocity = ship.velocity.lerp(Vector3.ZERO, blend)
		return
	wish = wish.normalized()
	ship.velocity = ship.velocity.lerp(wish * cruise_speed, blend)
