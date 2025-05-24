## Undo/Redo Manager
##
## Manages undo and redo operations for map editing actions.
## Supports various action types like tile painting, map operations, etc.
class_name UndoRedoManager
extends RefCounted

# Action types
enum ActionType {
	PAINT_TILE,
	FLOOD_FILL,
	FILL_RECT,
	PASTE_TILES,
	RESIZE_MAP,
	CHANGE_TILESET
}

# Base action class
class Action:
	var type: ActionType
	var description: String
	var timestamp: float
	
	func _init(action_type: ActionType, desc: String):
		type = action_type
		description = desc
		timestamp = Time.get_ticks_msec() / 1000.0
	
	func execute():
		pass
	
	func undo():
		pass

# Paint tile action
class PaintTileAction extends Action:
	var map: FEMap
	var position: Vector2i
	var old_tile: int
	var new_tile: int
	
	func _init(target_map: FEMap, pos: Vector2i, old_value: int, new_value: int):
		super._init(ActionType.PAINT_TILE, "Paint tile at (%d, %d)" % [pos.x, pos.y])
		map = target_map
		position = pos
		old_tile = old_value
		new_tile = new_value
	
	func execute():
		map.set_tile_at(position.x, position.y, new_tile)
	
	func undo():
		map.set_tile_at(position.x, position.y, old_tile)

# Flood fill action
class FloodFillAction extends Action:
	var map: FEMap
	var start_position: Vector2i
	var old_tiles: Dictionary  # position -> old_tile_value
	var new_tile: int
	
	func _init(target_map: FEMap, start_pos: Vector2i, affected_tiles: Dictionary, fill_tile: int):
		super._init(ActionType.FLOOD_FILL, "Flood fill from (%d, %d)" % [start_pos.x, start_pos.y])
		map = target_map
		start_position = start_pos
		old_tiles = affected_tiles
		new_tile = fill_tile
	
	func execute():
		for pos in old_tiles.keys():
			map.set_tile_at(pos.x, pos.y, new_tile)
	
	func undo():
		for pos in old_tiles.keys():
			map.set_tile_at(pos.x, pos.y, old_tiles[pos])

# Fill rectangle action
class FillRectAction extends Action:
	var map: FEMap
	var rect: Rect2i
	var old_tiles: Array[int]
	var new_tile: int
	
	func _init(target_map: FEMap, area: Rect2i, old_data: Array[int], fill_tile: int):
		super._init(ActionType.FILL_RECT, "Fill rectangle %dx%d" % [area.size.x, area.size.y])
		map = target_map
		rect = area
		old_tiles = old_data
		new_tile = fill_tile
	
	func execute():
		map.fill_rect(rect.position.x, rect.position.y, rect.end.x, rect.end.y, new_tile)
	
	func undo():
		var index = 0
		for y in range(rect.position.y, rect.end.y + 1):
			for x in range(rect.position.x, rect.end.x + 1):
				if index < old_tiles.size():
					map.set_tile_at(x, y, old_tiles[index])
				index += 1

# Map resize action
class ResizeMapAction extends Action:
	var map: FEMap
	var old_width: int
	var old_height: int
	var old_data: Array[int]
	var new_width: int
	var new_height: int
	
	func _init(target_map: FEMap, old_w: int, old_h: int, old_tiles: Array[int], new_w: int, new_h: int):
		super._init(ActionType.RESIZE_MAP, "Resize map to %dx%d" % [new_w, new_h])
		map = target_map
		old_width = old_w
		old_height = old_h
		old_data = old_tiles
		new_width = new_w
		new_height = new_h
	
	func execute():
		map.resize(new_width, new_height, true)
	
	func undo():
		map.width = old_width
		map.height = old_height
		map.tile_data = old_data.duplicate()

# Main UndoRedoManager class
var undo_stack: Array[Action] = []
var redo_stack: Array[Action] = []
var max_history_size: int = 100
var current_map: FEMap

# Signals
signal action_executed(action: Action)
signal action_undone(action: Action)
signal action_redone(action: Action)
signal history_changed()

## Set the current map being edited
func set_current_map(map: FEMap):
	current_map = map
	clear_history()

## Add an action to the undo stack
func add_action(action: Action):
	# Clear redo stack when new action is added
	redo_stack.clear()
	
	# Add to undo stack
	undo_stack.append(action)
	
	# Limit history size
	while undo_stack.size() > max_history_size:
		undo_stack.pop_front()
	
	action_executed.emit(action)
	history_changed.emit()

