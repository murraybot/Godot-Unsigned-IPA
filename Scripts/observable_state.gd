class_name ObservableState
extends RefCounted

signal stateChanged(key, newValue)

var _data: Dictionary

func _init(initial_data: Dictionary = {}):
	_data = initial_data.duplicate()

func set_value(key, value):
	_data[key] = value
	stateChanged.emit(key, value)

func get_value(key):
	return _data.get(key)
