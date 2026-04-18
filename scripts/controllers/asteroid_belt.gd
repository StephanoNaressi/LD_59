extends Node3D
class_name AsteroidBelt

const METEOR_SCENE: PackedScene = preload("res://scenes/meteor.tscn")

@export var asteroids_to_spawn: int = 30
@export var inner_radius: float = 70.0
@export var outer_radius: float = 150.0
@export var vertical_spread: float = 30.0
@export var min_distance_from_player: float = 50.0
@export var max_spawn_attempts: int = 48
@export var respawn_delay_seconds: float = 120.0
@export var respawn_delay_jitter: float = 35.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	call_deferred("_initial_spawn")


func _initial_spawn() -> void:
	for i in asteroids_to_spawn:
		_spawn_meteor_at_safe_position()


func _random_belt_position() -> Vector3:
	var angle: float = _rng.randf() * TAU
	var r: float = _rng.randf_range(inner_radius, outer_radius)
	var y: float = _rng.randf_range(-vertical_spread, vertical_spread)
	return global_position + Vector3(cos(angle) * r, y, sin(angle) * r)


func _spawn_meteor_at_safe_position() -> void:
	var player: Node3D = GlobalValues.player as Node3D
	var pos: Vector3 = Vector3.ZERO
	var found: bool = false
	for attempt in max_spawn_attempts:
		pos = _random_belt_position()
		if player == null or player.global_position.distance_to(pos) >= min_distance_from_player:
			found = true
			break
	if not found:
		pos = _random_belt_position()

	var meteor: Meteor = METEOR_SCENE.instantiate() as Meteor
	add_child(meteor)
	meteor.global_position = pos
	if _rng.randf() < 0.5:
		meteor.resource_drop = Item.Item_Type.METAL
	else:
		meteor.resource_drop = Item.Item_Type.ROCK
	meteor.drop_rate = 3
	meteor.destroyed.connect(_on_meteor_destroyed, CONNECT_ONE_SHOT)


func _on_meteor_destroyed() -> void:
	var delay: float = respawn_delay_seconds + _rng.randf_range(-respawn_delay_jitter, respawn_delay_jitter)
	delay = maxf(delay, 5.0)
	get_tree().create_timer(delay).timeout.connect(_spawn_meteor_at_safe_position)
