extends Node3D

var manager
@onready var score: Label3D = $Potion_1/score

func _ready() -> void:
	manager = get_tree().get_first_node_in_group('manager')
	manager.state.stateChanged.connect(updateScore)
	
func updateScore(key, newValue) -> void:
	if key == "tempScore":
		score.text = str(newValue)
