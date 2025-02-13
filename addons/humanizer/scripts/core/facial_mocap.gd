@tool
extends Node

enum AppType {
	MeowFace,
	iFacialMocapTr
}

@export_category("Animation Authoring Settings")
@export var _recording := false:
	set(value):
		if not value:  ## done recording
			_recording = false
			if clip == null:
				return
			clip.length = next_key
			_animation_library.add_animation(_clip_name, clip)
			push_warning('Recording finished. Animation clip added to library.')
		elif _animation_library == null:
			printerr('No animation library supplied')
			return
		elif _clip_name in ['', null]:
			printerr('No clip name supplied')
			return
		else:  ## okay, start recording
			_streaming = true
			#human = get_node_or_null('../')
			if human == null or skeleton == null or animation_tree == null:
				printerr('Missing at least one of the following in the scene : human, skeleton, animator')
				return
			if human.human_config.rig != 'default-RETARGETED':
				printerr('Only the default-RETARGETED rig is compatible with face mocap')
				return
			_recording = true
			t0 = Time.get_ticks_msec() / 1e3
			next_key = 0
			clip = Animation.new()
			push_warning('Recording in progress')
## The target framerate of the authored animation clip
@export var _framerate: float = 30
## The name of the recorded animation clip
@export var _clip_name: String
## The animation library where authored clips should be saved
@export var _animation_library: AnimationLibrary


var t0: float
var next_key: float
var clip: Animation
var socket := UDPServer.new()
var peer: PacketPeerUDP
@onready var human: Humanizer
var skeleton: Skeleton3D:
	get:
		return human.skeleton
var animation_tree: AnimationTree:
	get:
		return human.animator

@export_category('Mocap Streaming Settings')
## The app you are using to stream mocap data, MeowFace and iFacialMocapTr supported
@export var app: AppType
## Is streaming data from connected app
@export var _streaming: bool = true:
	set(value):
		_streaming = value
		if _streaming:
			if not socket.is_listening():
				socket.listen(port)
			if socket.get_local_port() != port:
				socket.stop()
				socket.listen(port)
		else:
			socket.stop()
			if human != null:
				human.reset_face_pose()
## The port to connect to
@export var port: int = 49983


func _process(_delta) -> void:
	if not _streaming:
		return
	if human != null and human.human_config.rig != 'default-RETARGETED':
		return
	if skeleton == null or animation_tree == null:
		return
		
	socket.poll()
	if socket.is_connection_available():
		print('Cconnecting to mocap peer')
		peer = socket.take_connection()
	if peer == null:
		return
		
	var packet = peer.get_packet()
	if packet.size() == 0:
		return
	
	var data := get_data(packet)
	if data.size() == 0:
		return
	
	for bs in data.BlendShapes:
		#if not face_poses.has_animation(bs):
		#	printerr('missing clip for ' + bs)
		var value = data.BlendShapes[bs]
		animation_tree.set("parameters/" + bs + "/add_amount",value)
	
	if not _recording:
		return
		
	var t: float = Time.get_ticks_msec() / 1e3 - t0
	if t < next_key:
		return
	next_key = t + 1 / _framerate
	
	var track: int 
	## Don't record all bones.  Skip until we get to the neck
	var skip := true  
	
	for bone in skeleton.get_bone_count():
		if skip:
			if &'neck' in skeleton.get_bone_name(bone).to_lower():
				skip = false
			else:
				continue
		var path = NodePath(&'%GeneralSkeleton:' + skeleton.get_bone_name(bone))
		
		var transform = skeleton.get_bone_rest(bone)
		var basis: Basis = transform.basis
		var scale := Vector3(basis.x.length(), basis.y.length(), basis.z.length())
		var pos = transform.origin

		if skeleton.get_bone_pose_rotation(bone) != basis.get_rotation_quaternion():
			track = clip.find_track(path, Animation.TrackType.TYPE_ROTATION_3D)
			if track == -1:
				track = clip.add_track(Animation.TrackType.TYPE_ROTATION_3D)
				clip.track_set_path(track, path)
			clip.track_insert_key(track, t, skeleton.get_bone_pose_rotation(bone))
			
		if skeleton.get_bone_pose_scale(bone) != scale:
			track = clip.find_track(path, Animation.TrackType.TYPE_SCALE_3D)
			if track == -1:
				track = clip.add_track(Animation.TrackType.TYPE_SCALE_3D)
				clip.track_set_path(track, path)
			clip.track_insert_key(track, t, skeleton.get_bone_pose_scale(bone))

		if skeleton.get_bone_pose_position(bone) != pos:
			track = clip.find_track(path, Animation.TrackType.TYPE_POSITION_3D)
			if track == -1:
				track = clip.add_track(Animation.TrackType.TYPE_POSITION_3D)
				clip.track_set_path(track, path)
			clip.track_insert_key(track, t, skeleton.get_bone_pose_position(bone) / skeleton.motion_scale)


func get_data(packet) -> Dictionary:
	if app == AppType.MeowFace:
		var data = JSON.parse_string(packet.get_string_from_utf8())
		var bs = {}
		for b in data.BlendShapes:
			bs[b.k] = b.v
		data['BlendShapes'] = bs
		return data
	elif app == AppType.iFacialMocapTr:
		var data = packet.get_string_from_utf8()
		var head_str = data.split('head#')[1].split('|')[0].split(',')
		var head: Array[float]
		for i in head_str.size():
			head.append(float(head_str[i]))
		data = data.replace('_R', 'Right').replace('_L', 'Left').replace('-', '":"').replace('|', '","').replace('#', '":"')
		data = data.split(',"hapi')[0]
		data = '{"' + data + '}'
		data = JSON.parse_string(data)
		data.erase(&'trackingStatus')
		for k in data:
			data[k] = float(data[k]) / 100
		if head[0] > 0:
			data[&'headDown'] = head[0] / 35
		else:
			data[&'headUp'] = -head[0] / 35
		if head[2] > 0:
			data[&'headRollRight'] = head[2] / 35
		else:
			data[&'headRollLeft'] = -head[2] / 35
		if head[1] > 0:
			data[&'headLeft'] = head[1] / 35
		else:
			data[&'headRight'] = -head[1] / 35
		data[&'jawOpen'] = max(data[&'jawOpen'] - 0.1, 0)
		data = {&'BlendShapes': data}
		#data[&'headPosition'] = head.slice(3)
		return data
	return {}
