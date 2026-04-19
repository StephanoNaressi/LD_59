extends Node3D
class_name Radio

const NOISE_STREAM: AudioStream = preload("res://game/audios/noise.ogg")
const SONAR_STREAM: AudioStream = preload("res://game/audios/sonar.ogg")

const ECHO_SHELL_DEPTH: float = 2000.0
const BROKEN_STATIC_INNER_SURFACE: float = 120.0
const BROKEN_STATIC_OUTER_SURFACE: float = 520.0
const ECHO_DELAY: float = 0.22
const STATIC_OFF_DB: float = -80.0
const STATIC_STREAM_MAX_DB: float = -4.0
const NOISE_HEAR_RADIUS_M: float = 44.0
const NOISE_UNIT_SIZE: float = 16.0
const SONAR_HEAR_RADIUS_M: float = 180.0
const SONAR_UNIT_SIZE: float = 36.0
const RADIO_SPEAKER_MAX_DISTANCE_M: float = 32.0
const RADIO_SPEAKER_UNIT_SIZE: float = 10.0
const BROADCAST_SIGNAL_FULL_WITHIN_M: float = 280.0
const BROADCAST_SIGNAL_GONE_BEYOND_M: float = 1200.0

@onready var sonar_player: AudioStreamPlayer3D = $SonarPlayer
@onready var noise_player: AudioStreamPlayer3D = $NoisePlayer
@onready var broadcast_player: AudioStreamPlayer3D = $TowerMusicPlayer

var broadcast_source_id: int = 0
var music_focus_antenna: Antenna = null


func _ready() -> void:
	setup_noise_player()
	setup_sonar_player()
	setup_antenna_broadcast_player()


func make_looping_stream(original: AudioStream) -> AudioStream:
	if original is AudioStreamOggVorbis:
		var ogg: AudioStreamOggVorbis = original.duplicate() as AudioStreamOggVorbis
		ogg.loop = true
		return ogg
	return original


func configure_spatial_player(
	player: AudioStreamPlayer3D, max_distance: float, unit_size: float
) -> void:
	player.max_distance = max_distance
	player.unit_size = unit_size
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	player.pitch_scale = 1.0


func setup_noise_player() -> void:
	noise_player.stream = make_looping_stream(NOISE_STREAM)
	noise_player.volume_db = STATIC_OFF_DB
	noise_player.max_db = STATIC_STREAM_MAX_DB
	configure_spatial_player(noise_player, NOISE_HEAR_RADIUS_M, NOISE_UNIT_SIZE)


func setup_sonar_player() -> void:
	sonar_player.stream = SONAR_STREAM
	sonar_player.volume_db = AudioLevels.RADIO_PING_DB
	configure_spatial_player(sonar_player, SONAR_HEAR_RADIUS_M, SONAR_UNIT_SIZE)


func setup_antenna_broadcast_player() -> void:
	broadcast_player.volume_db = AudioLevels.ANTENNA_BROADCAST_VOLUME_DB
	configure_spatial_player(
		broadcast_player, RADIO_SPEAKER_MAX_DISTANCE_M, RADIO_SPEAKER_UNIT_SIZE
	)


func closest_antenna(listener_pos: Vector3) -> Antenna:
	return Antenna.closest_to(listener_pos, get_tree())


