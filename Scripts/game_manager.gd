extends Node

@export var initState: Dictionary ={
	"launchFactor": 6,
	"dragging": null,
	"scoreGrid": [],
	"holdGrid": [],
	"oldHold": [],
	"tempScore": 0,
	"runningScore": 0,
	"phase": phase.ROLL,
	"firstRoll": true,
	"round": 0,
	"bust": false,
}

var state = ObservableState.new(initState)

enum phase{
	ROLL,
	PICK
}
var dice
var cam
var dicePos = []
@onready var score_grid: Node3D = $"../ScoreGrid"
@onready var hold_grid: Node3D = $"../HoldGrid"

func _ready() -> void:
	dice = get_tree().get_nodes_in_group('dice')
	cam = get_tree().get_first_node_in_group('cam')
	for die in dice:
		dicePos.push_back(die.global_position)
	print(dicePos)
	state.stateChanged.connect(stateChange)
	randomize()
	roll()
	
func _process(_delta: float) -> void:
	if state.get_value("phase") == phase.ROLL:
		var thaw = checkFrozen()
		if thaw:
			print('thawed')
			evalRoll()
			state.set_value("phase",phase.PICK) 
	if state.get_value("dragging") and state.get_value("phase") == phase.PICK:
		var moveTo = cam.project_ray_origin(get_viewport().get_mouse_position())
		state.get_value("dragging").position = Vector3(moveTo.x, 2,moveTo.z)
	
func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("ui_accept"):
	#	roll()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			
			if state.get_value("dragging") and state.get_value("phase") == phase.PICK:
				state.get_value("dragging").freeze = false
				if belowPlayarea(state.get_value("dragging").global_position):
					print('below')
					var grid = closerGrid(state.get_value("dragging").global_position)
					var snapTo = closestChild(grid, state.get_value("dragging").global_position)
					placeHold(state.get_value("dragging"), snapTo)
				else:
					var die = state.get_value("dragging")
					die.global_position = die.stats.returnPos
					die.freeze = true
					die.stats.play = Dice.playState.INPLAY
				state.set_value("dragging", null)
				#print(state)
		
func roll() -> void:
	state.set_value("phase",phase.ROLL)
	for die in dice:
			if die.stats.play == die.playState.INPLAY:
				die.freeze = false
				die.apply_impulse(randVec(6))
				die.apply_torque_impulse(randVec(12))

func get_random_sign():
	if randi() % 2 == 0:
		return 1
	else:
		return -1
		
func checkFrozen() -> bool:
	var thaw = true
	for die in dice:
		
		if die.freeze == false:
			thaw = false
	return thaw
	
func evalRoll() -> void:
	# Rethink in terms of conditions that allow another roll
	#snapshots? maybe not
	# this is where we determine bust so it must fail here if it fails
	# rolling a crit in active dice (check)
	# rolling at least a double in active die (check)
	# rolling a value that matching a scored die's crit (making a new double)(combined w above)
	# if a double was found in the last two steps does it match the current hold value?
	# rolling a value that would complete a triple
	####EDGE CASE#### handled
	# two tens allow you to swap back and forth every turn and play until you have a great payout
	var diceInPlay = []
	var currHold = state.get_value("holdGrid")[0] if state.get_value("holdGrid") else null
	#var oldHold = state.get_value("oldHold")[0].value if state.get_value("oldHold") else null
	var values = []
	var doubleFound
	
	if state.get_value("firstRoll"):
		#state.set_value("firstRoll", false)
		print('first roll over but state not changed')
		#early return (free roll)
	
	for die in dice:
		if die.stats.play == Dice.playState.INPLAY:
			diceInPlay.push_back(die)
			if isCrit(die):
				#state.set_value("canRoll", true)
				#return
				print("crit found")
				
	for die in state.get_value('scoreGrid'):
		diceInPlay.push_back(die.die)
	
	for die in diceInPlay:
		values.push_back(die.stats.value)
		
	if currHold and state.get_value("holdGrid").size() == 2:
		for die in diceInPlay:
			if die.stats.value == currHold.value:
				print("found third hold die")
	
	for i in range(diceInPlay.size()):
		for j in range(diceInPlay.size()):
			#if j == 0: continue
			if diceInPlay[i] != diceInPlay[j] and values[i] == values[j]:
				print('found double in active')
				doubleFound = values[j]
				# you should still check if the double in active == currHold and size to 
				# make sure the found double isn't contributing to a hold size above 3
				#return
				
	if doubleFound:
		if currHold and currHold.value == doubleFound:
			print('but it wasn\'t unique')
		else:
			print('and it was valid')
		
func resetDice() -> void:
	for i in range(dice.size()):
		dice[i].global_position = dicePos[i]
		dice[i].freeze = false
		dice[i].stats.play = Dice.playState.INPLAY
		print(dice[i].freeze)

func canRoll() -> bool:
	if state.get_value("holdGrid") and state.get_value("holdGrid").size() == 1:
		return false
	if state.get_value("firstRoll"):
		
		state.set_value("firstRoll", false)
		return true
	if not state.get_value("oldHold") and state.get_value("holdGrid"):
		return true
	if state.get_value("tempScore") > state.get_value("runningScore"):
		return true
	if state.get_value("oldHold") and state.get_value("holdGrid"):
		var old = state.get_value("oldHold")[0]
		var curr = state.get_value("holdGrid")[0]
		
		if old.value == curr.value:
			return false
		else:
			return true
		
	return false
	
func stateChange(key, _newVal) -> void:
	if key == "scoreGrid" or key == "holdGrid":
		state.set_value("tempScore", currentScore())
		print("score "+str(state.get_value("tempScore")))
	
