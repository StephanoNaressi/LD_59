extends CharacterBody3D
class_name Player

#region constants
const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENS = 0.002
#endregion

var is_locked : bool = false
@onready var camera_3d: Camera3D = $Camera3D

func _ready():
	GlobalValues.player = self
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	handle_camera(event)
	handle_mouse_capture(event)
	
func _physics_process(delta: float) -> void:
	handle_movement(delta)

#region Movement
func handle_movement(delta: float) -> void:
	if is_locked: return
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
#endregion

#region Input
func handle_camera(event: InputEvent) -> void:
	if is_locked: return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera_3d.rotate_x(-event.relative.y * MOUSE_SENS)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(80))
func handle_mouse_capture(event: InputEvent) -> void:
	if Input.is_action_just_pressed("Escape"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if Input.is_action_just_pressed("MouseLeft"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#endregion
