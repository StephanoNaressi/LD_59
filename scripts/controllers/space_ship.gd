extends CharacterBody3D
class_name SpaceShip

#region constants
const METEOR_PROJECTILE_SCENE: PackedScene = preload("uid://b65juspb4p45s")
const REPAIR_PROJECTILE_SCENE: PackedScene = preload("res://scenes/repair_proyectile.tscn")

const SPEED = 20.0
const ACCEL = 6.0

const SEAT_OFFSET_LOCAL: Vector3 = Vector3(0, 1.2, -2.0)
const EXIT_PROBE_OFFSET: Vector3 = Vector3(0.0, 0.35, 0.65)
const EXIT_SPAWN_ABOVE_FLOOR: float = 1.12
#endregion

#region variables
var is_active: bool = false
var is_player_in_area: bool = false
var is_shooting: bool = false
var can_shoot: bool = true
@onready var turret_pos: Node3D = $TurretPos
@onready var turret_pos_2: Node3D = $TurretPos2

var next_turret_left: bool = true

@onready var camera_3d: Camera3D = $spaceship/Chair/Camera3D
@onready var seat_anchor: Node3D = $spaceship/Chair
@onready var exit_anchor: Node3D = $"spaceship/Exit" as Node3D
@onready var engagement_area: Area3D = $EngagementRange
@onready var shooting_cooldown: Timer = $ShootingCooldown
@onready var repair_shooting_cooldown: Timer = $RepairShootingCooldown

var can_fire_repair: bool = true

var _mouse_yaw_delta: float = 0.0
var _smoothed_yaw_delta: float = 0.0
var _reticle_meteor: Meteor = null
var _reticle_antenna: Antenna = null
#endregion

func _ready() -> void:
	process_priority = -10
	camera_3d.current = false
	add_to_group("rideable_ship")

func _process(delta: float) -> void:
	handle_input()

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseMotion:
		_mouse_yaw_delta += event.relative.x

func _physics_process(delta: float) -> void:
	if is_active:
		handle_movement(delta)
		move_and_slide()
	_sync_interior_animatable_bodies_to_physics()

## collision bodies with the parent unless their transform is pushed to the physics server
func _sync_interior_animatable_bodies_to_physics() -> void:
	for n in find_children("*", "AnimatableBody3D", true, false):
		var ab: AnimatableBody3D = n as AnimatableBody3D
		var rid: RID = ab.get_rid()
		if not rid.is_valid():
			continue
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, ab.global_transform)

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
		refresh_weapon_reticles()
		update_meteor_primary_hold()
		tick_repair_hold_fire()
		tick_meteor_primary_auto_fire()
	
func set_piloting(piloting: bool) -> void:
	is_active = piloting
	if piloting:
		_mouse_yaw_delta = 0.0
		_smoothed_yaw_delta = 0.0
	else:
		is_shooting = false
		shooting_cooldown.stop()
		repair_shooting_cooldown.stop()
		can_shoot = true
		can_fire_repair = true
		clear_weapon_reticles()

func clear_weapon_reticles() -> void:
	if _reticle_meteor != null and is_instance_valid(_reticle_meteor):
		_reticle_meteor.untarget_destroyable()
	_reticle_meteor = null
	if _reticle_antenna != null and is_instance_valid(_reticle_antenna):
		_reticle_antenna.untarget_destroyable()
	_reticle_antenna = null


func refresh_weapon_reticles() -> void:
	var new_meteor: Meteor = pick_meteor_in_crosshair()
	if new_meteor != _reticle_meteor:
		if _reticle_meteor != null and is_instance_valid(_reticle_meteor):
			_reticle_meteor.untarget_destroyable()
		_reticle_meteor = new_meteor
		if _reticle_meteor != null:
			_reticle_meteor.target_destroyable()

	var new_antenna: Antenna = pick_antenna_in_crosshair()
	if new_antenna != _reticle_antenna:
		if _reticle_antenna != null and is_instance_valid(_reticle_antenna):
			_reticle_antenna.untarget_destroyable()
		_reticle_antenna = new_antenna
		if _reticle_antenna != null:
			_reticle_antenna.target_destroyable()

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

