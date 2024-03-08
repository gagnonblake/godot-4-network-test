extends Node3D

@onready var mesh_node: MeshInstance3D = $BallBody/MeshInstance3D

@export var current_color: Color

func _ready():
	multiplayer.peer_connected.connect(load_color)

@rpc("any_peer", "call_local")
func update_color(new_color: Color):
	current_color = new_color
	var mesh: Mesh = mesh_node.mesh
	var material: Material = mesh.surface_get_material(0)
	material.albedo_color = current_color
	mesh.surface_set_material(0, material)

func load_color(_peer_id):
	call_deferred("sync_color")

func sync_color():
	rpc("update_color", current_color)
