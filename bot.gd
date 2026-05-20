extends CharacterBody3D

@export var max_speed: float = 15.0
@export var acceleration: float = 5.0
@export var steering_speed: float = 5.0
@export var target_path_follow: PathFollow3D

# --- Avoidance Settings ---
@export var avoidance_radius: float = 3
@export var avoidance_weight: float = 1

# --- Wall Avoidance Settings ---
@export var wall_avoidance_length: float = 10 # How far to look for walls
@export var wall_avoidance_weight: float = 9 # How strongly to push away from walls

var current_speed: float = 0.0

func _physics_process(delta: float) -> void:
	if not target_path_follow:
		return

	# 1. Move the "Rabbit" forward along the path
	target_path_follow.progress += max_speed * delta
	
	# 2. Find direction to the rabbit (ignoring height differences)
	var target_pos = target_path_follow.global_position
	var direction_to_rabbit = Vector3(target_pos.x - global_position.x, 0, target_pos.z - global_position.z)
	
	if direction_to_rabbit.length_squared() > 0.01:
		direction_to_rabbit = direction_to_rabbit.normalized()
	else:
		direction_to_rabbit = Vector3.ZERO
	
	# 3. Calculate Avoidance Vector
	var avoidance_vector = Vector3.ZERO
	
	# --- A) Avoid Players and Bots ---
	var bodies_to_avoid = get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("Bot")
	for body in bodies_to_avoid:
		if body != self and body is Node3D:
			# Flatten Y axis for distance checks so it doesn't get messed up by ramps/jumping
			var pos_a = Vector3(global_position.x, 0, global_position.z)
			var pos_b = Vector3(body.global_position.x, 0, body.global_position.z)
			var dist = pos_a.distance_to(pos_b)
			
			if dist < avoidance_radius and dist > 0.01:
				var push_dir = (pos_a - pos_b).normalized()
				var push_strength = 1.0 - (dist / avoidance_radius)
				avoidance_vector += push_dir * push_strength * avoidance_weight
				
	# --- B) Avoid Walls (Using Raycasts) ---
	var space_state = get_world_3d().direct_space_state
	
	# Calculate bot's forward and right directions mathematically based on rotation
	var bot_forward = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	var bot_right = Vector3.RIGHT.rotated(Vector3.UP, rotation.y)
	
	# Create 3 rays: Straight ahead, Diagonal Right, Diagonal Left
	var ray_directions = [
		bot_forward,
		(bot_forward + bot_right * 0.8).normalized(),
		(bot_forward - bot_right * 0.8).normalized()
	]
	
	# Start rays slightly above the ground (0.5m) to avoid accidentally hitting the floor
	var ray_start_pos = global_position + Vector3(0, 0.5, 0) 
	
	for ray_dir in ray_directions:
		var ray_end_pos = ray_start_pos + (ray_dir * wall_avoidance_length)
		var query = PhysicsRayQueryParameters3D.create(ray_start_pos, ray_end_pos)
		query.exclude = [self.get_rid()] # Make sure the bot doesn't hit itself
		
		var result = space_state.intersect_ray(query)
		if result:
			# We hit a wall! Calculate how close we are
			var dist = ray_start_pos.distance_to(result.position)
			var push_strength = 1.0 - (dist / wall_avoidance_length)
			
			# result.normal tells us which way the wall is facing. Steer away from it!
			var push_dir = Vector3(result.normal.x, 0, result.normal.z).normalized()
			avoidance_vector += push_dir * push_strength * wall_avoidance_weight

	# 4. Blend the Rabbit direction and Avoidance direction together
	var final_direction = (direction_to_rabbit + avoidance_vector)
	final_direction.y = 0.0 # Keep it completely flat
	
	# 5. Rotate the bot to look at the final blended direction smoothly
	if final_direction.length_squared() > 0.001:
		final_direction = final_direction.normalized()
		var look_target = atan2(-final_direction.x, -final_direction.z)
		rotation.y = lerp_angle(rotation.y, look_target, steering_speed * delta)

	# 6. Apply Acceleration smoothly
	current_speed = move_toward(current_speed, max_speed, acceleration * delta)

	# 7. Move Forward 
	# (We calculate this purely from rotation.y to prevent the Transform Scale error!)
	var move_dir = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	velocity = move_dir * current_speed
	
	# Add gravity if needed
	if not is_on_floor():
		velocity.y -= 20 * delta
		
	move_and_slide()