#region Movement
func handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("Left", "Right", "Forward", "Backward")
	var raw_yaw: float = -_mouse_yaw_delta * 0.002
	_mouse_yaw_delta = 0.0
	_smoothed_yaw_delta = lerpf(_smoothed_yaw_delta, raw_yaw, clampf(14.0 * delta, 0.0, 1.0))
	rotate_y(_smoothed_yaw_delta)

	var vertical: float = 0.0
	if Input.is_action_pressed("FlyUp") or Input.is_physical_key_pressed(KEY_SPACE):
		vertical += 1.0
	if Input.is_action_pressed("FlyDown") or Input.is_physical_key_pressed(KEY_CTRL):
		vertical -= 1.0
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	var wish: Vector3 = forward * (-input_dir.y) + Vector3.UP * vertical
	if wish.length_squared() < 0.0001:
		velocity = velocity.lerp(Vector3.ZERO, ACCEL * delta)
		return
	wish = wish.normalized()
	velocity = velocity.lerp(wish * SPEED, ACCEL * delta)
#endregion

#region Ship weapons
func update_meteor_primary_hold() -> void:
	if Input.is_action_just_pressed("MouseLeft"):
		is_shooting = true
	if Input.is_action_just_released("MouseLeft"):
		is_shooting = false


func tick_repair_hold_fire() -> void:
	if not Input.is_action_pressed("MouseRight"):
		return
	try_fire_repair_bolt()


func try_fire_repair_bolt() -> void:
	if not can_fire_repair:
		return
	if _reticle_antenna == null:
		return
	var muzzle: Node3D = turret_pos if next_turret_left else turret_pos_2
	next_turret_left = not next_turret_left
	var bolt: RepairProyectile = REPAIR_PROJECTILE_SCENE.instantiate() as RepairProyectile
	bolt.configure_homing(_reticle_antenna, muzzle)
	ShipWeaponSpawn.add_to_current_scene(self, bolt)
	can_fire_repair = false
	repair_shooting_cooldown.start()


func tick_meteor_primary_auto_fire() -> void:
	if not is_shooting:
		return
	try_spawn_meteor_projectile()


func try_spawn_meteor_projectile() -> void:
	if not can_shoot:
		return
	if _reticle_meteor == null:
		return
	var muzzle: Node3D = turret_pos if next_turret_left else turret_pos_2
	next_turret_left = not next_turret_left
	var projectile: Proyectile = METEOR_PROJECTILE_SCENE.instantiate() as Proyectile
	projectile.configure_homing(_reticle_meteor, muzzle)
	ShipWeaponSpawn.add_to_current_scene(self, projectile)

	can_shoot = false
	shooting_cooldown.start()


func pick_meteor_in_crosshair() -> Meteor:
	var body: Node = ShipWeaponSpawn.pick_body_in_engagement(
		camera_3d,
		engagement_area,
		func(b: Node) -> bool: return b is Meteor
	)
	return body as Meteor


func pick_antenna_in_crosshair() -> Antenna:
	var body: Node = ShipWeaponSpawn.pick_body_in_engagement(
		camera_3d,
		engagement_area,
		func(b: Node) -> bool: return antenna_is_repair_target(b)
	)
	return body as Antenna


func antenna_is_repair_target(body: Node) -> bool:
	if not (body is Antenna):
		return false
	var antenna: Antenna = body as Antenna
	if antenna.is_repaired:
		return false
	if antenna.repair_progress > 0.001:
		return true
	return GlobalValues.can_afford_items(antenna.metal_cost, antenna.rock_cost)

#endregion

#region Area Detection
func on_chair_area_body_entered(body: Node3D) -> void:
	if body is Player:
		is_player_in_area = true

func on_chair_area_body_exited(body: Node3D) -> void:
	if body is Player:
		is_player_in_area = false
#endregion


func _on_shooting_cooldown_timeout() -> void:
	can_shoot = true


func repair_cooldown_finished() -> void:
	can_fire_repair = true
