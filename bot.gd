extends CharacterBody3D

@export var max_speed: float = 15.0
@export var acceleration: float = 5.0
@export var steering_speed: float = 5.0
@export var target_path_follow: PathFollow3D

# --- Wall Avoidance Settings ---
@export var wall_avoidance_length: float = 5
@export var wall_avoidance_weight: float = 3
@export var wall_avoidance_smoothing: float = 5.0

# --- Path Following Settings ---
@export var lookahead_distance: float = 4.0
# Cuántos metros adelante poner el conejo

## Modf
@onready var hud = get_tree().current_scene.get_node_or_null("CanvasLayer/Hud")

var vueltas_completadas = 0
var ultimo_progress = 0.0
var puede_contar_vuelta = false

##

var current_speed: float = 0.0
var smooth_avoidance: Vector3 = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not target_path_follow:
		return

	## modif

	# REQUISITO INTERFAZ:
	# Los bots se quedan quietos durante el 3, 2, 1
	if hud and not hud.carrera_activa:
		current_speed = 0.0
		velocity = Vector3.ZERO

		if not is_on_floor():
			velocity.y -= 20 * delta

		move_and_slide()
		return
		# Detiene la lógica de la IA momentáneamente

	### Encuentra el punto del path más cercano al bot
	var path = target_path_follow.get_parent()
	# El nodo Path3D

	var closest_progress = _get_closest_progress(path)

	# Coloca el conejo un poco adelante del bot en el path
	target_path_follow.progress = closest_progress + lookahead_distance

	var target_pos = target_path_follow.global_position

	var direction_to_rabbit = Vector3(
		target_pos.x - global_position.x,
		0,
		target_pos.z - global_position.z
	)

	if direction_to_rabbit.length_squared() > 0.01:
		direction_to_rabbit = direction_to_rabbit.normalized()
	else:
		direction_to_rabbit = Vector3.ZERO

	var space_state = get_world_3d().direct_space_state

	var bot_forward = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	var bot_right = Vector3.RIGHT.rotated(Vector3.UP, rotation.y)

	var ray_directions = [
		bot_forward,
		(bot_forward + bot_right * 0.8).normalized(),
		(bot_forward - bot_right * 0.8).normalized()
	]

	var ray_start_pos = global_position + Vector3(0, 0.5, 0)

	var raw_avoidance = Vector3.ZERO

	for ray_dir in ray_directions:
		var ray_end_pos = ray_start_pos + (ray_dir * wall_avoidance_length)

		var query = PhysicsRayQueryParameters3D.create(
			ray_start_pos,
			ray_end_pos
		)

		var exclude_rids = [self.get_rid()]

		for bot in get_tree().get_nodes_in_group("Bot"):
			if bot != self and bot is CollisionObject3D:
				exclude_rids.append(bot.get_rid())

		query.exclude = exclude_rids

		var result = space_state.intersect_ray(query)

		if result:
			var dist = ray_start_pos.distance_to(result.position)

			var push_strength = 1.0 - (dist / wall_avoidance_length)

			var push_dir = Vector3(
				result.normal.x,
				0,
				result.normal.z
			).normalized()

			raw_avoidance += push_dir * push_strength * wall_avoidance_weight

	smooth_avoidance = smooth_avoidance.lerp(
		raw_avoidance,
		wall_avoidance_smoothing * delta
	)

	var final_direction = direction_to_rabbit + smooth_avoidance
	final_direction.y = 0.0

	if final_direction.length_squared() > 0.001:
		final_direction = final_direction.normalized()

	var look_target = atan2(-final_direction.x, -final_direction.z)

	rotation.y = lerp_angle(
		rotation.y,
		look_target,
		steering_speed * delta
	)

	current_speed = move_toward(
		current_speed,
		max_speed,
		acceleration * delta
	)

	var move_dir = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)

	velocity = move_dir * current_speed

	if not is_on_floor():
		velocity.y -= 20 * delta

	move_and_slide()


# Calcula el progress en el path más cercano
# a la posición actual del bot
func _get_closest_progress(path: Path3D) -> float:
	var curve = path.curve

	var closest_progress: float = 0.0
	var closest_dist: float = INF

	var total_length = curve.get_baked_length()

	# Samplea el path cada ~1 metro
	# para encontrar el punto más cercano
	var steps = int(total_length)

	for i in range(steps + 1):
		var progress = (
			(float(i) / float(steps)) * total_length
		)

		var point = (
			path.global_transform * curve.sample_baked(progress)
		)

		var dist = Vector3(
			global_position.x,
			0,
			global_position.z
		).distance_to(
			Vector3(point.x, 0, point.z)
		)

		if dist < closest_dist:
			closest_dist = dist
			closest_progress = progress

	return closest_progress


func get_progress_on_path(path: Path3D) -> float:
	return _get_closest_progress(path)


func _on_checkpoint_body_entered(body: Node3D) -> void:
	if body == self:
		puede_contar_vuelta = true


func _on_meta_area_body_entered(body: Node3D) -> void:
	if body == self and puede_contar_vuelta:
		puede_contar_vuelta = false
		vueltas_completadas += 1
