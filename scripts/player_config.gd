class_name PlayerConfig
extends Resource

@export var walk_speed := 4.3
@export var run_speed := 6.8
@export var acceleration := 24.0
@export var dash_speed := 7.5
@export var dash_duration := 0.20
@export var dash_cooldown := 0.65
@export var visual_scale := Vector3.ONE
@export var visual_offset := Vector3.ZERO
@export var hold_offset := Vector3(0, 0.82, 0.47)
@export var use_visual_hand_anchor := true
@export var visual_scene: PackedScene
