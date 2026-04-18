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
	var vertical: float = 0.0
	if Input.is_action_pressed("FlyUp") or Input.is_physical_key_pressed(KEY_SPACE):
		vertical += 1.0
	if Input.is_action_pressed("FlyDown") or Input.is_physical_key_pressed(KEY_CTRL):
		vertical -= 1.0
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	var right: Vector3 = global_transform.basis.x
	right.y = 0.0
	if right.length_squared() > 0.0001:
		right = right.normalized()
	var wish: Vector3 = forward * (-input_dir.y) + right * input_dir.x + Vector3.UP * vertical
	if wish.length_squared() < 0.0001:
		velocity = velocity.lerp(Vector3.ZERO, ACCEL * delta)
		return
	wish = wish.normalized()
	velocity = velocity.lerp(wish * SPEED, ACCEL * delta)
#endregion

#region Shooting
func shoot() -> void:
	var meteor: Meteor = find_best_meteor_target()
	if meteor == null:
		return
	var projectile: Proyectile = PROJECTILE.instantiate() as Proyectile
	projectile.target = meteor
	projectile.global_position = (turret_pos if next_turret_left else turret_pos_2).global_position
	next_turret_left = not next_turret_left
	get_tree().current_scene.add_child(projectile)

func find_best_meteor_target() -> Meteor:
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 30.0
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 2
	var forward: Vector3 = -camera_3d.global_transform.basis.z
	var origin: Vector3 = global_position
	var best: Meteor = null
	var best_dot: float = -1.0
	for hit in get_world_3d().direct_space_state.intersect_shape(query):
		var m: Meteor = hit.collider as Meteor
		if m == null:
			continue
		var dot: float = forward.dot((m.global_position - origin).normalized())
		if dot > 0.6 and dot > best_dot:
			best_dot = dot
			best = m
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
