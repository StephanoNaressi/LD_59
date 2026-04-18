extends CharacterBody3D
class_name SpaceShip

#region constants
const PROJECTILE = preload("uid://b65juspb4p45s")

const SPEED = 20.0
const ACCEL = 6.0
const YAW_SPEED: float = 2.2
const MOUSE_YAW_SENS: float = 0.0035
const MOUSE_PITCH_SENS: float = 0.0025
const ROLL_SPEED = 2.5
const ROLL_RETURN_SPEED: float = 1.2

const SEAT_OFFSET_LOCAL: Vector3 = Vector3(0, 1.2, -2.0)
#endregion

#region variables
var is_active: bool = false
var is_player_in_area: bool = false

var roll: float = 0.0
@onready var turret_pos: Node3D = $TurretPos
@onready var turret_pos_2: Node3D = $TurretPos2

var next_turret_left: bool = true

@onready var camera_3d: Camera3D = $spaceship/Chair/Camera3D
@onready var seat_anchor: Node3D = $spaceship/Chair
@onready var exit_anchor: Node3D = $"spaceship/Exit" as Node3D
#endregion

func _ready() -> void:
	process_priority = -10
	camera_3d.current = false
	add_to_group("rideable_ship")

func _process(delta: float) -> void:
	handle_input()

func _physics_process(delta: float) -> void:
	if is_active:
		handle_movement(delta)
		move_and_slide()
		apply_flight_leveling(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseMotion:
		camera_3d.rotation.y -= event.relative.x * MOUSE_YAW_SENS
		camera_3d.rotation.x -= event.relative.y * MOUSE_PITCH_SENS
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, -deg_to_rad(89.0), deg_to_rad(89.0))
		get_viewport().set_input_as_handled()

func apply_flight_leveling(delta: float) -> void:
	if Input.is_action_pressed("RollLeft"):
		roll += ROLL_SPEED * delta
	elif Input.is_action_pressed("RollRight"):
		roll -= ROLL_SPEED * delta
	else:
		roll = move_toward(roll, 0.0, ROLL_RETURN_SPEED * delta)
	rotation.z = roll

func handle_input() -> void:
	if Input.is_action_just_pressed("Interact"):
		var pilot: Player = GlobalValues.player
		if pilot == null:
			return
		if pilot.is_piloting(self):
			pilot.end_pilot()
		elif is_player_in_area:
			pilot.begin_pilot(self)

	if is_active and Input.is_action_just_pressed("MouseLeft"):
		shoot()

func set_piloting(piloting: bool) -> void:
	is_active = piloting

func activate_pilot_camera() -> void:
	camera_3d.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func deactivate_pilot_camera() -> void:
	camera_3d.current = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func get_seat_world_transform() -> Transform3D:
	var anchor_transform: Transform3D = seat_anchor.global_transform
	return Transform3D(anchor_transform.basis, anchor_transform * SEAT_OFFSET_LOCAL)

func get_exit_world_position() -> Vector3:
	if exit_anchor:
		return exit_anchor.global_position + exit_anchor.global_transform.basis * Vector3(0, 0.5, 0.5)
	return global_position + global_transform.basis * Vector3(0, 2.0, 4.0)

#region Movement
func handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("Left", "Right", "Forward", "Backward")
	rotate_y(-input_dir.x * YAW_SPEED * delta)
	var vertical: float = 0.0
	if Input.is_action_pressed("FlyUp") or Input.is_physical_key_pressed(KEY_SPACE):
		vertical += 1.0
	if Input.is_action_pressed("FlyDown") or Input.is_physical_key_pressed(KEY_CTRL):
		vertical -= 1.0
	var cam_basis: Basis = camera_3d.global_transform.basis
	var local_move: Vector3 = Vector3(0.0, vertical, input_dir.y)
	if local_move.length_squared() < 0.0001:
		velocity = velocity.lerp(Vector3.ZERO, ACCEL * delta)
		return
	var direction: Vector3 = cam_basis * local_move.normalized()
	velocity = velocity.lerp(direction * SPEED, ACCEL * delta)
#endregion

#region Shooting
func shoot() -> void:
	var target = get_best_target()
	if target == null:
		return

	var projectile = PROJECTILE.instantiate()
	get_tree().current_scene.add_child(projectile)

	var spawn_from: Node3D = turret_pos if next_turret_left else turret_pos_2
	next_turret_left = not next_turret_left
	projectile.global_position = spawn_from.global_position
	projectile.target = target

func get_best_target() -> Node3D:
	var space_state = get_world_3d().direct_space_state

	var origin = global_position
	var forward = -camera_3d.global_transform.basis.z

	var shape = SphereShape3D.new()
	shape.radius = 30.0

	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), origin)
	query.collision_mask = 2

	var results = space_state.intersect_shape(query)

	var best_target = null
	var best_forward_dot: float = -1.0

	for intersection in results:
		var collider: Object = intersection.collider
		if collider == null:
			continue

		var to_target: Vector3 = (collider.global_position - origin).normalized()
		var forward_dot: float = forward.dot(to_target)

		if forward_dot > 0.6 and forward_dot > best_forward_dot:
			best_forward_dot = forward_dot
			best_target = collider

	return best_target
#endregion

#region Area Detection
func on_chair_area_body_entered(body: Node3D) -> void:
	if body is Player:
		is_player_in_area = true

func on_chair_area_body_exited(body: Node3D) -> void:
	if body is Player:
		is_player_in_area = false
#endregion
