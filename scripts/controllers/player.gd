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
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	handle_camera(event)
	handle_mouse_capture(event)

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
	set_collision_shapes_enabled(true)
	global_position = ship.get_exit_world_position()
	velocity = Vector3.ZERO
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
	var riding: CharacterBody3D = get_riding_ship()
	if riding:
		global_position += riding.velocity * delta

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir: Vector2 = Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func get_riding_ship() -> CharacterBody3D:
	if not is_on_floor():
		return null
	var slide_count: int = get_slide_collision_count()
	for slide_index in range(slide_count):
		var slide_hit: KinematicCollision3D = get_slide_collision(slide_index)
		if slide_hit == null:
			continue
		var collider: CollisionObject3D = slide_hit.get_collider() as CollisionObject3D
		if collider == null:
			continue
		var ancestor: Node = collider
		while ancestor:
			if ancestor.is_in_group("rideable_ship"):
				return ancestor as CharacterBody3D
			ancestor = ancestor.get_parent()
	return null
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
