extends Control

@export var radar_radius_meters: float = 1200.0
@export var ring_fill: Color = Color(0.22, 0.28, 0.38, 0.92)
@export var ring_stroke: Color = Color(0.4, 0.48, 0.58, 0.55)
@export var heading_marker: Color = Color(0.55, 0.78, 1.0, 0.95)
@export var belt_dot: Color = Color(0.55, 0.72, 0.55, 0.88)
@export var ping_antenna_dot: Color = Color(1.0, 0.82, 0.45, 0.95)
@export var sonar_ring_color: Color = Color(0.35, 0.72, 1.0, 0.5)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var player: Player = GlobalValues.player
	if player == null:
		return
	var navigation_body: Node3D = player.vehicle if player.vehicle != null else player
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

	var forward_xz: Vector2 = Vector2(
		-navigation_body.global_transform.basis.z.x,
		-navigation_body.global_transform.basis.z.z
	)
	if forward_xz.length_squared() < 0.0001:
		forward_xz = Vector2(0.0, -1.0)
	else:
		forward_xz = forward_xz.normalized()
	var pixels_per_meter: float = ring_radius / maxf(radar_radius_meters, 1.0)
	var player_xz: Vector2 = Vector2(navigation_body.global_position.x, navigation_body.global_position.z)

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

	if now_sec < GlobalValues.radar_ping_until_sec:
		var nearest_antenna_delta: Vector2 = Vector2.ZERO
		var nearest_antenna_dist_sq: float = INF
		for antenna_xz in TowerRegistry.xy_by_name.values():
			var antenna_delta: Vector2 = antenna_xz - player_xz
			var antenna_dist_sq: float = antenna_delta.length_squared()
			if antenna_dist_sq < nearest_antenna_dist_sq:
				nearest_antenna_dist_sq = antenna_dist_sq
				nearest_antenna_delta = antenna_delta
		if nearest_antenna_dist_sq < INF:
			draw_circle(
				widget_center
				+ to_map(nearest_antenna_delta, forward_xz, pixels_per_meter, ring_radius, 5.0),
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
