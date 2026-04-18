extends Node3D
class_name RepairProyectile

const GROUP_NAME: String = "repair_projectile"

const SPEED: float = 72.0
const HIT_DISTANCE: float = 1.25

var target_antenna: Antenna


func _ready() -> void:
	add_to_group(GROUP_NAME)


static func despawn_all_in_tree(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group(GROUP_NAME):
		if is_instance_valid(node):
			node.queue_free()


func configure_homing(antenna: Antenna, muzzle: Node3D) -> void:
	target_antenna = antenna
	global_position = muzzle.global_position


func _process(delta: float) -> void:
	if target_antenna == null or not is_instance_valid(target_antenna):
		queue_free()
		return
	if target_antenna.is_repaired:
		queue_free()
		return
	var aim: Vector3 = target_antenna.get_weapon_aim_position()
	global_position = global_position.move_toward(aim, SPEED * delta)
	if global_position.distance_to(aim) <= HIT_DISTANCE:
		target_antenna.apply_repair_hit()
		queue_free()
