extends CharacterBody3D

@export var camera: Node3D
@export_range(0.1, 5) var move_speed: float = 2
@export_range(0, 100) var vertical_impulse: float = 60

@onready var skeleton: Skeleton3D = $GeneralSkeleton
const GRAVITY: float  = 9.8


# Advance expressions
var moving: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():	
	var anim = $AnimationTree as AnimationTree
	# Seems like animation tree has to be inactivated for this to work
	anim.active = false
	anim.advance_expression_base_node = get_path()
	anim.active = true
	
	skeleton.physical_bones_stop_simulation()
	skeleton.animate_physical_bones = false

func _physics_process(delta):
	if camera == null:
		return
	
	var cam_right: Vector3 = camera.basis.x
	var cam_forward: Vector3 = -camera.basis.z
	cam_right.y = 0
	cam_forward.y = 0
	cam_right = cam_right.normalized()
	cam_forward = cam_forward.normalized()
	
	var move_input: Vector2 = Input.get_vector(
		&'ui_left', &'ui_right', &'ui_down', &'ui_up')
	moving = move_input.length() > 0.1  # Give a little deadzone

	var movement: Vector3 = move_input.x * cam_right + move_input.y * cam_forward
	if moving:
		# IDK why negative signs but it works
		transform.basis = Basis.looking_at(-movement)
	
	movement = movement * move_speed
	velocity.x = movement.x
	velocity.z = movement.z
	velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed(&'ui_accept'):
		if skeleton != null:
			if skeleton.get_child_count() > 0:
				if (skeleton.get_child(0) as PhysicalBone3D).is_simulating_physics():
					skeleton.physical_bones_stop_simulation()
				else:
					skeleton.physical_bones_start_simulation()
					(skeleton.get_child(0) as PhysicalBone3D).linear_velocity = velocity
					(skeleton.get_child(0) as PhysicalBone3D).apply_impulse(Vector3.UP * vertical_impulse)
	move_and_slide()
