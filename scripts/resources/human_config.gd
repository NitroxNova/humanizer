@tool
class_name HumanConfig
extends Resource

## Rig
@export var rig: String

## Shapekey Settings
@export var shapekeys := {}

## Additional Components
@export var components := [&'main_collider', &'lod']

## Equipped body parts
@export var body_parts := {}
@export var body_part_materials := {}

## Equipped clothes
@export var clothes := []
@export var clothes_materials := {}

## Custom Transforms
@export var transforms := {}

## Colors
@export var skin_color: Color = Humanizer._DEFAULT_SKIN_COLOR
@export var eye_color: Color = Humanizer._DEFAULT_EYE_COLOR
@export var eyebrow_color: Color = Humanizer._DEFAULT_EYEBROW_COLOR
@export var hair_color: Color = Humanizer._DEFAULT_HAIR_COLOR

## Overlay config
@export var overlay_material_configs := {}