## Add a paint tile action
func add_paint_action(position: Vector2i, old_tile: int, new_tile: int):
	if not current_map:
		return
	
	var action = PaintTileAction.new(current_map, position, old_tile, new_tile)
	add_action(action)

## Add a flood fill action
func add_flood_fill_action(start_pos: Vector2i, affected_tiles: Dictionary, fill_tile: int):
	if not current_map:
		return
	
	var action = FloodFillAction.new(current_map, start_pos, affected_tiles, fill_tile)
	add_action(action)

## Add a fill rectangle action
func add_fill_rect_action(rect: Rect2i, old_tiles: Array[int], fill_tile: int):
	if not current_map:
		return
	
	var action = FillRectAction.new(current_map, rect, old_tiles, fill_tile)
	add_action(action)

## Add a map resize action
func add_resize_action(old_width: int, old_height: int, old_data: Array[int], new_width: int, new_height: int):
	if not current_map:
		return
	
	var action = ResizeMapAction.new(current_map, old_width, old_height, old_data, new_width, new_height)
	add_action(action)

## Undo the last action
func undo() -> bool:
	if undo_stack.is_empty():
		return false
	
	var action = undo_stack.pop_back()
	action.undo()
	redo_stack.append(action)
	
	action_undone.emit(action)
	history_changed.emit()
	return true

## Redo the last undone action
func redo() -> bool:
	if redo_stack.is_empty():
		return false
	
	var action = redo_stack.pop_back()
	action.execute()
	undo_stack.append(action)
	
	action_redone.emit(action)
	history_changed.emit()
	return true

## Check if undo is available
func can_undo() -> bool:
	return not undo_stack.is_empty()

## Check if redo is available  
func can_redo() -> bool:
	return not redo_stack.is_empty()

## Get the next action that would be undone
func get_undo_action() -> Action:
	if undo_stack.is_empty():
		return null
	return undo_stack.back()

## Get the next action that would be redone
func get_redo_action() -> Action:
	if redo_stack.is_empty():
		return null
	return redo_stack.back()

## Clear all history
func clear_history():
	undo_stack.clear()
	redo_stack.clear()
	history_changed.emit()

## Get undo stack size
func get_undo_count() -> int:
	return undo_stack.size()

## Get redo stack size
func get_redo_count() -> int:
	return redo_stack.size()

## Get action history for display
func get_action_history(max_items: int = 10) -> Array[String]:
	var history: Array[String] = []
	var start_index = max(0, undo_stack.size() - max_items)
	
	for i in range(start_index, undo_stack.size()):
		history.append(undo_stack[i].description)
	
	return history

## Set maximum history size
func set_max_history_size(size: int):
	max_history_size = max(1, size)
	
	# Trim current history if needed
	while undo_stack.size() > max_history_size:
		undo_stack.pop_front()
	
	while redo_stack.size() > max_history_size:
		redo_stack.pop_front()

## Get memory usage estimate
func get_memory_usage() -> Dictionary:
	var undo_size = 0
	var redo_size = 0
	
	# Rough estimate based on action types
	for action in undo_stack:
		match action.type:
			ActionType.PAINT_TILE:
				undo_size += 32  # Small action
			ActionType.FLOOD_FILL:
				var flood_action = action as FloodFillAction
				undo_size += flood_action.old_tiles.size() * 12
			ActionType.FILL_RECT:
				var rect_action = action as FillRectAction
				undo_size += rect_action.old_tiles.size() * 4
			ActionType.RESIZE_MAP:
				var resize_action = action as ResizeMapAction
				undo_size += resize_action.old_data.size() * 4
	
	for action in redo_stack:
		match action.type:
			ActionType.PAINT_TILE:
				redo_size += 32
			ActionType.FLOOD_FILL:
				var flood_action = action as FloodFillAction
				redo_size += flood_action.old_tiles.size() * 12
			ActionType.FILL_RECT:
				var rect_action = action as FillRectAction
				redo_size += rect_action.old_tiles.size() * 4
			ActionType.RESIZE_MAP:
				var resize_action = action as ResizeMapAction
				redo_size += resize_action.old_data.size() * 4
	
	return {
		"undo_actions": undo_stack.size(),
		"redo_actions": redo_stack.size(),
		"undo_size_bytes": undo_size,
		"redo_size_bytes": redo_size,
		"total_size_bytes": undo_size + redo_size
	}
