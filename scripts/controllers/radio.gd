extends Node3D
class_name Radio

const NOISE_AUDIO: AudioStream = preload("res://game/audios/noise.ogg")
const SONAR_AUDIO: AudioStream = preload("res://game/audios/sonar.ogg")

const PING_RANGE: float = 100.0
const NOISE_FADE_START: float = 38.0
const NOISE_FADE_END: float = 6.0
const MUSIC_RANGE: float = 45.0

@export var music_stream: AudioStream

@onready var sonar_player: AudioStreamPlayer3D = $SonarPlayer
@onready var noise_player: AudioStreamPlayer3D = $NoisePlayer
@onready var music_player: AudioStreamPlayer3D = $MusicPlayer


func _ready() -> void:
	var noise_copy: AudioStreamOggVorbis = NOISE_AUDIO.duplicate() as AudioStreamOggVorbis
	noise_copy.loop = true
	noise_player.stream = noise_copy
	noise_player.volume_db = -80.0
	sonar_player.stream = SONAR_AUDIO
	if music_stream != null:
		music_player.stream = music_stream


func play_ping(ship_world_position: Vector3) -> void:
	var tower: Antenna = find_closest_antenna(ship_world_position)
	if tower == null:
		return
	if tower.is_repaired:
		return
	var distance: float = ship_world_position.distance_to(tower.global_position)
	if distance > PING_RANGE:
		return
	var closeness: float = 1.0 - clampf(distance / PING_RANGE, 0.0, 1.0)
	var pitch: float = lerpf(0.9, 2.15, closeness)
	sonar_player.pitch_scale = pitch
	sonar_player.play()


func tick(ship_world_position: Vector3, piloting: bool) -> void:
	if not piloting:
		noise_player.stop()
		music_player.stop()
		return
	var tower: Antenna = find_closest_antenna(ship_world_position)
	if tower == null:
		noise_player.stop()
		music_player.stop()
		return
	var distance: float = ship_world_position.distance_to(tower.global_position)
	if tower.is_repaired:
		noise_player.stop()
		if distance < MUSIC_RANGE and music_player.stream != null:
			if not music_player.playing:
				music_player.play()
		else:
			music_player.stop()
		return
	music_player.stop()
	if distance > NOISE_FADE_START:
		noise_player.stop()
		return
	var span: float = NOISE_FADE_START - NOISE_FADE_END
	var blend: float = 1.0 - clampf((distance - NOISE_FADE_END) / span, 0.0, 1.0)
	noise_player.volume_db = lerpf(-42.0, -6.0, blend)
	if not noise_player.playing:
		noise_player.play()


func find_closest_antenna(from: Vector3) -> Antenna:
	var best: Antenna = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("antennas"):
		if not (node is Antenna):
			continue
		var antenna: Antenna = node as Antenna
		var distance: float = from.distance_to(antenna.global_position)
		if distance < best_distance:
			best_distance = distance
			best = antenna
	return best
