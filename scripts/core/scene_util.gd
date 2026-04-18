extends RefCounted
class_name SceneUtil


static func add_child_to_current_scene(anchor: Node, child: Node) -> bool:
	var scene: Node = anchor.get_tree().current_scene
	if scene == null:
		return false
	scene.add_child(child)
	return true
