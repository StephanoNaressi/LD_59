extends Control

@export var radar_radius_meters: float = 3000.0
@export var ring_fill: Color = Color(0.22, 0.28, 0.38, 0.92)
@export var ring_stroke: Color = Color(0.4, 0.48, 0.58, 0.55)
@export var heading_marker: Color = Color(0.55, 0.78, 1.0, 0.95)
@export var belt_dot: Color = Color(0.55, 0.72, 0.55, 0.88)
@export var ping_antenna_dot: Color = Color(1.0, 0.82, 0.45, 0.95)
@export var repaired_antenna_dot: Color = Color(0.35, 0.92, 0.42, 0.95)
@export var sonar_ring_color: Color = Color(0.35, 0.72, 1.0, 0.5)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if GlobalValues.player == null:
		return
	var player: Node3D = GlobalValues.player
	var body: Node3D = player.vehicle if player.vehicle != null else player
	var widget_center: Vector2 = size * 0.5
	var ring_radius: float = minf(size.x, size.y) * 0.5 - 6.0
	if ring_radius <= 4.0:
		return

	var now_sec: float = Time.get_ticks_msec() / 1000.0

	draw_arc(widget_center, ring_radius, 0.0, TAU, 48, ring_fill, 3.0, true)
	draw_arc(widget_center, ring_radius, 0.0, TAU, 48, ring_stroke, 1.2, false)

	var seconds_since_ping: float = now_sec - GlobalValues.radar_ping_start_sec
	if seconds_since_ping >= 0.0 and seconds_since_ping < 0.7:
		var pulse: float = seconds_since_ping / 0.7
		var sonar_radius: float = ring_radius * pulse
		var fade: float = (1.0 - pulse) * 0.55
		draw_arc(
			widget_center,
			sonar_radius,
			0.0,
			TAU,
			56,
			Color(sonar_ring_color.r, sonar_ring_color.g, sonar_ring_color.b, fade),
			2.8,
			false
		)
		var echo_radius: float = ring_radius * pulse * 0.62
		draw_arc(
			widget_center,
			echo_radius,
			0.0,
			TAU,
			48,
			Color(sonar_ring_color.r, sonar_ring_color.g, sonar_ring_color.b, fade * 0.55),
			1.6,
			false
		)

	var look_flat: Vector3 = -body.global_transform.basis.z
	look_flat.y = 0.0
	var forward_xz: Vector2
	if look_flat.length_squared() < 0.0001:
		forward_xz = Vector2(0.0, -1.0)
	else:
		look_flat = look_flat.normalized()
		forward_xz = Vector2(look_flat.x, look_flat.z)
	var pixels_per_meter: float = ring_radius / maxf(radar_radius_meters, 1.0)
	var player_xz: Vector2 = Vector2(body.global_position.x, body.global_position.z)

	var nearest_belt_delta: Vector2 = Vector2.ZERO
	var nearest_belt_dist_sq: float = INF
	for belt in get_tree().get_nodes_in_group(&"asteroid_belts"):
		if belt is Node3D:
			var belt_xz: Vector2 = Vector2((belt as Node3D).global_position.x, (belt as Node3D).global_position.z)
			var belt_delta: Vector2 = belt_xz - player_xz
			var belt_dist_sq: float = belt_delta.length_squared()
			if belt_dist_sq < nearest_belt_dist_sq:
				nearest_belt_dist_sq = belt_dist_sq
				nearest_belt_delta = belt_delta
	if nearest_belt_dist_sq < INF:
		draw_circle(
			widget_center
			+ to_map(nearest_belt_delta, forward_xz, pixels_per_meter, ring_radius, 4.0),
			3.5,
			belt_dot
		)

	for node in get_tree().get_nodes_in_group(TowerRegistry.GROUP_ANTENNAS):
		if not (node is Antenna):
			continue
		var map_antenna: Antenna = node as Antenna
		if not map_antenna.is_repaired:
			continue
		var rep_delta: Vector2 = (
			Vector2(map_antenna.global_position.x, map_antenna.global_position.z) - player_xz
		)
		draw_circle(
			widget_center
			+ to_map(rep_delta, forward_xz, pixels_per_meter, ring_radius, 4.0),
			4.0,
			repaired_antenna_dot
		)

	if now_sec < GlobalValues.radar_ping_until_sec:
		var ping_target: Antenna = null
		var ping_best: float = INF
		var any_target: Antenna = null
		var any_best: float = INF
		for ping_node in get_tree().get_nodes_in_group(TowerRegistry.GROUP_ANTENNAS):
			if not (ping_node is Antenna):
				continue
			var cand: Antenna = ping_node as Antenna
			var d2: float = (
				Vector2(cand.global_position.x, cand.global_position.z) - player_xz
			).length_squared()
			if d2 < any_best:
				any_best = d2
				any_target = cand
			if not cand.is_repaired and d2 < ping_best:
				ping_best = d2
				ping_target = cand
		var show: Antenna = ping_target if ping_target != null else any_target
		if show != null:
			var ping_delta: Vector2 = Vector2(show.global_position.x, show.global_position.z) - player_xz
			draw_circle(
				widget_center
				+ to_map(ping_delta, forward_xz, pixels_per_meter, ring_radius, 5.0),
				5.0,
				ping_antenna_dot
			)

	var arrow_tip: Vector2 = widget_center + Vector2(0.0, -10.0)
	draw_colored_polygon(
		PackedVector2Array(
			[arrow_tip + Vector2(0, -8), arrow_tip + Vector2(-7, 6), arrow_tip + Vector2(7, 6)]
		),
		heading_marker
	)


func to_map(
	world_delta_xz: Vector2,
	forward_xz: Vector2,
	pixels_per_meter: float,
	ring_radius: float,
	edge_inset: float
) -> Vector2:
	var right: Vector2 = Vector2(-forward_xz.y, forward_xz.x)
	var screen: Vector2 = Vector2(world_delta_xz.dot(right), -world_delta_xz.dot(forward_xz)) * pixels_per_meter
	return screen.limit_length(ring_radius - edge_inset)
