@tool
extends Node

enum AppType {
	MeowFace,
	iFacialMocapTr
}


@export var _recording := false:
	set(value):
		if not value:
			_recording = false
			if clip == null:
				return
			_animation_library.add_animation(_clip_name, clip)
			push_warning('Recording finished')
		if _animation_library == null:
			printerr('No animation library supplied')
			return
		if _clip_name in [&'', null]:
			printerr('No clip name supplied')
			return
		stream = true
		_recording = true
		t0 = Time.get_ticks_msec() / 1000
		clip = Animation.new()
		push_warning('Recording in progress')
## The name of the recorded animation clip
@export var _clip_name: String
## The animation library where authored clips should be saved
@export var _animation_library: AnimationLibrary
## The app you are using to stream mocap data, MeowFace adn iFacialMocapTr supported
@export var app: AppType

var t0: float
var clip: Animation
var animation_tree: AnimationTree 
var skeleton: Skeleton3D
var socket := UDPServer.new()
var peer: PacketPeerUDP
## Stream data from connected app
@export var stream: bool = false:
	set(value):
		stream = value
		if stream:
			socket.listen(port)
		else:
			socket.stop()
## The port to connect to
@export var port: int = 49983

var _clip_data := {}
var recording := true
var pose := {}

func _process(_delta) -> void:	
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
	
	pose = {}
	for bs in data.BlendShapes:
		#if not face_poses.has_animation(bs):
		#	printerr('missing clip for ' + bs)
		var value = data.BlendShapes[bs]
		animation_tree.set("parameters/" + bs + "/add_amount",value)
	
	if not _recording:
		return
		
	var t: float = Time.get_ticks_msec() / 1000 - t0
	var track: int 
	
	for bone in skeleton.get_bone_count():
		var path = NodePath(&'%GeneralSkeleton:' + skeleton.get_bone_name(bone))
		
		track = clip.find_track(path, Animation.TrackType.TYPE_POSITION_3D)
		if track == -1:
			track = clip.add_track(Animation.TrackType.TYPE_POSITION_3D)
			clip.track_set_path(track, path)
		clip.track_insert_key(track, t, skeleton.get_bone_pose_position(bone))
		
		track = clip.find_track(path, Animation.TrackType.TYPE_ROTATION_3D)
		if track == -1:
			track = clip.add_track(Animation.TrackType.TYPE_ROTATION_3D)
			clip.track_set_path(track, path)
		clip.track_insert_key(track, t, skeleton.get_bone_pose_rotation(bone))
		
		track = clip.find_track(path, Animation.TrackType.TYPE_SCALE_3D)
		if track == -1:
			track = clip.add_track(Animation.TrackType.TYPE_SCALE_3D)
			clip.track_set_path(track, path)
		clip.track_insert_key(track, t, skeleton.get_bone_pose_scale(bone))

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
		data = data.replace('_R', 'Right').replace('_L', 'Left').replace('-', '":"').replace('|', '","').replace('#', '":"')
		data = data.split(',"hapi')[0]
		data = '{"' + data + '}'
		data = JSON.parse_string(data)
		data.erase('trackingStatus')
		for k in data:
			data[k] = float(data[k]) / 100
		return {'BlendShapes': data}
	return {}
