extends CharacterBody3D

@export var _camera: Node
@export_range(0.1, 5) var move_speed: float = 1

const GRAVITY: float  = 9.8


# Advance expressions
var moving: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	var msg: String = 'This script was automatically added to your generated human. '
	msg += 'You can set a different default script in your HumanizerConfig resource '
	msg += 'on the humanizer_global.tscn scene root node.'
	print(msg)
	
	var anim = $AnimationTree as AnimationTree
	# Seems like animation tree has to be inactivated for this to work
	anim.active = false
	anim.advance_expression_base_node = get_path()
	anim.active = true

func _physics_process(delta):
	if _camera == null:
		return
	
	var cam_right: Vector3 = _camera.basis.x
	var cam_forward: Vector3 = -_camera.basis.z
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

	move_and_slide()
