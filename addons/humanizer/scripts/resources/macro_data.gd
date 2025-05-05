@tool
extends Resource
class_name MacroData


@export var registered_macros := {} #shape keys with the weights for each macro
@export var macro_registry := {}#a registry of all macros and what targets utilize that macro
@export var macro_defaults := {}#storing default values for all marco keys
