class_name Dice extends RigidBody3D
@onready var values: Node3D = $values
@onready var impacts: Node3D = $impacts

var valLock := false
var oldTouch

var stats: Dictionary = {
	'is_active': true,
	'value': null,
	'returnPos': null,
	'moveable': false,
	'play': playState.INPLAY,
	'maxRoll': null
}

enum playState{
	INPLAY,
	SCORE,
	MULT
}

func _ready() -> void:
	stats.maxRoll = values.get_children().size()
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

func findValue() -> void:
	var highest: Node3D = null
	
	for value in values.get_children():
		if highest == null: 
			highest = value
		#print(value.global_position.y)
		if value.global_position.y > highest.global_position.y: 
			highest = value
			#print(highest.name+' '+str(highest.global_position.y))
	
	print(self.name+' '+highest.name+'/'+str(stats.maxRoll))
	stats.value = int(highest.name)
	stats.returnPos = self.global_position
	valLock= true
	freeze = true
	
func _physics_process(delta: float) -> void:
	var touching = get_colliding_bodies()
	
	if touching != oldTouch:
		print("new collide")
		var sounds = impacts.get_children()
		var randIndex = randi() % impacts.get_children().size()
		sounds[randIndex].play()
		oldTouch = touching

func _process(_delta: float) -> void:
	if sleeping and !valLock and stats.play == playState.INPLAY:
		findValue()
	if !sleeping and valLock:
		valLock = false
		stats.moveable = true
	
