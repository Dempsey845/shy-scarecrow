class_name Player
extends CharacterBody3D

signal pumpkin_too_large(pumpkin: Pumpkin)

func emit_pumpkin_too_large(pumpkin: Pumpkin):
    pumpkin_too_large.emit(pumpkin)