extends Control


@onready var continuar_button = $CenterContainer/VBoxContainer/Continue
@onready var reiniciar_button = $CenterContainer/VBoxContainer/Restart
@onready var opciones_button = $CenterContainer/VBoxContainer/Options
@onready var salir_button = $CenterContainer/VBoxContainer/Exit


func _ready() -> void:

	visible = false

	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	continuar_button.pressed.connect(_on_continuar_pressed)
	reiniciar_button.pressed.connect(_on_reiniciar_pressed)
	opciones_button.pressed.connect(_on_opciones_pressed)
	salir_button.pressed.connect(_on_salir_pressed)


func _on_continuar_pressed() -> void:

	get_tree().paused = false

	visible = false


func _on_reiniciar_pressed() -> void:

	get_tree().paused = false

	get_tree().reload_current_scene()


func _on_opciones_pressed() -> void:

	print("Opciones")


func _on_salir_pressed() -> void:

	get_tree().paused = false

	get_tree().change_scene_to_file(
		"res://MenuPrincipal.tscn"
	)
