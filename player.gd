extends CharacterBody3D

@export var mouse_sensitivity : float = 0.001
@export var controller_sensitivity : float = 0.05

@export var jump_velocity : float = 6.0
@export var auto_bhop := true

# Ground movement settings
@export var run_speed : float = 8
@export var walk_speed : float = 6
@export var ground_accel : float = 14.0
@export var ground_decel : float = 10.0
@export var ground_friction : float = 6.0

# Air movement settings
@export var air_cap := 0.85 # Can surf steeper ramps if this is higher, makes it easier to stick and bhop
@export var air_accel := 800.0
@export var air_move_speed := 500.0

var wish_dir := Vector3.ZERO

const VIEW_MODEL_LAYER = 9
const WORLD_MODEL_LAYER = 2

func get_move_speed():
	return run_speed

func _ready() -> void:
	# Hide WorldModel from camera
	update_view_and_world_model_masks()

func update_view_and_world_model_masks() -> void:
	for child in %WorldModel.find_children("*", "VisualInstance3D", true, false):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(WORLD_MODEL_LAYER, true)
	for child in %ViewModel.find_children("*", "VisualInstance3D", true, false):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(VIEW_MODEL_LAYER, true)
		if child is GeometryInstance3D:
			child.cast_shadow = false
	%Camera3D.set_cull_mask_value(WORLD_MODEL_LAYER, false)
	#%ThirdPersonCamera3D.set_cull_mask_value(VIEW_MODEL_LAYER, false)

func _unhandled_input(event: InputEvent) -> void:
	# Toggle mouse look when pressing ESC
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Handle mouse look
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		%Camera3D.rotation.x = clamp(%Camera3D.rotation.x - event.relative.y * mouse_sensitivity, deg_to_rad(-90), deg_to_rad(90))
		

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("moveleft", "moveright", "forward", "back")
	wish_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		# Handle jump
		if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
			velocity.y = jump_velocity
		_handle_ground_physics(delta)
	else:
			_handle_air_physics(delta)
	
	move_and_slide()

func _process(delta: float) -> void:
	_handle_look(delta)

func _handle_air_physics(delta: float) -> void:
	# Add the gravity 
	velocity += get_gravity() * delta
	
	var cur_speed_in_wish_dir = velocity.dot(wish_dir)
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta # Usually is adding this one.
		accel_speed = min(accel_speed, add_speed_till_cap) # Works ok without this but sticking to the recipe
		velocity += accel_speed * wish_dir
	
	if is_on_wall():
		# The floating mode is much better and less jittery for surf
		# This bit of code is tricky. Will toggle floating mode in air
		# is_on_floor() never triggers in floating mode, and instead is_on_wall() does.
		if is_surface_too_steep(get_wall_normal()):
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clip_velocity(get_wall_normal(), 1, delta)

func _handle_ground_physics(delta: float) -> void:
	var cur_speed_in_wish_dir = velocity.dot(wish_dir)
	var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * delta * get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		velocity += accel_speed * wish_dir
	
	# Apply friction
	var control = max(velocity.length(), ground_decel)
	var drop = control * ground_friction * delta
	var new_speed = max(velocity.length() - drop, 0.0)
	if velocity.length() > 0:
		new_speed /= velocity.length()
	velocity *= new_speed

# Handle any non-mouse look
func _handle_look(delta: float) -> void:
		var target_look = Input.get_vector("left", "right", "lookup", "lookdown").normalized()
		rotate_y(-target_look.x * controller_sensitivity)
		%Camera3D.rotation.x = clamp(%Camera3D.rotation.x - target_look.y * controller_sensitivity, deg_to_rad(-90), deg_to_rad(90))

func clip_velocity(normal: Vector3, overbounce : float, _delta : float) -> void:
	# When strafing into wall, + gravity, velocity will be pointing much in the opposite direction of the normal
	# So with this code, we will back up and off of the wall, cancelling out our strafe + gravity, allowing surf.
	var backoff := velocity.dot(normal) * overbounce
	# Not in original recipe. Maybe because of the ordering of the loop, in original source it
	# shouldn't be the case that velocity can be away away from plane while also colliding.
	# Without this, it's possible to get stuck in ceilings
	if backoff >= 0: return
	
	var change := normal * backoff
	velocity -= change
	
	# Second iteration to make sure not still moving through plane
	# Not sure why this is necessary but it was in the original recipe so keeping it.
	var adjust := velocity.dot(normal)
	if adjust < 0.0:
		velocity -= normal * adjust

func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > floor_max_angle
