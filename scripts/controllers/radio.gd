extends Node3D
class_name Radio

const NOISE_STREAM: AudioStream = preload("res://game/audios/noise.ogg")
const SONAR_STREAM: AudioStream = preload("res://game/audios/sonar.ogg")

const ECHO_SHELL_DEPTH: float = 1600.0
const BROKEN_STATIC_INNER_SURFACE: float = 120.0
const BROKEN_STATIC_OUTER_SURFACE: float = 520.0
const ECHO_DELAY: float = 0.22
const STATIC_OFF_DB: float = -80.0
const STATIC_STREAM_MAX_DB: float = 2.0

@onready var sonar_player: AudioStreamPlayer3D = $SonarPlayer
@onready var noise_player: AudioStreamPlayer3D = $NoisePlayer
@onready var tower_music_player: AudioStreamPlayer3D = $TowerMusicPlayer

var tower_music_source_id: int = 0


func _ready() -> void:
	setup_noise_player()
	setup_sonar_player()
	setup_tower_music_player()


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
	configure_spatial_player(noise_player, 180.0, 42.0)


func setup_sonar_player() -> void:
	sonar_player.stream = SONAR_STREAM
	sonar_player.volume_db = AudioLevels.RADIO_PING_DB
	configure_spatial_player(sonar_player, 80000.0, 120.0)


func setup_tower_music_player() -> void:
	tower_music_player.volume_db = AudioLevels.TOWER_MUSIC_VOLUME_DB
	configure_spatial_player(tower_music_player, 140.0, 48.0)


func closest_tower(listener_pos: Vector3) -> Antenna:
	return Antenna.closest_to(listener_pos, get_tree())


func play_ping(listener_pos: Vector3) -> void:
	sonar_player.pitch_scale = 1.0
	sonar_player.volume_db = AudioLevels.RADIO_PING_DB
	sonar_player.play()
	if not echo_is_in_range(listener_pos):
		return
	var echo_pitch: float = tower_echo_pitch(listener_pos)
	get_tree().create_timer(ECHO_DELAY).timeout.connect(func ():
		sonar_player.pitch_scale = echo_pitch
		sonar_player.volume_db = (
			AudioLevels.RADIO_PING_DB - AudioLevels.RADIO_PING_ECHO_QUIETER_DB
		)
		sonar_player.play()
	)


func distance_to_tower_surface(listener_pos: Vector3, tower: Antenna) -> float:
	var radius: float = tower.planet_surface_radius()
	return maxf(listener_pos.distance_to(tower.global_position) - radius, 0.0)


func echo_is_in_range(listener_pos: Vector3) -> bool:
	var tower: Antenna = closest_tower(listener_pos)
	if tower == null or tower.is_repaired:
		return false
	return distance_to_tower_surface(listener_pos, tower) <= ECHO_SHELL_DEPTH


func tower_echo_pitch(listener_pos: Vector3) -> float:
	var tower: Antenna = closest_tower(listener_pos)
	var dist_surface: float = distance_to_tower_surface(listener_pos, tower)
	var closeness: float = 1.0 - clampf(dist_surface / ECHO_SHELL_DEPTH, 0.0, 1.0)
	return lerpf(0.88, 2.05, closeness)


func tick(listener_pos: Vector3) -> void:
	var tower: Antenna = closest_tower(listener_pos)
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


func set_music_focus(focus: Antenna) -> void:
	if focus == null or not focus.is_repaired or focus.music_stream == null:
		tower_music_player.stop()
		tower_music_source_id = 0
		return
	var source_id: int = focus.get_instance_id()
	if tower_music_player.playing and tower_music_source_id == source_id:
		return
	tower_music_source_id = source_id
	tower_music_player.stream = make_looping_stream(focus.music_stream)
	tower_music_player.volume_db = AudioLevels.TOWER_MUSIC_VOLUME_DB
	tower_music_player.play()