func currentScore() -> int:
	var score: int = 0
	var holdGrid = state.get_value("holdGrid")
	for die in state.get_value("scoreGrid"):
		score += die.value
		
	if holdGrid and holdGrid.size() > 2:
		score = score * holdGrid[0].value
	return score

func randVec(factor) -> Vector3:
	var vX = randf()*factor*get_random_sign()
	var vY = randf()*factor*get_random_sign()
	var vZ = randf()*factor*get_random_sign()
	
	var veccy = Vector3(vX,vY,vZ)
	
	return veccy
	
func belowPlayarea(pos: Vector3) -> bool:
	if pos.z > 13.4:
		return true
	else:
		return false
		
func isCrit(die: Dice) -> bool:
	if die.stats.value == die.stats.maxRoll:
		return true
	else: return false
	
func placeHold(die: Dice, cell: Node3D) -> void:
	if cell.get_parent_node_3d().name == 'ScoreGrid':
		var crit = isCrit(die)
		if crit: 
			print("allowed")
			
			die.global_position = Vector3(cell.global_position.x,1.5,cell.global_position.z)
			die.stats.play = Dice.playState.SCORE
			var old = state.get_value("scoreGrid").duplicate()
			old.push_back({"node":cell,"die": die, "value": die.stats.value})
			state.set_value("scoreGrid", old)
			#state.set_value("tempScore", currentScore())
			
			state.get_value("dragging").freeze = true
		else:
			print('denied')
			die.global_position = die.stats.returnPos
			state.get_value("dragging").freeze = true
			state.get_value("dragging").stats.play = Dice.playState.INPLAY
	
	if cell.get_parent_node_3d().name == 'HoldGrid':
		var currHold
		if state.get_value("holdGrid"):
			currHold = state.get_value("holdGrid")[0].value
			
		if die.stats.value == currHold or !currHold:
			var old = state.get_value("holdGrid").duplicate()
			old.push_back({"node": cell, "die":die,"value": die.stats.value})
			state.set_value("holdGrid", old)
			#state.set_value("tempScore", currentScore())
			#print("score "+str(state.get_value("tempScore")))
			die.global_position = Vector3(cell.global_position.x,1.5,cell.global_position.z)
			die.stats.play = Dice.playState.SCORE
			state.get_value("dragging").freeze = true
		else:
			die.global_position = die.stats.returnPos
			state.get_value("dragging").freeze = true
			state.get_value("dragging").stats.play = Dice.playState.INPLAY
		
func closerGrid(pos: Vector3) -> Node3D:
	var toScore = score_grid.global_position.distance_to(pos)
	var toHold = hold_grid.global_position.distance_to(pos)
	
	if toHold < toScore:
		return hold_grid
	else:
		return score_grid
		
func closestChild(grid: Node3D, pos: Vector3) -> Node3D:
	var gridGroup = grid.get_children()
	var closest = null
	if state.get_value("scoreGrid") != [] or state.get_value("holdGrid") != []:
		var occupied = []
		var newGridGroup = []
		for cell in state.get_value("scoreGrid"):
			occupied.push_back(cell.node)
		for cell in state.get_value("holdGrid"):
			occupied.push_back(cell.node)
		for cell in gridGroup:
			if cell not in occupied:
				newGridGroup.push_back(cell)
		gridGroup = newGridGroup
	
	for cell in gridGroup:
		
		var distToCell = cell.global_position.distance_to(pos)
		if closest ==  null:
			closest = cell
		if distToCell < closest.global_position.distance_to(pos):
			closest = cell
			
	return closest

func drag(id: String) -> void:
	var target
	for die in dice:
		if(id == die.name):
			target = die
			
	#TODO Detect if target is below playline and remove target from state if so
	for item in state.get_value("scoreGrid"):
		if target == item.die:
			var old = state.get_value('scoreGrid').duplicate()
			old.erase(item)
			
			print(old)
			state.set_value("scoreGrid", old)
	for item in state.get_value("holdGrid"):
		if target == item.die:
			var old = state.get_value("holdGrid").duplicate()
			old.erase(item)
			state.set_value("holdGrid", old)
	target.freeze = true
	state.set_value("dragging", target)

func _on_d_12_input_event(_camera, event, _event_position, _normal, _shape_idx) -> void:
		var mouseButt = event is InputEventMouseButton
		if mouseButt and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			
			if state.get_value("phase") == phase.PICK:
				drag('D12')

func _on_d_20_input_event(_camera, event, _event_position, _normal, _shape_idx) -> void:
		var mouseButt = event is InputEventMouseButton
		if mouseButt and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			
			if state.get_value("phase") == phase.PICK:
				drag('D20')

func _on_d_102_input_event(_camera, event, _event_position, _normal, _shape_idx) -> void:
	var mouseButt = event is InputEventMouseButton
	if mouseButt and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		if state.get_value("phase") == phase.PICK:
			drag('D10-2')

func _on_d_10_input_event(_camera, event, _event_position, _normal, _shape_idx) -> void:
	var mouseButt = event is InputEventMouseButton
	if mouseButt and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		if state.get_value("phase") == phase.PICK:
			drag('D10')

func _on_d_8_input_event(_camera, event, _event_position, _normal, _shape_idx) -> void:
		var mouseButt = event is InputEventMouseButton
		if mouseButt and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			
			if state.get_value("phase") == phase.PICK:
				drag('D8')

func _on_d_6_input_event(_camera, event, _event_position, _normal, _shape_idx) -> void:
	var mouseButt = event is InputEventMouseButton
	if mouseButt and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		if state.get_value("phase") == phase.PICK:
			drag('D6')

func _on_d_4_input_event(_camera, event, _event_position, _normal, _shape_idx) -> void:
	var mouseButt = event is InputEventMouseButton
	if mouseButt and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		if state.get_value("phase") == phase.PICK:
			drag('D4')
