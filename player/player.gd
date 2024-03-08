extends CharacterBody3D

signal health_changed(health_value)

@onready var camera: Node = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var anim_player_hands: Node = $Hands/AnimationPlayer
@onready var left_hand: Node3D = $Hands/LeftHand
@onready var right_hand: Node3D = $Hands/RightHand
@onready var interact_ret: Control = $Interactable/Control
@onready var hold_point: Node3D = $HoldPoint

@export var current_hand_color: Color

var currently_wall_running: bool = false
var currently_can_double_jump: bool = false

var held_object: RigidBody3D = null

const SPEED: float = 10.0
const JUMP_VELOCITY: float = 10.0
const gravity: float = 20.0

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	# Always set up hand color syncing, even if not authority
	multiplayer.peer_connected.connect(sync_hand_color)

	# Only authority sets up their own camera and idle animations
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera.current = true

		anim_player_hands.play("IdleHands")

func _unhandled_input(event):
	# Only authority can control the character
	if is_multiplayer_authority():
		# Camera movement
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x *.005)
			camera.rotate_x(-event.relative.y *.005)
			camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

		# Interact events
		if Input.is_action_just_pressed("interact"):
			if raycast.is_colliding():
				var hit_object: Object = raycast.get_collider()
				if hit_object.is_in_group("ball"):
					var new_color: Color = Color(randf(), randf(), randf())
					hit_object.clicked(new_color)
					rpc("update_hand_color",new_color)

		# Click events
		if Input.is_action_just_pressed("click"):
			if raycast.is_colliding() and held_object == null:
				var hit_object: RigidBody3D = raycast.get_collider()
				if hit_object.is_in_group("ball"):
					held_object = raycast.get_collider()
					print("started holding " + held_object.to_string())
		elif Input.is_action_just_released("click"):
			if held_object != null:
				print("stopped holding " + held_object.to_string())
				held_object = null

		# Hand animation
		if Input.is_action_just_pressed("look_hands"):
			anim_player_hands.play("LookHands")
		if Input.is_action_just_released("look_hands"):
			anim_player_hands.play("IdleHands")

func _physics_process(delta):
	# Only authority can control the character
	if is_multiplayer_authority():
		# Hud Updates based on looking
		if raycast.is_colliding() and not interact_ret.is_visible():
			interact_ret.show()
		if not raycast.is_colliding() and interact_ret.is_visible():
			interact_ret.hide()

		# Held object movement
		if held_object != null:
			held_object.set_global_position(hold_point.get_global_position())

		# Gravity with wall running
		if not is_on_floor() and not currently_wall_running:
			velocity.y -= gravity * delta
		elif not is_on_floor() and currently_wall_running:
			velocity.y = 0
		else:
			currently_wall_running = false

		# Handle jump and double jumping
		if Input.is_action_just_pressed("ui_accept") and (is_on_floor() or currently_wall_running):
			velocity.y = JUMP_VELOCITY
			currently_wall_running = false
			currently_can_double_jump = true
		elif Input.is_action_just_pressed("ui_accept") and not (is_on_floor() or currently_wall_running) and currently_can_double_jump:
			velocity.y = JUMP_VELOCITY
			currently_can_double_jump = false

		# Get the input direction and handle the movement/deceleration
		var input_dir: Vector2 = Input.get_vector("left", "right", "up", "down")
		var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

		move_and_slide()

# Attach to wall
func _on_collision_body_shape_entered(_body_rid, body, _body_shape_index, _local_shape_index):
	if not is_on_floor() and body.is_in_group("wall"):
		currently_wall_running = true

# Detach from wall
func _on_collision_body_shape_exited(_body_rid, body, _body_shape_index, _local_shape_index):
	if currently_wall_running == true and body.is_in_group("wall"):
		currently_wall_running = false
		currently_can_double_jump = true

@rpc("any_peer", "call_local")
func update_hand_color(new_color: Color):
	current_hand_color = new_color
	var mesh_left_hand: MeshInstance3D = left_hand.get_child(0)
	var mesh_right_hand: MeshInstance3D = right_hand.get_child(0)
	var left_material: Material = mesh_left_hand.get_surface_override_material(0)
	var right_material: Material = mesh_right_hand.get_surface_override_material(0)
	left_material.albedo_color = current_hand_color
	right_material.albedo_color = current_hand_color
	mesh_left_hand.set_surface_override_material(0, left_material)
	mesh_right_hand.set_surface_override_material(0, right_material)

func sync_hand_color(_peer_id):
	call_deferred("load_hand_color")

func load_hand_color():
	rpc("update_hand_color", current_hand_color)

