extends Node


const GROUP_ANTENNAS: StringName = &"antennas"

var xy_by_name: Dictionary = {}


func rebuild_from_tree(tree: SceneTree) -> void:
	xy_by_name.clear()
	for node in tree.get_nodes_in_group(GROUP_ANTENNAS):
		if not (node is Antenna):
			continue
		var antenna: Antenna = node as Antenna
		xy_by_name[antenna.name] = Vector2(antenna.global_position.x, antenna.global_position.z)


func get_sorted_labels() -> PackedStringArray:
	var keys: Array = xy_by_name.keys()
	keys.sort()
	var lines: PackedStringArray = PackedStringArray()
	for antenna_name in keys:
		var flat: Vector2 = xy_by_name[antenna_name]
		lines.append("%s   X:%.0f   Z:%.0f" % [str(antenna_name), flat.x, flat.y])
	return lines