func closest_repaired_antenna_with_music(listener_pos: Vector3) -> Antenna:
	var best: Antenna = null
	var best_d2: float = INF
	for node in get_tree().get_nodes_in_group(TowerRegistry.GROUP_ANTENNAS):
		var a: Antenna = node as Antenna
		if a == null or not a.is_repaired or a.music_stream == null:
			continue
		var d2: float = listener_pos.distance_squared_to(a.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = a
	return best


func play_ping(listener_pos: Vector3) -> void:
	sonar_player.pitch_scale = 1.0
	sonar_player.volume_db = AudioLevels.RADIO_PING_DB
	sonar_player.play()
	if not echo_is_in_range(listener_pos):
		return
	var echo_pitch: float = antenna_echo_pitch(listener_pos)
	get_tree().create_timer(ECHO_DELAY).timeout.connect(func ():
		sonar_player.pitch_scale = echo_pitch
		sonar_player.volume_db = (
			AudioLevels.RADIO_PING_DB - AudioLevels.RADIO_PING_ECHO_QUIETER_DB
		)
		sonar_player.play()
	)


func distance_to_antenna_surface(listener_pos: Vector3, antenna: Antenna) -> float:
	var radius: float = antenna.planet_surface_radius()
	return maxf(listener_pos.distance_to(antenna.global_position) - radius, 0.0)


func echo_is_in_range(listener_pos: Vector3) -> bool:
	var antenna: Antenna = closest_antenna(listener_pos)
	if antenna == null or antenna.is_repaired:
		return false
	return distance_to_antenna_surface(listener_pos, antenna) <= ECHO_SHELL_DEPTH


func antenna_echo_pitch(listener_pos: Vector3) -> float:
	var antenna: Antenna = closest_antenna(listener_pos)
	var dist_surface: float = distance_to_antenna_surface(listener_pos, antenna)
	var closeness: float = 1.0 - clampf(dist_surface / ECHO_SHELL_DEPTH, 0.0, 1.0)
	return lerpf(0.88, 2.05, closeness)


func broadcast_signal_offset_db(distance_to_tower_m: float) -> float:
	if distance_to_tower_m <= BROADCAST_SIGNAL_FULL_WITHIN_M:
		return 0.0
	if distance_to_tower_m >= BROADCAST_SIGNAL_GONE_BEYOND_M:
		return -75.0
	var t: float = (distance_to_tower_m - BROADCAST_SIGNAL_FULL_WITHIN_M) / (
		BROADCAST_SIGNAL_GONE_BEYOND_M - BROADCAST_SIGNAL_FULL_WITHIN_M
	)
	return lerpf(0.0, -58.0, t * t * t)


func tick(listener_pos: Vector3) -> void:
	var ear_pos: Vector3 = (
		GlobalValues.player.global_position
		if GlobalValues.player != null
		else listener_pos
	)
	var antenna: Antenna = closest_antenna(ear_pos)
	if antenna == null:
		noise_player.stop()
		set_music_focus(null)
		return
	var dist_surface: float = distance_to_antenna_surface(ear_pos, antenna)
	var music_antenna: Antenna = closest_repaired_antenna_with_music(ear_pos)
	if music_antenna != null:
		set_music_focus(music_antenna)
	else:
		set_music_focus(null)
	sync_broadcast_volume_for_signal(ear_pos)
	if antenna.is_repaired:
		noise_player.stop()
		return
	if dist_surface >= BROKEN_STATIC_OUTER_SURFACE:
		noise_player.stop()
		return
	var span: float = BROKEN_STATIC_OUTER_SURFACE - BROKEN_STATIC_INNER_SURFACE
	var static_blend: float = 1.0 - clampf(
		(dist_surface - BROKEN_STATIC_INNER_SURFACE) / span, 0.0, 1.0
	)
	if static_blend <= 0.02:
		noise_player.stop()
		return
	noise_player.pitch_scale = 1.0
	noise_player.volume_db = lerpf(
		AudioLevels.RADIO_STATIC_FAR_DB,
		AudioLevels.RADIO_STATIC_NEAR_DB,
		static_blend * static_blend
	)
	if not noise_player.playing:
		noise_player.play()


func sync_broadcast_volume_for_signal(ear_pos: Vector3) -> void:
	if not broadcast_player.playing:
		return
	if music_focus_antenna == null or not is_instance_valid(music_focus_antenna):
		return
	var dist_tower: float = ear_pos.distance_to(music_focus_antenna.global_position)
	var offset_db: float = broadcast_signal_offset_db(dist_tower)
	broadcast_player.volume_db = AudioLevels.ANTENNA_BROADCAST_VOLUME_DB + offset_db


func set_music_focus(focus: Antenna) -> void:
	if focus == null or not focus.is_repaired or focus.music_stream == null:
		broadcast_player.stop()
		broadcast_source_id = 0
		music_focus_antenna = null
		return
	var source_id: int = focus.get_instance_id()
	if broadcast_player.playing and broadcast_source_id == source_id:
		return
	broadcast_source_id = source_id
	music_focus_antenna = focus
	broadcast_player.stream = make_looping_stream(focus.music_stream)
	broadcast_player.volume_db = AudioLevels.ANTENNA_BROADCAST_VOLUME_DB
	broadcast_player.play()
