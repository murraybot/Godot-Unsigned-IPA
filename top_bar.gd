extends Control

var manager
@onready var roll: Button = $Panel/VBoxContainer/HBoxContainer/Roll
@onready var click_sfx: AudioStreamPlayer = $click
@onready var error: AudioStreamPlayer = $error

@onready var cash_out: Button = $Panel/VBoxContainer/HBoxContainer/CashOut

func _ready() -> void:
	manager = get_tree().get_first_node_in_group('manager')
	manager.state.stateChanged.connect(newState)


func newState(key, newValue):
	if key == 'holdGrid':
		print("____________UI updated____________")
		print(newValue)
		
	if key == 'phase':
		if newValue == manager.phase.PICK:
			cash_out.disabled = false
			roll.disabled = false
		else:
			cash_out.disabled = true
			cash_out.disabled = true
		#We may want to have 3 states for buttons disabled, unable, and able
		# disabled when rolling so nobody could cash out mid roll
		# unable, when the the held dice don't allow for a new roll (roll button only)
		print('enable buttons')
		


func _on_roll_pressed() -> void:
	# run a validator func from the manager that checks 
	# 1. if the tempScore went up (check)
	# 2. if the hold value is != to oldhold and != null (check)
	# 3. move the first roll toggle to this function (check)
	# 4. if holdGrid size == 1 return false (check)
	# if that returns true, set old hold and old score to duplicates of current
	# set tempScore to runningScore
	# call roll from manager
	# if false, call a dialog? 
	
	if manager.canRoll():
		click_sfx.play()
		print('can roll')
		manager.state.set_value("oldHold", manager.state.get_value("holdGrid").duplicate())
		manager.state.set_value("runningScore", manager.state.get_value("tempScore"))
		manager.roll()
		roll.release_focus()
		roll.disabled = true
	else:
		print('can not roll')
		error.play()
	


func _on_cash_out_pressed() -> void:
	click_sfx.play()
	manager.resetDice()
	manager.state.set_value('holdGrid', [])
	manager.state.set_value('scoreGrid', [])
	manager.state.set_value('runningScore', 0)
	manager.state.set_value('firstRoll', true)
	manager.state.set_value('round', manager.state.get_value('round') + 1)
	manager.roll()
	# add tempScore to score and reset tempScore and runningScore
	# increment state round
	# set an initial dice position in manager (do it ready function before init roll)
	# make a reset postion func in manager and call it here
	# call roll
