extends RefCounted
class_name AnimatableBodySync


static func push_transforms_to_physics(root: Node) -> void:
	for child in root.find_children("*", "AnimatableBody3D", true, false):
		var animatable_body: AnimatableBody3D = child as AnimatableBody3D
		var rid: RID = animatable_body.get_rid()
		if not rid.is_valid():
			continue
		PhysicsServer3D.body_set_state(
			rid, PhysicsServer3D.BODY_STATE_TRANSFORM, animatable_body.global_transform
		)
