extends CharacterBody2D

## El uso de "%path" es un shorthand para acceder a los "Nodos Unicos de Escena"
## El nodo "Weapon" está marcado como un "Nodo Único de Escena", es decir, es el
## único nodo en la escena actual que se llama así, por lo que si se hace una query del
## mismo utilizando este patrón, se puede acceder a él de manera dinámica sin
## importar su ubicación en el árbol, es decir, ya no se tiene que especificar una
## ruta estática al mismo.
## https://docs.godotengine.org/es/stable/tutorials/scripting/scene_unique_nodes.html
@onready var weapon: Node = $"%Weapon"
@onready var body_animations: AnimationPlayer = $BodyAnimations
@onready var pivot: Node2D = $Pivot


const FLOOR_NORMAL: Vector2 = Vector2.UP  # Igual a Vector2(0, -1)
const SNAP_DIRECTION: Vector2 = Vector2.UP
const SNAP_LENGHT: float = 32.0
const SLOPE_THRESHOLD: float = deg_to_rad(46)
@export var push_force:float = 550.0
@export var ACCELERATION: float = 60.0
@export var H_SPEED_LIMIT: float = 600.0
@export var jump_speed: int = 500
@export var FRICTION_WEIGHT: float = 0.0
@export var gravity: int = 5

var projectile_container: Node

var vel: Vector2 = Vector2.ZERO
var snap_vector: Vector2 = SNAP_DIRECTION * SNAP_LENGHT

## Flag de ayuda para saber identificar el estado de actividad
var dead: bool = false


func _ready() -> void:
	initialize()


func initialize(projectile_container: Node = get_parent()) -> void:
	self.projectile_container = projectile_container
	weapon.projectile_container = projectile_container

func _process_input() -> void:
	## Estoy muerto, asi que dejo de procesar inputs y solo aplico fricción para
	## que no se deslice como cubito de hielo
	if dead:
		vel.x = lerp(vel.x, 0, FRICTION_WEIGHT) if abs(vel.x) > 1 else 0
		return
	
	# Weapon Fire
	if Input.is_action_just_pressed("fire_cannon"):
		if projectile_container == null:
			projectile_container = get_parent()
		if weapon.projectile_container == null:
			weapon.projectile_container = projectile_container
		weapon.fire()

	# Jump Action
	var jump = Input.is_action_just_pressed("jump")
	if jump and is_on_floor():
		vel.y -= jump_speed

	#Horizontal Movement
	var h_movement_direction: int = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	if h_movement_direction != 0:
		vel.x = clamp(vel.x + (h_movement_direction * ACCELERATION), -H_SPEED_LIMIT, H_SPEED_LIMIT)
		pivot.scale.x = 1 - 2 * float(h_movement_direction < 0)
	else:
		vel.x = lerp(vel.x, 0.0, FRICTION_WEIGHT) if abs(vel.x) > 1 else 0
	weapon.process_input()
	
	
	if !is_on_floor():
		_play_animation("jump")
	elif h_movement_direction !=0:
		_play_animation("run")
	else:
		_play_animation("idle")


func _physics_process(delta: float) -> void:
	_process_input()
	vel.y += gravity
	set_velocity(vel)
	# TODOConverter3To4 looks that snap in Godot 4 is float, not vector like in Godot 3 - previous value `snap_vector`
	set_up_direction(FLOOR_NORMAL)
	set_floor_stop_on_slope_enabled(true)
	set_max_slides(4)
	set_floor_max_angle(SLOPE_THRESHOLD)
	move_and_slide()
	vel = vel
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			c.get_collider().apply_central_impulse(-c.get_normal() * push_force)

func notify_hit() -> void:
	print("I'm player and imma die")
	call_deferred("_remove")


func _remove() -> void:
	set_physics_process(false)
	hide()
	collision_layer = 0


## Wrapper sobre el llamado a animación para tener un solo punto de entrada controlable
## (en el caso de que necesitemos expandir la lógica o debuggear, por ejemplo)
func _play_animation(animation: String) -> void:
	if body_animations.has_animation(animation):
		body_animations.play(animation)
