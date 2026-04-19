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
@export var asteroids_to_spawn: int = 18
@export var inner_radius: float = 70.0
@export var outer_radius: float = 150.0
@export var vertical_spread: float = 30.0
@export var min_distance_from_player: float = 50.0
@export var max_spawn_attempts: int = 48
@export var respawn_delay_seconds: float = 120.0
@export var respawn_delay_jitter: float = 35.0

var random_generator: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"asteroid_belts")
	random_generator.randomize()
	add_resource_labels()
	call_deferred("initial_spawn")


func add_resource_labels() -> void:
	var title_label: Label3D = Label3D.new()
	title_label.text = Item.type_name(belt_resource)
	title_label.font_size = 128
	title_label.pixel_size = 0.065
	title_label.modulate = LABEL_TINT.get(belt_resource, Color(0.9, 0.9, 0.95))
	title_label.outline_size = 14
	title_label.outline_modulate = Color(0, 0, 0, 0.88)
	title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title_label.shaded = false
	title_label.position = Vector3(0, vertical_spread + outer_radius * 0.35, 0)
	add_child(title_label)


func initial_spawn() -> void:
	for spawn_index in asteroids_to_spawn:
		spawn_meteor_at_safe_position()


func random_belt_position() -> Vector3:
	var angle: float = random_generator.randf() * TAU
	var belt_radius: float = random_generator.randf_range(inner_radius, outer_radius)
	var height: float = random_generator.randf_range(-vertical_spread, vertical_spread)
	return global_position + Vector3(cos(angle) * belt_radius, height, sin(angle) * belt_radius)


func spawn_meteor_at_safe_position() -> void:
	var player: Node3D = GlobalValues.player as Node3D
	var candidate_position: Vector3 = Vector3.ZERO
	var found_valid_position: bool = false
	for attempt in max_spawn_attempts:
		candidate_position = random_belt_position()
		if (
			player == null
			or player.global_position.distance_to(candidate_position) >= min_distance_from_player
		):
			found_valid_position = true
			break
	if not found_valid_position:
		candidate_position = random_belt_position()

	var meteor: Meteor = METEOR_SCENE.instantiate() as Meteor
	meteor.resource_drop = belt_resource
	meteor.drop_rate = 3
	add_child(meteor)
	meteor.global_position = candidate_position
	meteor.destroyed.connect(on_meteor_destroyed, CONNECT_ONE_SHOT)


func on_meteor_destroyed() -> void:
	var delay: float = respawn_delay_seconds + random_generator.randf_range(
		-respawn_delay_jitter, respawn_delay_jitter
	)
	delay = maxf(delay, 5.0)
	get_tree().create_timer(delay).timeout.connect(spawn_meteor_at_safe_position)
