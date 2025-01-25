extends Node3D


@onready var loadout_gui: Node3D = $LoadoutGUI
@onready var helicopter_hud: CanvasLayer = $HelicopterHUD



func toggle_helicopter_hud():
	helicopter_hud.visible = !helicopter_hud.visible

func toggle_loadout_gui():
	loadout_gui.visible = !loadout_gui.visible



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	loadout_gui.visible = false
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
