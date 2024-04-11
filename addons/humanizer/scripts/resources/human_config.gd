@tool
class_name HumanConfig
extends Resource

## Rig
@export var rig: String

## Shapekey Settings
@export var shapekeys := {}

## Additional Components
@export var components := []

## Equipped body parts
@export var body_parts := {}
@export var body_part_materials := {}

## Equipped clothes
@export var clothes := []
@export var clothes_materials := {}

## Colors
@export var skin_color: Color = Color.WHITE
@export var eye_color: Color = Color.SKY_BLUE
@export var hair_color: Color = Color.BLACK

