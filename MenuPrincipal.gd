extends Control
@onready var play_button = $VBoxContainer/Comenzar
@onready var options_button = $VBoxContainer/Opciones
@onready var quit_button = $VBoxContainer/Salir

func _ready():

	play_button.pressed.connect(_on_comenzar_pressed)
	options_button.pressed.connect(_on_opciones_pressed)
	quit_button.pressed.connect(_on_salir_pressed)


func _on_comenzar_pressed() -> void:
	get_tree().change_scene_to_file(
		"res://Pista.tscn"
	)


func _on_opciones_pressed() -> void:
	print("Abrir opciones")


func _on_salir_pressed() -> void:
	get_tree().quit()
