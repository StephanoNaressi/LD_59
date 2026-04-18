extends RefCounted
class_name ShipWeaponSpawn

## Shared helpers for ship-fired projectiles (camera aim, scene root, physics exclusions).


## Picks the overlapping body whose screen position is closest to the view center (same rule as ship crosshair).
static func pick_body_in_engagement(
	camera: Camera3D,
	engagement: Area3D,
	should_include: Callable
) -> Node:
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var viewport_center: Vector2 = camera.get_viewport().get_visible_rect().size * 0.5
	var best: Node = null
	var best_screen_d2: float = INF
	var best_world_d2: float = INF
	for body in engagement.get_overlapping_bodies():
		if not should_include.call(body):
			continue
		var to_b: Vector3 = (body as Node3D).global_position - origin
		if forward.dot(to_b) <= 0.0:
			continue
		var world_d2: float = to_b.length_squared()
		var screen_d2: float = (
			camera.unproject_position((body as Node3D).global_position) - viewport_center
		).length_squared()
		if (
			best == null
			or screen_d2 < best_screen_d2
			or (is_equal_approx(screen_d2, best_screen_d2) and world_d2 < best_world_d2)
		):
			best = body
			best_screen_d2 = screen_d2
			best_world_d2 = world_d2
	return best


static func add_to_current_scene(ship: Node, node: Node) -> bool:
	var scene: Node = ship.get_tree().current_scene
	if scene == null:
		return false
	scene.add_child(node)
	return true


static func aim_from_camera(camera: Camera3D, forward_offset: float) -> Dictionary:
	var forward: Vector3 = -camera.global_transform.basis.z
	if forward.length_squared() < 0.0001:
		forward = Vector3(0, 0, -1)
	else:
		forward = forward.normalized()
	var origin: Vector3 = camera.global_position + forward * forward_offset
	return {"origin": origin, "forward": forward}


static func exclude_ship_rid(ship: Node3D) -> Array[RID]:
	return [ship.get_rid()]
