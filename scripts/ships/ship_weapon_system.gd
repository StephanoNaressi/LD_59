extends Node
class_name ShipWeaponSystem

const METEOR_PROJECTILE_SCENE: PackedScene = preload("uid://b65juspb4p45s")
const REPAIR_PROJECTILE_SCENE: PackedScene = preload("res://scenes/repair_proyectile.tscn")
const PEW_SFX: AudioStream = preload("res://game/audios/pew.ogg")

var ship: SpaceShip
var is_shooting: bool = false
var can_shoot: bool = true
var can_fire_repair: bool = true
var next_turret_left: bool = true

var reticle_meteor: Meteor = null
var reticle_antenna: Antenna = null

@onready var turret_pos: Node3D = $"../TurretPos"
@onready var turret_pos_2: Node3D = $"../TurretPos2"
@onready var camera_3d: Camera3D = $"../spaceship/Chair/Camera3D"
@onready var engagement_area: Area3D = $"../EngagementRange"
@onready var shooting_cooldown: Timer = $ShootingCooldown
@onready var repair_shooting_cooldown: Timer = $RepairShootingCooldown


func _ready() -> void:
	ship = get_parent() as SpaceShip


func on_piloting_changed(piloting: bool) -> void:
	if piloting:
		return
	is_shooting = false
	shooting_cooldown.stop()
	repair_shooting_cooldown.stop()
	can_shoot = true
	can_fire_repair = true
	clear_reticles()


func handle_combat_frame() -> void:
	refresh_reticles()
	update_meteor_hold()
	tick_repair_hold()
	tick_meteor_auto_fire()


func clear_reticles() -> void:
	if reticle_meteor != null and is_instance_valid(reticle_meteor):
		reticle_meteor.untarget_destroyable()
	reticle_meteor = null
	if reticle_antenna != null and is_instance_valid(reticle_antenna):
		reticle_antenna.untarget_destroyable()
	reticle_antenna = null
	GlobalValues.antenna_repair_hud_changed.emit(null)


func refresh_reticles() -> void:
	var new_meteor: Meteor = pick_meteor()
	if new_meteor != reticle_meteor:
		if reticle_meteor != null and is_instance_valid(reticle_meteor):
			reticle_meteor.untarget_destroyable()
		reticle_meteor = new_meteor
		if reticle_meteor != null:
			reticle_meteor.target_destroyable()

	var new_antenna: Antenna = pick_antenna()
	if new_antenna != reticle_antenna:
		if reticle_antenna != null and is_instance_valid(reticle_antenna):
			reticle_antenna.untarget_destroyable()
		reticle_antenna = new_antenna
		if reticle_antenna != null:
			reticle_antenna.target_destroyable()
		GlobalValues.antenna_repair_hud_changed.emit(reticle_antenna)


func update_meteor_hold() -> void:
	if Input.is_action_just_pressed("MouseLeft"):
		is_shooting = true
	if Input.is_action_just_released("MouseLeft"):
		is_shooting = false


func tick_repair_hold() -> void:
	if not Input.is_action_pressed("MouseRight"):
		return
	try_fire_repair()


func try_fire_repair() -> void:
	if not can_fire_repair or reticle_antenna == null:
		return
	if not GlobalValues.has_items_for_cost(
		reticle_antenna.metal_cost,
		reticle_antenna.rock_cost,
		reticle_antenna.oxygen_cost,
		reticle_antenna.water_cost
	):
		return
	var muzzle: Node3D = turret_pos if next_turret_left else turret_pos_2
	next_turret_left = not next_turret_left
	var bolt: RepairProyectile = REPAIR_PROJECTILE_SCENE.instantiate() as RepairProyectile
	if not SceneUtil.add_child_to_current_scene(ship, bolt):
		bolt.queue_free()
		return
	bolt.configure_homing(reticle_antenna, muzzle)
	can_fire_repair = false
	repair_shooting_cooldown.start()


func tick_meteor_auto_fire() -> void:
	if not is_shooting:
		return
	try_spawn_meteor()


func try_spawn_meteor() -> void:
	if not can_shoot or reticle_meteor == null:
		return
	var muzzle: Node3D = turret_pos if next_turret_left else turret_pos_2
	next_turret_left = not next_turret_left
	var projectile: Proyectile = METEOR_PROJECTILE_SCENE.instantiate() as Proyectile
	if not SceneUtil.add_child_to_current_scene(ship, projectile):
		projectile.queue_free()
		return
	projectile.configure_homing(reticle_meteor, muzzle)
	GlobalValues.play_sfx_at(PEW_SFX, muzzle.global_position, -17.0, randf_range(0.98, 1.05), 560.0)
	can_shoot = false
	shooting_cooldown.start()


func pick_meteor() -> Meteor:
	var body: Node = EngagementTargeting.pick_forward_body_in_area(
		camera_3d,
		engagement_area,
		func(body_candidate: Node) -> bool: return body_candidate is Meteor
	)
	return body as Meteor


func pick_antenna() -> Antenna:
	var body: Node = EngagementTargeting.pick_forward_body_in_area(
		camera_3d,
		engagement_area,
		func(body_candidate: Node) -> bool: return antenna_is_repair_target(body_candidate)
	)
	return body as Antenna


func antenna_is_repair_target(body: Node) -> bool:
	if not (body is Antenna):
		return false
	var antenna: Antenna = body as Antenna
	return not antenna.is_repaired


func on_shooting_cooldown_timeout() -> void:
	can_shoot = true


func on_repair_cooldown_timeout() -> void:
	can_fire_repair = true
