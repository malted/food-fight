extends CharacterBody3D

@export var camera: Camera3D
@export var hand_item_anchor: Node3D

var mouse_input: Vector2
const SENSITIVITY = .001

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

const RAY_LENGTH = 1000 # For forward raycasting
const FOOD_COLLISION_LAYER = 10
@export var REACH_DISTANCE = 100
var held_item: RigidBody3D

const FOOD_DROP_FORCE = 100
const FOOD_THROW_FORCE = 1000

#region UI
@export var crosshair_rect: ColorRect
#endregion

var food_container: Node3D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_use_accumulated_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	food_container = get_owner().get_node("Room/Food")
	
func _process(delta):
	camera.rotate_x(-mouse_input.y * SENSITIVITY)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))
	camera.orthonormalize()
	
	rotate_y(-mouse_input.x * SENSITIVITY)
	orthonormalize()
	
	mouse_input = Vector2.ZERO

func _physics_process(delta):
	#region Movement.
	if not is_on_floor():
		velocity.y -= gravity * delta # Add the gravity

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	#endregion
	#region Raycasting
	var space_state = get_world_3d().direct_space_state
	var mousepos = get_viewport().get_mouse_position()

	var origin = camera.project_ray_origin(mousepos)
	var end = origin + camera.project_ray_normal(mousepos) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end, layer_to_mask(FOOD_COLLISION_LAYER))
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	if result && result.collider:
		var distance = position.distance_to(result.position)
		if distance <= REACH_DISTANCE && result.collider.get_collision_layer_value(FOOD_COLLISION_LAYER):
			crosshair_rect.set_color(Color(0, 1, 0))
			if Input.is_action_just_pressed("click"):
				if held_item: throw_item(FOOD_DROP_FORCE)

					
				held_item = result.collider
				pick_up_item()
		else: reset_crosshair()
	else:
		reset_crosshair()
		if Input.is_action_just_pressed("click"):
			if held_item:
				throw_item(FOOD_THROW_FORCE)
			
	#endregion

func _unhandled_input(event):
	if event is InputEventMouseMotion && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input += event.relative

	if event.is_action_pressed("click") && Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
	food_container.add_child(held_item)
	held_item.transform = held_item_global_transform
	held_item.set_process_mode(ProcessMode.PROCESS_MODE_INHERIT)

	var rng = RandomNumberGenerator.new()
	var random_unit = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
	
	var throw_direction = (Vector3.FORWARD + Vector3.UP * camera.global_rotation.x).rotated(Vector3.UP, rotation.y)
	held_item.apply_force(
		throw_direction * force,
		random_unit * rng.randf() * 0.1
	)
	
	held_item = null
#endregion
#region UI helpers
func reset_crosshair(): crosshair_rect.set_color(Color(1, 1, 1))
#endregion
#region Utils
func layer_to_mask(layer):
	return pow(2, layer - 1)
#endregion
