extends Node3D
class_name Radio

const NOISE_STREAM: AudioStream = preload("res://game/audios/noise.ogg")
const SONAR_STREAM: AudioStream = preload("res://game/audios/sonar.ogg")

const ECHO_SHELL_DEPTH: float = 420.0
const NOISE_SHELL_INNER: float = 220.0
const NOISE_SHELL_OUTER: float = 14000.0
const RADIO_HEAR: float = 220.0
const ECHO_DELAY: float = 0.22
const SONAR_DB: float = -14.0

@onready var sonar_player: AudioStreamPlayer3D = $SonarPlayer
@onready var noise_player: AudioStreamPlayer3D = $NoisePlayer


func _ready() -> void:
	var loop: AudioStreamOggVorbis = NOISE_STREAM.duplicate() as AudioStreamOggVorbis
	loop.loop = true
	noise_player.stream = loop
	noise_player.volume_db = -80.0
	sonar_player.stream = SONAR_STREAM
	sonar_player.volume_db = SONAR_DB


func play_ping(listener_pos: Vector3) -> void:
	sonar_player.pitch_scale = 1.0
	sonar_player.volume_db = SONAR_DB
	sonar_player.play()
	if not echo_is_in_range(listener_pos):
		return
	var echo_pitch: float = tower_echo_pitch(listener_pos)
	get_tree().create_timer(ECHO_DELAY).timeout.connect(func ():
		sonar_player.pitch_scale = echo_pitch
		sonar_player.volume_db = SONAR_DB - 3.0
		sonar_player.play()
	)


func distance_to_tower_surface(listener_pos: Vector3, tower: Antenna) -> float:
	var radius: float = tower.planet_surface_radius()
	return maxf(listener_pos.distance_to(tower.global_position) - radius, 0.0)


func echo_is_in_range(listener_pos: Vector3) -> bool:
	var tower: Antenna = Antenna.closest_to(listener_pos, get_tree())
	if tower == null or tower.is_repaired:
		return false
	return distance_to_tower_surface(listener_pos, tower) <= ECHO_SHELL_DEPTH


func tower_echo_pitch(listener_pos: Vector3) -> float:
	var tower: Antenna = Antenna.closest_to(listener_pos, get_tree())
	var dist_surface: float = distance_to_tower_surface(listener_pos, tower)
	var closeness: float = 1.0 - clampf(dist_surface / ECHO_SHELL_DEPTH, 0.0, 1.0)
	return lerpf(0.88, 2.05, closeness)


func tick(listener_pos: Vector3) -> void:
	var tower: Antenna = Antenna.closest_to(listener_pos, get_tree())
	if tower == null:
		noise_player.stop()
		set_music_focus(null)
		return
	var dist_surface: float = distance_to_tower_surface(listener_pos, tower)
	if tower.is_repaired:
		noise_player.stop()
		set_music_focus(tower)
		return
	set_music_focus(null)
	if dist_surface > NOISE_SHELL_OUTER:
		noise_player.stop()
		return
	var near_radio: float = clampf(1.0 - listener_pos.distance_to(global_position) / RADIO_HEAR, 0.0, 1.0)
	if near_radio < 0.03:
		noise_player.stop()
		return
	var span: float = NOISE_SHELL_OUTER - NOISE_SHELL_INNER
	var tower_blend: float = 1.0 - clampf((dist_surface - NOISE_SHELL_INNER) / span, 0.0, 1.0)
	var blend: float = tower_blend * near_radio
	noise_player.volume_db = lerpf(-50.0, -28.0, blend)
	if not noise_player.playing:
		noise_player.play()


func set_music_focus(focus: Antenna) -> void:
	for node in get_tree().get_nodes_in_group("antennas"):
		if node is Antenna:
			var antenna: Antenna = node as Antenna
			antenna.set_tower_music_playing(antenna == focus)
