extends CharacterBody3D
class_name SpaceShip

const VELOCITY_RESPONSE: float = 3.25
const MIN_CRUISE: float = 5.0
const MAX_CRUISE: float = 80.0
const CRUISE_STEP: float = 2.0
const MOUSE_YAW_SENS: float = 0.002
const YAW_SMOOTHING: float = 10.5

const SEAT_OFFSET_LOCAL: Vector3 = Vector3(0, 1.2, -2.0)
const EXIT_PROBE_OFFSET: Vector3 = Vector3(0.0, 0.35, 0.65)
const EXIT_SPAWN_ABOVE_FLOOR: float = 1.12

var is_active: bool = false
var is_player_in_area: bool = false

@onready var camera_3d: Camera3D = $spaceship/Chair/Camera3D
@onready var seat_anchor: Node3D = $spaceship/Chair
@onready var exit_anchor: Node3D = $"spaceship/Exit" as Node3D
@onready var radio: Radio = $Radio
@onready var weapons: ShipWeaponSystem = $WeaponSystem

var cruise_speed: float = 20.0
var flight: ShipFlightModel = ShipFlightModel.new()

var mouse_yaw_delta: float = 0.0


func _ready() -> void:
	process_priority = -10
	camera_3d.current = false
	add_to_group("rideable_ship")


func _process(delta: float) -> void:
	handle_input()
	if radio != null:
		radio.tick(radio_listener_position())


func radio_listener_position() -> Vector3:
	if GlobalValues.player != null and GlobalValues.player.vehicle != self:
		return GlobalValues.player.global_position
	return global_position


func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseMotion:
		mouse_yaw_delta += event.relative.x
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cruise_speed = minf(cruise_speed + CRUISE_STEP, MAX_CRUISE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cruise_speed = maxf(cruise_speed - CRUISE_STEP, MIN_CRUISE)


func _physics_process(delta: float) -> void:
	if is_active:
		var yaw_accum: float = mouse_yaw_delta
		mouse_yaw_delta = 0.0
		flight.apply_arcade_thrust(self, delta, cruise_speed, VELOCITY_RESPONSE, yaw_accum, MOUSE_YAW_SENS, YAW_SMOOTHING)
		move_and_slide()
	AnimatableBodySync.push_transforms_to_physics(self)


func handle_input() -> void:
	if Input.is_action_just_pressed("Interact"):
		var pilot: Player = GlobalValues.player
		if pilot == null:
			return
		if pilot.is_piloting(self):
			pilot.end_pilot()
		elif is_player_in_area:
			pilot.begin_pilot(self)
	if is_active:
		weapons.handle_combat_frame()


func set_piloting(piloting: bool) -> void:
	is_active = piloting
	if piloting:
		mouse_yaw_delta = 0.0
		flight.reset_smoothing()
	weapons.on_piloting_changed(piloting)


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
	var ship_basis: Basis = global_transform.basis
	var origin: Vector3 = exit_anchor.global_position if exit_anchor else global_position
	var probe: Vector3 = origin + ship_basis * EXIT_PROBE_OFFSET
	var ray_from: Vector3 = probe + ship_basis.y * 4.0
	var ray_to: Vector3 = probe - ship_basis.y * 15.0
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	ray.collision_mask = 1
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.has("position"):
		return hit.position + ship_basis.y * EXIT_SPAWN_ABOVE_FLOOR
	return probe + ship_basis.y * (EXIT_SPAWN_ABOVE_FLOOR + 0.35)


func on_chair_area_body_entered(body: Node3D) -> void:
	if body is Player:
		is_player_in_area = true


func on_chair_area_body_exited(body: Node3D) -> void:
	if body is Player:
		is_player_in_area = false
