class_name Helicopter_Weapon_Subsystem extends Node3D


enum SIDE {
	LEFT,
	RIGHT
}
@export var side: SIDE
@export var joint: JoltHingeJoint3D
@export var medium_slot_a: Node3D
@export var small_slot_a: Node3D


func _ready():
	assert(joint and medium_slot_a and small_slot_a, "Need to assign the joint, med slot and small slot to helicopter")
