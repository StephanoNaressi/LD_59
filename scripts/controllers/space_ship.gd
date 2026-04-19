extends CharacterBody3D
class_name SpaceShip

const VELOCITY_RESPONSE: float = 3.25
const MIN_CRUISE: float = 5.0
const MAX_CRUISE: float = 80.0
const CRUISE_STEP: float = 2.0
const TANK_CAPACITY: float = 100.0
const FUEL_DRAIN_PER_SEC: float = 0.005
const MIN_FUEL_TO_INCREASE_SPEED: float = 0.02
const NO_FUEL_THRUST_CAP: float = 3.0
const LIFE_SUPPORT_O2_DRAIN_PER_SEC: float = 5
const LIFE_SUPPORT_H2O_DRAIN_PER_SEC: float = 0.4
const MOUSE_YAW_SENS: float = 0.002
const YAW_SMOOTHING: float = 10.5

const SEAT_OFFSET_LOCAL: Vector3 = Vector3(0, 1.2, -1.0)
const EXIT_SPEED_MAX: float = 2.0

const PILOT_CAMERA_FOV_MIN: float = 62.0
const PILOT_CAMERA_FOV_MAX: float = 88.0
const PILOT_CAMERA_FOV_SPEED_REF: float = 75.0

var is_active: bool = false
var is_player_in_area: bool = false

@onready var camera_3d: Camera3D = $spaceship/Chair/Camera3D
@onready var seat_anchor: Node3D = $spaceship/Chair
@onready var exit_anchor: Node3D = $"spaceship/Exit" as Node3D
@onready var radio: Radio = $Radio
@onready var weapons: ShipWeaponSystem = $WeaponSystem

var cruise_speed: float = 20.0
var oxygen_tank_fill: float = 0.0
var water_tank_fill: float = 0.0
var fuel: float = 1.0
var flight: ShipFlightModel = ShipFlightModel.new()

var mouse_yaw_delta: float = 0.0

var pilot_camera_fov_default: float = 75.0


func _ready() -> void:
	process_priority = -10
	camera_3d.current = false
	pilot_camera_fov_default = camera_3d.fov
	add_to_group("rideable_ship")
	oxygen_tank_fill = TANK_CAPACITY * 0.5
	water_tank_fill = TANK_CAPACITY * 0.5


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
			if fuel > MIN_FUEL_TO_INCREASE_SPEED:
				cruise_speed = minf(cruise_speed + CRUISE_STEP, MAX_CRUISE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cruise_speed = maxf(cruise_speed - CRUISE_STEP, MIN_CRUISE)


func _physics_process(delta: float) -> void:
	if is_active:
		if flight.is_thrusting(self) and cruise_speed > MIN_CRUISE:
			var cruise_speed_ratio: float = (cruise_speed - MIN_CRUISE) / maxf(
				0.001, MAX_CRUISE - MIN_CRUISE
			)
			fuel = maxf(0.0, fuel - FUEL_DRAIN_PER_SEC * cruise_speed_ratio * delta)
		if fuel <= MIN_FUEL_TO_INCREASE_SPEED:
			cruise_speed = MIN_CRUISE
		oxygen_tank_fill = maxf(0.0, oxygen_tank_fill - LIFE_SUPPORT_O2_DRAIN_PER_SEC * delta)
		water_tank_fill = maxf(0.0, water_tank_fill - LIFE_SUPPORT_H2O_DRAIN_PER_SEC * delta)
		if oxygen_tank_fill <= 0.001 or water_tank_fill <= 0.001:
			GlobalValues.trigger_game_over("Life support failed — O₂ or H₂O depleted.")
			return
		var yaw_accum: float = mouse_yaw_delta
		mouse_yaw_delta = 0.0
		var thrust_cruise: float = get_effective_thrust_cruise_speed()
		flight.apply_arcade_thrust(self, delta, thrust_cruise, VELOCITY_RESPONSE, yaw_accum, MOUSE_YAW_SENS, YAW_SMOOTHING)
		move_and_slide()
		_update_pilot_camera_fov()
	AnimatableBodySync.push_transforms_to_physics(self)


func get_effective_thrust_cruise_speed() -> float:
	if fuel > MIN_FUEL_TO_INCREASE_SPEED:
		return cruise_speed
	return minf(cruise_speed, NO_FUEL_THRUST_CAP)


func add_fuel_amount(amount: float) -> void:
	fuel = clampf(fuel + amount, 0.0, 1.0)


func handle_input() -> void:
	if Input.is_action_just_pressed("Interact"):
		var pilot: Player = GlobalValues.player
		if pilot == null:
			return
		if pilot.is_piloting(self):
			if velocity.length() <= EXIT_SPEED_MAX:
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
	camera_3d.fov = pilot_camera_fov_default
	camera_3d.current = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func get_seat_world_transform() -> Transform3D:
	var anchor_transform: Transform3D = seat_anchor.global_transform
	var basis: Basis = anchor_transform.basis.orthonormalized()
	return Transform3D(basis, anchor_transform * SEAT_OFFSET_LOCAL)


func get_exit_spawn_global() -> Vector3:
	if exit_anchor != null:
		return exit_anchor.global_position + Vector3.UP * 0.12
	return global_position + global_transform.basis.x * 3.0 + Vector3.UP * 1.0


func on_chair_area_body_entered(body: Node3D) -> void:
	if body is Player:
		is_player_in_area = true


func on_chair_area_body_exited(body: Node3D) -> void:
	if body is Player:
		is_player_in_area = false


func add_oxygen_to_tank(amount: float) -> void:
	oxygen_tank_fill = minf(TANK_CAPACITY, oxygen_tank_fill + amount)


func add_water_to_tank(amount: float) -> void:
	water_tank_fill = minf(TANK_CAPACITY, water_tank_fill + amount)


func _update_pilot_camera_fov() -> void:
	var speed: float = velocity.length()
	var speed_ratio: float = clampf(speed / PILOT_CAMERA_FOV_SPEED_REF, 0.0, 1.0)
	camera_3d.fov = lerpf(PILOT_CAMERA_FOV_MIN, PILOT_CAMERA_FOV_MAX, speed_ratio)
