class_name Helicopter_Weapon_Subsystem extends Node3D


enum SIDE {
	LEFT,
	RIGHT
}
@export var joint: JoltHingeJoint3D
@export var small_slot: Node3D
@export var side: SIDE
@export var medium_slot: Node3D


func _ready():
	assert(joint and medium_slot and small_slot, "Need to assign the joint, med slot and small slot to helicopter")
