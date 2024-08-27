@tool
extends Resource
class_name HumanizerColliderService

static func get_main_collider(helper_vertex:PackedVector3Array):
	var main_collider = CollisionShape3D.new()
	main_collider.shape = CapsuleShape3D.new()
	main_collider.name = 'MainCollider'
	adjust_main_collider(helper_vertex,main_collider)
	return main_collider

static func adjust_main_collider(helper_vertex:PackedVector3Array,main_collider:CollisionShape3D):
	var head_height = HumanizerBodyService.get_head_height(helper_vertex)
	var offset = HumanizerBodyService.get_foot_offset(helper_vertex)
	var height = head_height - offset
	main_collider.shape.height = height
	main_collider.position.y = height/2 + offset
	main_collider.shape.radius = HumanizerBodyService.get_max_width(helper_vertex)
