extends Node


signal helicopter_vehicle_updated(vehicle)




func send_helicopter_update(updated_helicopter: Helicopter):
	emit_signal("helicopter_vehicle_updated", updated_helicopter)



enum USER_INTERFACES {
	HELICOPTER_UI,
	HELICOPTER_LOADOUT,
}

func set_UI_menu():
	pass
