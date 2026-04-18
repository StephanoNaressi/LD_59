extends CharacterBody3D
class_name Player

#region constants
const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENS = 0.002
#endregion

var is_locked: bool = false
var vehicle: SpaceShip = null
@onready var camera_3d: Camera3D = $Camera3D

func _ready() -> void:
	GlobalValues.player = self
	process_priority = 0
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.25
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	handle_camera(event)
	handle_mouse_capture(event)


func _unhandled_input(event: InputEvent) -> void:
	if not Input.is_action_just_pressed("Ping"):
		return
	var ship: SpaceShip = get_tree().get_first_node_in_group("rideable_ship") as SpaceShip
	if ship == null or ship.radio == null:
		return
	var origin: Vector3 = global_position
	if vehicle != null:
		origin = vehicle.global_position
	ship.radio.play_ping(origin)

func _physics_process(delta: float) -> void:
	if vehicle != null:
		sync_pilot_to_seat()
		return
	handle_movement(delta)

func is_piloting(ship: Node) -> bool:
	return vehicle != null and vehicle == ship

func begin_pilot(ship: SpaceShip) -> void:
	vehicle = ship
	is_locked = true
	set_collision_shapes_enabled(false)
	camera_3d.current = false
	ship.activate_pilot_camera()
	ship.set_piloting(true)

func end_pilot() -> void:
	if vehicle == null:
		return
	var ship: SpaceShip = vehicle
	vehicle = null
	global_position = ship.get_exit_world_position()
	velocity = Vector3.ZERO
	set_collision_shapes_enabled(true)
	camera_3d.current = true
	ship.deactivate_pilot_camera()
	ship.set_piloting(false)
	is_locked = false

func set_collision_shapes_enabled(enabled: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = not enabled

func sync_pilot_to_seat() -> void:
	if vehicle == null:
		return
	velocity = Vector3.ZERO
	global_transform = vehicle.get_seat_world_transform()

#region Movement
func handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir: Vector2 = Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction: Vector3 = global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
#endregion

#region Input
func handle_camera(event: InputEvent) -> void:
	if is_locked:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera_3d.rotate_x(-event.relative.y * MOUSE_SENS)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, -deg_to_rad(89.0), deg_to_rad(89.0))

func handle_mouse_capture(event: InputEvent) -> void:
	if Input.is_action_just_pressed("Escape"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if Input.is_action_just_pressed("MouseLeft"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#endregion
