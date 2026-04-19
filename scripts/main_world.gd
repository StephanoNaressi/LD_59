extends Node3D

const AMBIENT_SFX: AudioStream = preload("res://game/audios/ambient.ogg")

@export var meteor_sleep_m: float = 340.0
@export var meteor_wake_m: float = 280.0
@export var meteor_cull_period_sec: float = 0.16

var meteor_cull_accumulator_sec: float = 0.0
var ambient_player: AudioStreamPlayer


func _ready() -> void:
	TowerRegistry.rebuild_from_tree(get_tree())
	ambient_player = AudioStreamPlayer.new()
	add_child(ambient_player)
	var looped_ambient: AudioStreamOggVorbis = AMBIENT_SFX.duplicate() as AudioStreamOggVorbis
	looped_ambient.loop = true
	ambient_player.stream = looped_ambient
	ambient_player.volume_db = AudioLevels.AMBIENT_VOLUME_DB
	ambient_player.play()


func _physics_process(delta: float) -> void:
	meteor_cull_accumulator_sec += delta
	if meteor_cull_accumulator_sec < meteor_cull_period_sec:
		return
	meteor_cull_accumulator_sec = 0.0
	update_meteor_activity()


func get_player_focus_position() -> Vector3:
	var player: Player = GlobalValues.player
	if player == null:
		return Vector3.ZERO
	if player.vehicle != null:
		return player.vehicle.global_position
	return player.global_position


func update_meteor_activity() -> void:
	if GlobalValues.player == null:
		return
	var origin: Vector3 = get_player_focus_position()
	var sleep_distance_squared: float = meteor_sleep_m * meteor_sleep_m
	var wake_distance_m: float = minf(meteor_wake_m, meteor_sleep_m - 1.0)
	var wake_distance_squared: float = wake_distance_m * wake_distance_m
	for candidate in get_tree().get_nodes_in_group(&"meteor_cull"):
		if not (candidate is Meteor):
			continue
		var meteor: Meteor = candidate as Meteor
		if not is_instance_valid(meteor) or meteor.dead:
			continue
		var distance_squared: float = meteor.global_position.distance_squared_to(origin)
		if meteor.simulated:
			if distance_squared > sleep_distance_squared:
				meteor.set_simulated(false)
		else:
			if distance_squared < wake_distance_squared:
				meteor.set_simulated(true)
