extends CharacterBody3D

# ─── Parámetros exportables ───────────────────────────────────────────────────
@export_group("Velocidad")
@export var velocidad_maxima     : float = 20.0   # m/s hacia adelante
@export var velocidad_reversa    : float = 5.0    # m/s hacia atrás
@export var aceleracion          : float = 9.0    # qué tan rápido llega a la velocidad máxima
@export var frenado              : float = 16.0   # fuerza del freno (tecla de retroceder en marcha)
@export var friccion             : float = 7.0    # desaceleración al soltar el acelerador

@export_group("Manejo")
@export var velocidad_giro       : float = 1.4    # radianes/seg a velocidad máxima
@export var giro_minimo          : float = 0.4    # giro mínimo (a baja velocidad, gira más)
@export var agarre               : float = 5.0    # qué tan rápido el kart alinea su velocidad al giro

@export_group("Física")
@export var gravedad             : float = 20.0   # gravedad personalizada
@export var velocidad_caida_max  : float = 40.0   # límite de velocidad vertical

# ─── Variables internas ───────────────────────────────────────────────────────
var speed        : float = 0.0   # velocidad longitudinal actual (+ adelante, - reversa)
var turn_input   : float = 0.0

func _physics_process(delta: float) -> void:
	_aplicar_gravedad(delta)
	_manejar_movimiento(delta)
	_manejar_giro(delta)
	_aplicar_agarre()
	move_and_slide()

# ── Gravedad ──────────────────────────────────────────────────────────────────
func _aplicar_gravedad(delta: float) -> void:
	if not is_on_floor():
		velocity.y = max(velocity.y - gravedad * delta, -velocidad_caida_max)
	else:
		velocity.y = -0.5  # pequeño empuje hacia el suelo para mantener contacto

# ── Movimiento adelante / atrás ───────────────────────────────────────────────
func _manejar_movimiento(delta: float) -> void:
	# Si W avanza y S retrocede en tu Input Map, intercambia los nombres aquí:
	var acelerando  = Input.is_action_pressed("Avanzar")
	var frenando    = Input.is_action_pressed("Retroceder")
	var en_reversa  = speed < -0.1   # el kart ya va hacia atrás

	if acelerando:
		if en_reversa:
			# Frenamos primero antes de avanzar
			speed = move_toward(speed, 0.0, frenado * delta)
		else:
			speed = move_toward(speed, velocidad_maxima, aceleracion * delta)

	elif frenando:
		if speed > 0.1:
			# Frenamos si vamos hacia adelante
			speed = move_toward(speed, 0.0, frenado * delta)
		else:
			# Engranamos la reversa
			speed = move_toward(speed, -velocidad_reversa, aceleracion * delta)

	else:
		# Sin input: fricción natural
		speed = move_toward(speed, 0.0, friccion * delta)

	# Propagamos la velocidad en la dirección del kart
	var forward = -transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed

# ── Giro (solo cuando hay velocidad) ─────────────────────────────────────────
func _manejar_giro(delta: float) -> void:
	turn_input = Input.get_axis("Izquierda", "Derecha")  # -1 izq, +1 der

	if abs(speed) < 0.5:
		return  # no girar si el kart está casi parado

	# A baja velocidad el kart gira más (como en Mario Kart)
	# A alta velocidad gira menos (más difícil de manejar en curvas rápidas)
	var factor_velocidad = clamp(abs(speed) / velocidad_maxima, giro_minimo, 1.0)

	# En reversa, el giro se invierte
	var direccion_giro = sign(speed)

	var angulo = turn_input * velocidad_giro * factor_velocidad * direccion_giro * delta
	rotate_y(-angulo)

# ── Agarre lateral (evita que el kart se deslice de lado) ────────────────────
func _aplicar_agarre() -> void:
	var right_dir = transform.basis.x
	# Calculamos cuánta velocidad lateral tiene el kart
	var vel_lateral = velocity.dot(right_dir)
	# La cancelamos progresivamente (agarre = 1.0 es perfecto, 0.0 es hielo)
	var factor_agarre = clamp(agarre / 10.0, 0.0, 1.0)
	velocity -= right_dir * vel_lateral * factor_agarre
