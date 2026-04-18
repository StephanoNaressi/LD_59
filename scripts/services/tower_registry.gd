extends Node


const GROUP_ANTENNAS: StringName = &"antennas"

var xy_by_name: Dictionary = {}


func refresh_from_tree(tree: SceneTree) -> void:
	xy_by_name.clear()
	for n in tree.get_nodes_in_group(GROUP_ANTENNAS):
		if not (n is Antenna):
			continue
		var antenna: Antenna = n as Antenna
		xy_by_name[antenna.name] = Vector2(antenna.global_position.x, antenna.global_position.z)


func sorted_labels() -> PackedStringArray:
	var keys: Array = xy_by_name.keys()
	keys.sort()
	var lines: PackedStringArray = PackedStringArray()
	for k in keys:
		var flat: Vector2 = xy_by_name[k]
		lines.append("%s   X:%.0f   Z:%.0f" % [str(k), flat.x, flat.y])
	return lines
