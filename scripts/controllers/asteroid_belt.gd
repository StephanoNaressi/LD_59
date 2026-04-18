extends Node3D
class_name AsteroidBelt

const METEOR_SCENE: PackedScene = preload("res://scenes/meteor.tscn")

const LABEL_TINT: Dictionary = {
	Item.Item_Type.ROCK: Color(0.92, 0.78, 0.55),
	Item.Item_Type.METAL: Color(0.88, 0.94, 1.0),
	Item.Item_Type.OXYGEN: Color(0.45, 0.96, 1.0),
	Item.Item_Type.WATER: Color(0.42, 0.62, 1.0),
}

@export var belt_resource: Item.Item_Type = Item.Item_Type.ROCK
@export var asteroids_to_spawn: int = 44
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
	_add_resource_labels()
	call_deferred("_initial_spawn")


func _add_resource_labels() -> void:
	var lb: Label3D = Label3D.new()
	lb.text = Item.type_name(belt_resource)
	lb.font_size = 128
	lb.pixel_size = 0.065
	lb.modulate = LABEL_TINT.get(belt_resource, Color(0.9, 0.9, 0.95))
	lb.outline_size = 14
	lb.outline_modulate = Color(0, 0, 0, 0.88)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.shaded = false
	lb.position = Vector3(0, vertical_spread + outer_radius * 0.35, 0)
	add_child(lb)


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
	meteor.resource_drop = belt_resource
	meteor.drop_rate = 3
	add_child(meteor)
	meteor.global_position = pos
	meteor.destroyed.connect(_on_meteor_destroyed, CONNECT_ONE_SHOT)


func _on_meteor_destroyed() -> void:
	var delay: float = respawn_delay_seconds + _rng.randf_range(-respawn_delay_jitter, respawn_delay_jitter)
	delay = maxf(delay, 5.0)
	get_tree().create_timer(delay).timeout.connect(_spawn_meteor_at_safe_position)
