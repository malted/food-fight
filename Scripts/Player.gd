extends CharacterBody3D

@export var camera: Camera3D
@export var hand_item_anchor: Node3D

var mouse_input: Vector2
const SENSITIVITY = .001

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

const FOOD_COLLISION_LAYER = 10
@export var REACH_DISTANCE = 5
var held_item: RigidBody3D

const FOOD_DROP_FORCE = 2
const FOOD_THROW_FORCE = 20

#region UI
@export var crosshair_rect: ColorRect
@export var crosshair_colour_neutral = Color(1, 1, 1)
@export var crosshair_colour_food = Color(0, 0, 1)
#endregion

#region Multiplayer
var player_id: int
#endregion

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	if not player_id: player_id = multiplayer.get_unique_id()
	var myself = player_id == multiplayer.get_unique_id()
	set_multiplayer_authority(player_id)
	MultiplayerManager.p("[Player::_ready] player_id: %s, MultiplayerManager.my_player: %s\tMultiplayerManager.my_player[\"peer\"].get_unique_id(): %s\tmultiplayer.get_unique_id(): %s" % [player_id, MultiplayerManager.my_player, MultiplayerManager.my_player["peer"].get_unique_id(), multiplayer.get_unique_id()])

	Input.set_use_accumulated_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if myself:
		camera.current = true

	set_process(myself)
	set_physics_process(myself)
	
func _process(delta):
	#region Looking
	camera.rotate_x(-mouse_input.y * SENSITIVITY)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))
	camera.orthonormalize()
	
	rotate_y(-mouse_input.x * SENSITIVITY)
	orthonormalize()
	
	mouse_input = Vector2.ZERO
	#endregion
	#region Movement
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	#endregion

func _physics_process(delta):
	#region Movement.
	if not is_on_floor():
		velocity.y -= gravity * delta # Add the gravity

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
	#endregion
			
	#region Raycasting
	var looking_at_food = food_raycast()
	if looking_at_food:
		crosshair_rect.set_color(crosshair_colour_food)
		if Input.is_action_just_pressed("click"):
			if held_item: throw_item(FOOD_DROP_FORCE)
			held_item = looking_at_food.collider
			pick_up_item()
	else:
		reset_crosshair()
		if Input.is_action_just_pressed("click"):
			if held_item: throw_item(FOOD_THROW_FORCE)
	
	if held_item:
		#region Render path
		var start_pos = hand_item_anchor.global_position
		var start_vel = (look_direction() * FOOD_THROW_FORCE).length()

		#endregion
	#endregion

func _unhandled_input(event):
	if event is InputEventMouseMotion && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input += event.relative

	if event.is_action_pressed("click") && Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func food_raycast():
	var space_state = get_world_3d().direct_space_state
	var mousepos = get_viewport().get_mouse_position()

	var origin = camera.project_ray_origin(mousepos)
	var end = origin + camera.project_ray_normal(mousepos) * REACH_DISTANCE
	var query = PhysicsRayQueryParameters3D.create(origin, end, layer_to_mask(FOOD_COLLISION_LAYER))
	query.collide_with_areas = true

	return space_state.intersect_ray(query)

#region Picking up & throwing items
func pick_up_item():
	if held_item.get_parent():
		held_item.get_parent().remove_child(held_item)
		hand_item_anchor.add_child(held_item)
		held_item.set_process_mode(ProcessMode.PROCESS_MODE_DISABLED)
		held_item.position = Vector3.ZERO
		
func throw_item(force: int):
	var held_item_global_transform = held_item.global_transform
	hand_item_anchor.remove_child(held_item)
	get_tree().get_root().add_child(held_item)
	held_item.transform = held_item_global_transform
	held_item.set_process_mode(ProcessMode.PROCESS_MODE_INHERIT)

	# Apply a random rotation to the thrown item to add variety
	var rng = RandomNumberGenerator.new()
	var random_unit = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
	var throw_rotation = random_unit * rng.randf() * 0.1
	
	held_item.apply_impulse(look_direction() * force, throw_rotation)
	
	held_item = null
#endregion
#region UI helpers
func reset_crosshair(): crosshair_rect.set_color(crosshair_colour_neutral)
#endregion
#region Utils
func look_direction():
	return (Vector3.FORWARD + Vector3.UP * camera.global_rotation.x).rotated(Vector3.UP, rotation.y)
	
func layer_to_mask(layer):
	return pow(2, layer - 1)
#endregion

#region Integrate forces
#func _integrate_forces(state : PhysicsDirectBodyState3D) -> void:
	#var trajectory = []
	#
	#var _apply_constant_forces : Callable = func () -> void:
		## This function applies gravity, damping etc to the ball. Essentially a simplified version of what is in https://github.com/godotengine/godot/blob/master/servers/physics_2d/godot_body_2d.cpp
		#state.linear_velocity *= (1.0 - state.step * state.total_linear_damp) # Damping is applied first in the physics engine
		#state.linear_velocity += state.total_gravity * state.step # + state.get_constant_force()
		## TODO: Apply angular damping and torque
	#
	## if this is a trajectory indicator control the motion directly so we can do multiple cycles
	#while true: # loop until the ball is removed or the loop is exited manually
		#_apply_constant_forces.call()
		#var col: KinematicCollision3D = move_and_collide(state.linear_velocity * state.step, true) # just test for a collision, don't move the ball
		## Alter the trajectory only if the ball collides with something
		#if col:
			## instead of manually calculating the bounce (which is complicated), let the physics engine do it by moving the ball to the collision point and then letting the engine cycle
			#state.transform = Transform3D(Basis.from_euler(rotation), position)
			#break
		#else:
			#move_and_collide(state.linear_velocity * state.step) # actually move the ball
#
		#trajectory.append(position) # record the ball's position for the trajectory indicator
#
		#return
#endregion
