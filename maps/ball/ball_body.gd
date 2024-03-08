extends RigidBody3D

@onready var ball_node: Node = $".."

func clicked(new_color):
	ball_node.rpc("update_color", new_color)
