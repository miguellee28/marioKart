extends CharacterBody3D


# ─── Parámetros exportables ──────────────────────────────────────────────────
@export_group("Velocidad")

@export var velocidad_maxima: float = 20.0
# m/s hacia adelante

@export var velocidad_reversa: float = 5.0
# m/s hacia atrás

@export var aceleracion: float = 9.0
# qué tan rápido llega a la velocidad máxima

@export var frenado: float = 16.0
# fuerza del freno (tecla de retroceder en marcha)

@export var friccion: float = 7.0
# desaceleración al soltar el acelerador


@export_group("Manejo")

@export var velocidad_giro: float = 1.4
# radianes/seg a velocidad máxima

@export var giro_minimo: float = 0.4
# giro mínimo (a baja velocidad, gira más)

@export var agarre: float = 5.0
# qué tan rápido el kart alinea su velocidad al giro


@export_group("Física")

@export var gravedad: float = 20.0
# gravedad personalizada

@export var velocidad_caida_max: float = 40.0
# límite de velocidad vertical


## modf

@export var progreso_inicial: float = 0.0

@onready var hud = get_tree().current_scene.get_node_or_null(
	"CanvasLayer/Hud"
)
@onready var pause_menu = $"../CanvasLayer/Pause"
# Ajusta la ruta si es necesario
var puede_contar_vuelta = false
var vueltas_completadas = 0

##


# ─── Variables internas ───────────────────────────────────────────────────────

var speed: float = 0.0
# velocidad longitudinal actual (+ adelante, - reversa)

var turn_input: float = 0.0

func _input(event):

	if event.is_action_pressed("pause"):
		toggle_pause()
		
func _physics_process(delta: float) -> void:

	_aplicar_gravedad(delta)
	## Orig

	# REQUISITO INTERFAZ:
	# Si el HUD existe y la carrera NO ha empezado,
	# congelamos el movimiento
	if hud and not hud.carrera_activa:

		speed = 0.0

		velocity.x = 0.0
		velocity.z = 0.0

		move_and_slide()

		return
		# Corta la ejecución aquí para que no detecte teclas

	## Orig

	_manejar_movimiento(delta)
	_manejar_giro(delta)
	_aplicar_agarre()

	move_and_slide()

	##

	# REQUISITO INTERFAZ:
	# Enviar la velocidad actual (speed) calculada al HUD
	if hud:
		hud.mostrar_velocidad(speed)


# ── Gravedad ──────────────────────────────────────────────────────────────────

func _aplicar_gravedad(delta: float) -> void:

	if not is_on_floor():

		velocity.y = max(
			velocity.y - gravedad * delta,
			-velocidad_caida_max
		)

	else:
		# pequeño empuje hacia el suelo
		# para mantener contacto
		velocity.y = -0.5


# ── Movimiento adelante / atrás ───────────────────────────────────────────────

func _manejar_movimiento(delta: float) -> void:

	# Si W avanza y S retrocede en tu Input Map,
	# intercambia los nombres aquí:

	var acelerando = Input.is_action_pressed("Avanzar")
	var frenando = Input.is_action_pressed("Retroceder")

	var en_reversa = speed < -0.1
	# el kart ya va hacia atrás

	if acelerando:

		if en_reversa:

			# Frenamos primero antes de avanzar
			speed = move_toward(
				speed,
				0.0,
				frenado * delta
			)

		else:

			speed = move_toward(
				speed,
				velocidad_maxima,
				aceleracion * delta
			)

	elif frenando:

		if speed > 0.1:

			# Frenamos si vamos hacia adelante
			speed = move_toward(
				speed,
				0.0,
				frenado * delta
			)

		else:

			# Engranamos la reversa
			speed = move_toward(
				speed,
				-velocidad_reversa,
				aceleracion * delta
			)

	else:

		# Sin input: fricción natural
		speed = move_toward(
			speed,
			0.0,
			friccion * delta
		)

	# Propagamos la velocidad
	# en la dirección del kart

	var forward = -transform.basis.z

	velocity.x = forward.x * speed
	velocity.z = forward.z * speed


# ── Giro (solo cuando hay velocidad) ─────────────────────────────────────────

func _manejar_giro(delta: float) -> void:

	turn_input = Input.get_axis(
		"Izquierda",
		"Derecha"
	)
	# -1 izq, +1 der

	if abs(speed) < 0.5:
		return
		# no girar si el kart está casi parado

	# A baja velocidad el kart gira más
	# (como en Mario Kart)

	# A alta velocidad gira menos
	# (más difícil de manejar en curvas rápidas)

	var factor_velocidad = clamp(
		abs(speed) / velocidad_maxima,
		giro_minimo,
		1.0
	)

	# En reversa, el giro se invierte
	var direccion_giro = sign(speed)

	var angulo = (
		turn_input
		* velocidad_giro
		* factor_velocidad
		* direccion_giro
		* delta
	)

	rotate_y(-angulo)


# ── Agarre lateral ────────────────────────────────────────────────────────────
# Evita que el kart se deslice de lado

func _aplicar_agarre() -> void:

	var right_dir = transform.basis.x

	# Calculamos cuánta velocidad lateral tiene el kart
	var vel_lateral = velocity.dot(right_dir)

	# La cancelamos progresivamente
	# (agarre = 1.0 es perfecto, 0.0 es hielo)

	var factor_agarre = clamp(
		agarre / 10.0,
		0.0,
		1.0
	)

	velocity -= right_dir * vel_lateral * factor_agarre


func _on_meta_area_body_entered(body: Node3D) -> void:

	if body == self and puede_contar_vuelta:

		puede_contar_vuelta = false
		vueltas_completadas += 1

		var hud_nodo = get_tree().current_scene.get_node_or_null(
			"CanvasLayer/Hud"
		)

		if hud_nodo:

			var nueva_vuelta = (
				hud_nodo.vueltas_jugador + 1
			)

			hud_nodo.actualizar_vuelta(nueva_vuelta)


## Agregando mod

func _on_checkpoint_body_entered(body: Node3D) -> void:

	if body == self:
		puede_contar_vuelta = true


func get_progress_on_path(path: Path3D) -> float:

	var curve = path.curve

	var closest_progress: float = 0.0
	var closest_dist: float = INF

	var total_length = curve.get_baked_length()

	var steps = int(total_length)

	for i in range(steps + 1):

		var progress = (
			(float(i) / float(steps))
			* total_length
		)

		var point = (
			path.global_transform
			* curve.sample_baked(progress)
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
	
func toggle_pause():

	get_tree().paused = !get_tree().paused

	if get_tree().paused:

		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		pause_menu.visible = true

	else:

		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		pause_menu.visible = false
