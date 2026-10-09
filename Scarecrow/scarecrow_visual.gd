class_name ScarecrowVisual
extends Node3D

@onready var head: MeshInstance3D = $Head
@onready var hat: MeshInstance3D = $Hat
@onready var straw_hair: MeshInstance3D = $Straw_001

func hide_head():
    head.visible = false
    hat.visible = false
    straw_hair.visible = false