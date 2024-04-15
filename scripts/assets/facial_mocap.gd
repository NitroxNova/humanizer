@tool
class_name HumanizerMocap
extends Node

enum AppType {
	MeowFace,
	iFacialMocapTr
}
@export var face_poses: AnimationLibrary
@export var skeleton: Skeleton3D
@export var app: AppType
var socket := UDPServer.new()
var peer: PacketPeerUDP

@export var stream: bool = false:
	set(value):
		stream = value
		if stream:
			socket.listen(port)
		else:
			socket.stop()
@export var port: int = 5432

var _clip_data := {}
var recording := true
var pose := {}

func _process(_delta) -> void:
	if skeleton == null:
		skeleton = get_node_or_null('../GeneralSkeleton')
	if skeleton == null:
		return
	if face_poses == null:
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
		#if bs.k == 'tongueOut':
		#	print(bs.v)
		if not face_poses.has_animation(bs):
			continue
		var anim: Animation = face_poses.get_animation(bs)
		if anim == null:
			#print('missing pose for ' + bs.k)
			continue
		var value = data.BlendShapes[bs]
		for track_id in anim.get_track_count():
			var track_type: Animation.TrackType = anim.track_get_type(track_id)
			var path = str(anim.track_get_path(track_id))
			if not pose.has(path):
				pose[path] = {}
			if not pose[path].has(track_type):
				pose[path][track_type] = {'sum': 0}
			pose[path][track_type]['sum'] += value
			## Apply a weighted sum over all shapekeys
			if pose[path][track_type].has('value'):
				pose[path][track_type]['value'] += anim.track_get_key_value(track_id, 0) * value
			else:
				pose[path][track_type]['value'] = anim.track_get_key_value(track_id, 0) * value

	## Normalize by sum total of all shapekey values
	for path in pose:
		for track_type in pose[path]:
			pose[path][track_type].value /= pose[path][track_type].sum

	## Apply pose to skeleton
	for path in pose:
		var bone = skeleton.find_bone(path.split(':')[1])
		for track_type in pose[path]:
			if track_type == Animation.TrackType.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, pose[path][track_type].value)
			elif track_type == Animation.TrackType.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, pose[path][track_type].value)
			elif track_type == Animation.TrackType.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, pose[path][track_type].value)

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
