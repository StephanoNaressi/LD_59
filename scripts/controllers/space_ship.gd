extends Node3D

var is_player_in_area : bool = false
@onready var camera_3d: Camera3D = $spaceship/Chair/Camera3D
var is_driving : bool = false
var player : Player

const PROYECTILE = preload("uid://b65juspb4p45s")

func _ready() -> void:
	camera_3d.current = false
	

func _process(delta: float) -> void:
	if is_player_in_area and Input.is_action_just_pressed("Interact"):
		player = GlobalValues.player
		if is_driving:
			unlock_player_from_chair()
		else:
			lock_player_to_chair()
	if is_driving and Input.is_action_just_pressed("MouseLeft"):
		shoot(player)
		
func shoot(target: Node3D) -> void:
	var p : Proyectile = PROYECTILE.instantiate()
	get_tree().current_scene.add_child(p)
	p.target = target
	
func lock_player_to_chair() -> void:
	if player == null : return
	player.is_locked = true
	is_driving = true
	player.camera_3d.current = false
	camera_3d.current = true


func unlock_player_from_chair() -> void:
	if player == null : return
	player.is_locked = false
	is_driving = false
	player.camera_3d.current = true
	camera_3d.current = false

func _on_chair_area_body_entered(body: Node3D) -> void:
	if body is Player:
		is_player_in_area = true

func _on_chair_area_body_exited(body: Node3D) -> void:
	if body is Player:
		is_player_in_area = false
