extends Camera3D

@export_range(0.1, 1.) var look_speed: float = 0.4
@export_range(0.5, 5.) var move_speed: float = 1.

@onready var pitch: float = rotation.y
@onready var yaw: float = rotation.x

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta):
	if Input.is_key_pressed(KEY_ESCAPE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_key_pressed(KEY_W):
		position -= basis.z * move_speed * delta
	if Input.is_key_pressed(KEY_S):
		position += basis.z * move_speed * delta
	if Input.is_key_pressed(KEY_D):
		position += basis.x * move_speed * delta
	if Input.is_key_pressed(KEY_A):
		position -= basis.x * move_speed * delta
	if Input.is_key_pressed(KEY_Q):
		position -= basis.y * move_speed * delta
	if Input.is_key_pressed(KEY_E):
		position += basis.y * move_speed * delta
			

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		print(event.relative)
		pitch -= event.relative.y * look_speed * get_process_delta_time()
		yaw -= event.relative.x * look_speed * get_process_delta_time()
	pitch = clampf(pitch, -PI * .45, PI * .45)
	rotation = Vector3(pitch, yaw, 0)
