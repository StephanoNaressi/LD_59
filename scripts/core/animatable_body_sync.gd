extends RefCounted
class_name AnimatableBodySync


static func push_transforms_to_physics(root: Node) -> void:
	for n in root.find_children("*", "AnimatableBody3D", true, false):
		var ab: AnimatableBody3D = n as AnimatableBody3D
		var rid: RID = ab.get_rid()
		if not rid.is_valid():
			continue
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, ab.global_transform)
