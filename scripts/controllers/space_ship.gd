extends CharacterBody3D
class_name SpaceShip

#region constants
const PROJECTILE = preload("uid://b65juspb4p45s")

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

var _mouse_yaw_delta: float = 0.0
var _smoothed_yaw_delta: float = 0.0
var _reticle_meteor: Meteor = null
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
	
	if is_active and Input.is_action_just_pressed("MouseLeft"):
		is_shooting = true
	if is_active and Input.is_action_just_released("MouseLeft"):
		is_shooting = false
	if is_active:
		shoot()
	
func set_piloting(piloting: bool) -> void:
	is_active = piloting
	if piloting:
		_mouse_yaw_delta = 0.0
		_smoothed_yaw_delta = 0.0
	else:
		is_shooting = false
		shooting_cooldown.stop()
		can_shoot = true
		_clear_target_reticle()

func _clear_target_reticle() -> void:
	if _reticle_meteor != null and is_instance_valid(_reticle_meteor):
		_reticle_meteor.untarget_destroyable()
	_reticle_meteor = null

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

#region Shooting
func shoot() -> void:
	if not is_shooting or not can_shoot:
		return

	if _reticle_meteor != null and not is_instance_valid(_reticle_meteor):
		_reticle_meteor = null
	var meteor: Meteor = _closest_meteor_in_front()
	if meteor == null:
		return
	if _reticle_meteor != meteor:
		if _reticle_meteor != null and is_instance_valid(_reticle_meteor):
			_reticle_meteor.untarget_destroyable()
		_reticle_meteor = meteor
		meteor.target_destroyable()
	var muzzle: Node3D = turret_pos if next_turret_left else turret_pos_2
	next_turret_left = not next_turret_left
	var projectile: Proyectile = PROJECTILE.instantiate() as Proyectile
	projectile.target = meteor
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = muzzle.global_position

	can_shoot = false
	shooting_cooldown.start()

func _closest_meteor_in_front() -> Meteor:
	var origin: Vector3 = camera_3d.global_position
	var forward: Vector3 = -camera_3d.global_transform.basis.z
	var viewport_center: Vector2 = camera_3d.get_viewport().get_visible_rect().size * 0.5
	var best: Meteor = null
	var best_screen_d2: float = INF
	var best_world_d2: float = INF
	for body in engagement_area.get_overlapping_bodies():
		if body is Meteor:
			var m: Meteor = body as Meteor
			var to_m: Vector3 = m.global_position - origin
			if forward.dot(to_m) <= 0.0:
				continue
			var world_d2: float = to_m.length_squared()
			var screen_d2: float = (camera_3d.unproject_position(m.global_position) - viewport_center).length_squared()
			if best == null or screen_d2 < best_screen_d2 or (is_equal_approx(screen_d2, best_screen_d2) and world_d2 < best_world_d2):
				best = m
				best_screen_d2 = screen_d2
				best_world_d2 = world_d2
	return best
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
