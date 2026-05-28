extends Control

# Referencias a los textos de la interfaz
@onready var lap_label = $Lap 
@onready var timer_label = $MarginContainer/Timer
@onready var speed_label = $MarginContainer/Speed
@onready var posicion_label = $MarginContainer/Posicion
@onready var countdown_label = $MarginContainer/Countdown
@onready var countdown_timer = $CountdownTimer

# Variables de control de carrera
var tiempo_transcurrido: float = 0.0
var carrera_activa: bool = false
var cuenta_atras: int = 3

# Datos del jugador
var vueltas_jugador: int = 0
var max_vueltas: int = 3

# Control de actualización de posiciones
var tiempo_actualizacion_posiciones: float = 0.0


func _ready():

	# Configuración inicial clásica de Mario Kart Wii
	lap_label.text = "Lap 1/3"
	posicion_label.text = "6th"
	speed_label.text = "00.0\nkm/h"

	# Iniciar cuenta regresiva
	countdown_label.text = str(cuenta_atras)

	countdown_timer.wait_time = 1.0
	countdown_timer.start()


func _process(delta: float) -> void:

	if carrera_activa:
		tiempo_transcurrido += delta
		_actualizar_cronometro()

	# Actualizar posiciones solo 5 veces por segundo
	tiempo_actualizacion_posiciones += delta

	if tiempo_actualizacion_posiciones >= 0.2:
		tiempo_actualizacion_posiciones = 0.0
		_calcular_posiciones_carrera()


# Actualiza el formato del tiempo a 00:00.000
func _actualizar_cronometro() -> void:

	var minutos = int(tiempo_transcurrido) / 60
	var segundos = int(tiempo_transcurrido) % 60

	var milisegundos = int(
		(tiempo_transcurrido - int(tiempo_transcurrido)) * 1000
	)

	timer_label.text = "%02d:%02d.%03d" % [
		minutos,
		segundos,
		milisegundos
	]


# Recibe la velocidad del script de Mario y la muestra
func mostrar_velocidad(vel_metros_por_segundo: float) -> void:

	# Convertimos m/s a km/h multiplicando por 3.6
	var kmh = abs(vel_metros_por_segundo) * 3.6

	speed_label.text = "%04.1f\nkm/h" % kmh


# Cambia el texto de las vueltas
func actualizar_vuelta(nueva_vuelta: int) -> void:

	vueltas_jugador = clamp(
		nueva_vuelta,
		0,
		max_vueltas
	)

	var vuelta_visual = min(
		vueltas_jugador + 1,
		max_vueltas
	)

	lap_label.text = "Lap %d/%d" % [
		vuelta_visual,
		max_vueltas
	]


# Lógica del temporizador segundo a segundo
func _on_countdown_timer_timeout() -> void:

	cuenta_atras -= 1

	if cuenta_atras > 0:
		countdown_label.text = str(cuenta_atras)

	elif cuenta_atras == 0:
		carrera_activa = true

	else:
		countdown_label.visible = false
		countdown_timer.stop()


# Sistema dinámico de posiciones
# basado en el progreso del circuito
func _calcular_posiciones_carrera() -> void:

	var player = get_tree().get_first_node_in_group("Player")
	var bots = get_tree().get_nodes_in_group("Bot")

	if not player:
		return

	if bots.size() == 0:
		return

	var path = get_tree().current_scene.get_node("RnkingPath")

	var largo_pista = path.curve.get_baked_length()

	# --- MARIO ---
	var progreso_mario = player.get_progress_on_path(path)

	var progreso_total_mario = (
		(player.vueltas_completadas * largo_pista)
		+ progreso_mario
	)

	var posicion = 1

	# --- BOTS ---
	for bot in bots:

		var progreso_bot = bot.get_progress_on_path(path)

		var progreso_total_bot = (
			(bot.vueltas_completadas * largo_pista)
			+ progreso_bot
		)

		if progreso_total_bot > progreso_total_mario:
			posicion += 1

	var total_corredores = bots.size() + 1

	var sufijo = "th"

	if posicion == 1:
		sufijo = "st"

	elif posicion == 2:
		sufijo = "nd"

	elif posicion == 3:
		sufijo = "rd"

	posicion_label.text = "%d%s" % [
		posicion,
		sufijo
	]
