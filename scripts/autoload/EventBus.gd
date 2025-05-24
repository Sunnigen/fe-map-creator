## Global Event Bus
##
## Centralized event system for decoupled communication between components.
## Use this for events that multiple systems need to know about.
extends Node

# Map-related events
signal map_loaded(map: FEMap)
signal map_saved(map: FEMap, file_path: String)
signal map_created(map: FEMap)
signal map_modified(map: FEMap)
signal map_closed()

# Tileset-related events
signal tileset_changed(tileset_id: String)
signal tileset_loaded(tileset_data: FETilesetData)

# Tool-related events
signal tool_changed(tool: EditorTool)
signal tile_selected(tile_index: int)

# UI events
signal zoom_changed(zoom_level: float)
signal grid_toggled(visible: bool)
signal selection_changed(area: Rect2i)

# Editor state events
signal editor_ready()
signal settings_changed(settings: Dictionary)

# Undo/Redo events
signal action_performed(action_name: String)
signal undo_performed(action_name: String)
signal redo_performed(action_name: String)

# Animation events
signal animation_state_changed(enabled: bool)

# File system events
signal recent_files_updated(files: Array[String])

## Editor tools enumeration
enum EditorTool {
	PAINT,        # Place single tiles
	FILL,         # Flood fill
	RECTANGLE,    # Draw rectangles
	SELECT,       # Selection tool
	EYEDROPPER    # Pick tile from map
}

## Emits a map loaded event
func emit_map_loaded(map: FEMap):
	map_loaded.emit(map)
	print("Map loaded: ", map.name if map.name else "Untitled")

## Emits a map saved event
func emit_map_saved(map: FEMap, file_path: String):
	map_saved.emit(map, file_path)
	print("Map saved: ", file_path)

## Emits a tool change event
func emit_tool_changed(tool: EditorTool):
	tool_changed.emit(tool)
	print("Tool changed to: ", EditorTool.keys()[tool])

## Emits a tileset change event
func emit_tileset_changed(tileset_id: String):
	tileset_changed.emit(tileset_id)
	print("Tileset changed to: ", tileset_id)

## Emits a zoom change event
func emit_zoom_changed(zoom_level: float):
	zoom_changed.emit(zoom_level)

## Emits a grid toggle event
func emit_grid_toggled(is_visible: bool):
	grid_toggled.emit(is_visible)

## Emits a tile selection event
func emit_tile_selected(tile_index: int):
	tile_selected.emit(tile_index)

## Emits a selection change event
func emit_selection_changed(area: Rect2i):
	selection_changed.emit(area)

## Emits an action performed event for undo/redo
func emit_action_performed(action_name: String):
	action_performed.emit(action_name)

## Emits an undo event
func emit_undo_performed(action_name: String):
	undo_performed.emit(action_name)

## Emits a redo event
func emit_redo_performed(action_name: String):
	redo_performed.emit(action_name)

## Emits editor ready event
func emit_editor_ready():
	editor_ready.emit()
	print("FE Map Creator ready")

## Emits settings changed event
func emit_settings_changed(settings: Dictionary):
	settings_changed.emit(settings)

## Gets string representation of a tool
func get_tool_name(tool: EditorTool) -> String:
	match tool:
		EditorTool.PAINT:
			return "Paint"
		EditorTool.FILL:
			return "Fill"
		EditorTool.RECTANGLE:
			return "Rectangle"
		EditorTool.SELECT:
			return "Select"
		EditorTool.EYEDROPPER:
			return "Eyedropper"
		_:
			return "Unknown"

## Gets hotkey for a tool
func get_tool_hotkey(tool: EditorTool) -> String:
	match tool:
		EditorTool.PAINT:
			return "B"
		EditorTool.FILL:
			return "F"
		EditorTool.RECTANGLE:
			return "R"
		EditorTool.SELECT:
			return "S"
		EditorTool.EYEDROPPER:
			return "I"
		_:
			return ""
