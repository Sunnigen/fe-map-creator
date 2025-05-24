## Map Canvas
##
## Main editing area for Fire Emblem maps. Handles tile painting, selection,
## zoom, pan, and other editing operations.
class_name MapCanvas
extends Control

# UI References
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var tilemap: TileMap = $ScrollContainer/TileMap

# Current state
var current_map: FEMap
var current_tileset_data: FETilesetData
var selected_tile_index: int = 0
var current_tool: EventBus.EditorTool = EventBus.EditorTool.PAINT

# Grid overlay
var show_grid: bool = true
var grid_color: Color = Color.WHITE
var grid_opacity: float = 0.3

# Zoom and pan
var zoom_level: float = 1.0
var min_zoom: float = 0.1
var max_zoom: float = 8.0
var zoom_speed: float = 1.2
var pan_speed: float = 1.0

# Selection
var selection_start: Vector2i = Vector2i(-1, -1)
var selection_end: Vector2i = Vector2i(-1, -1)
var is_selecting: bool = false

# Painting state
var is_painting: bool = false
var last_painted_tile: Vector2i = Vector2i(-1, -1)

# Constants
const TILE_SIZE = 16

# Signals
signal tile_painted(position: Vector2i, old_tile: int, new_tile: int)
signal selection_changed(area: Rect2i)
signal map_modified()

func _ready():
	# Set up scroll container
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Connect to EventBus
	EventBus.tool_changed.connect(_on_tool_changed)
	EventBus.tile_selected.connect(_on_tile_selected)
	EventBus.zoom_changed.connect(_on_zoom_changed)
	EventBus.grid_toggled.connect(_on_grid_toggled)
	
	# Set up zoom
	update_zoom()

func _input(event: InputEvent):
	if not current_map:
		return
		
	# Handle zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent):
	if not current_map:
		return
	
	if event is InputEventMouseButton:
		var mouse_pos = get_local_mouse_position()
		var tile_pos = world_to_tile(mouse_pos)
		
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_handle_left_click(tile_pos, event)
				MOUSE_BUTTON_RIGHT:
					_handle_right_click(tile_pos, event)
		else:
			_handle_mouse_release(tile_pos, event)
	
	elif event is InputEventMouseMotion:
		var mouse_pos = get_local_mouse_position()
		var tile_pos = world_to_tile(mouse_pos)
		_handle_mouse_motion(tile_pos, event)

func _handle_left_click(tile_pos: Vector2i, event: InputEventMouseButton):
	if not _is_valid_tile_position(tile_pos):
		return
		
	match current_tool:
		EventBus.EditorTool.PAINT:
			_start_painting(tile_pos)
		EventBus.EditorTool.FILL:
			_flood_fill(tile_pos)
		EventBus.EditorTool.SELECT:
			_start_selection(tile_pos)
		EventBus.EditorTool.EYEDROPPER:
			_eyedrop_tile(tile_pos)

func _handle_right_click(tile_pos: Vector2i, event: InputEventMouseButton):
	# Right-click for eyedropper regardless of current tool
	if _is_valid_tile_position(tile_pos):
		_eyedrop_tile(tile_pos)

func _handle_mouse_release(tile_pos: Vector2i, event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		match current_tool:
			EventBus.EditorTool.PAINT:
				_stop_painting()
			EventBus.EditorTool.SELECT:
				_finish_selection(tile_pos)

func _handle_mouse_motion(tile_pos: Vector2i, event: InputEventMouseMotion):
	if not _is_valid_tile_position(tile_pos):
		return
		
	match current_tool:
		EventBus.EditorTool.PAINT:
			if is_painting:
				_paint_tile(tile_pos)
		EventBus.EditorTool.SELECT:
			if is_selecting:
				_update_selection(tile_pos)

func _start_painting(tile_pos: Vector2i):
	is_painting = true
	last_painted_tile = Vector2i(-1, -1)
	_paint_tile(tile_pos)

func _stop_painting():
	is_painting = false
	last_painted_tile = Vector2i(-1, -1)

func _paint_tile(tile_pos: Vector2i):
	if not _is_valid_tile_position(tile_pos):
		return
	
	# Avoid painting the same tile repeatedly
	if tile_pos == last_painted_tile:
		return
	
	var old_tile = current_map.get_tile_at(tile_pos.x, tile_pos.y)
	if old_tile == selected_tile_index:
		return  # No change needed
	
	# Update map data
	current_map.set_tile_at(tile_pos.x, tile_pos.y, selected_tile_index)
	
	# Update visual tilemap
	var atlas_coords = Vector2i(selected_tile_index % 32, selected_tile_index / 32)
	tilemap.set_cell(0, tile_pos, 0, atlas_coords)
	
	# Emit signals
	tile_painted.emit(tile_pos, old_tile, selected_tile_index)
	map_modified.emit()
	
	last_painted_tile = tile_pos

func _flood_fill(tile_pos: Vector2i):
	if not _is_valid_tile_position(tile_pos):
		return
	
	var old_tile = current_map.get_tile_at(tile_pos.x, tile_pos.y)
	if old_tile == selected_tile_index:
		return  # Nothing to fill
	
	var tiles_changed = current_map.flood_fill(tile_pos.x, tile_pos.y, selected_tile_index)
	
	if tiles_changed > 0:
		# Refresh the entire tilemap
		_refresh_tilemap()
		map_modified.emit()
		print("Flood filled ", tiles_changed, " tiles")

func _start_selection(tile_pos: Vector2i):
	is_selecting = true
	selection_start = tile_pos
	selection_end = tile_pos
	_update_selection_display()

func _update_selection(tile_pos: Vector2i):
	selection_end = tile_pos
	_update_selection_display()

func _finish_selection(tile_pos: Vector2i):
	is_selecting = false
	selection_end = tile_pos
	
	var area = _get_selection_rect()
	selection_changed.emit(area)

func _eyedrop_tile(tile_pos: Vector2i):
	if not _is_valid_tile_position(tile_pos):
		return
	
	var tile_index = current_map.get_tile_at(tile_pos.x, tile_pos.y)
	if tile_index >= 0:
		selected_tile_index = tile_index
		EventBus.emit_tile_selected(tile_index)
		print("Eyedropped tile: ", tile_index)

func _update_selection_display():
	# This would draw selection rectangle on overlay
	queue_redraw()

func _get_selection_rect() -> Rect2i:
	if selection_start == Vector2i(-1, -1) or selection_end == Vector2i(-1, -1):
		return Rect2i()
	
	var min_x = min(selection_start.x, selection_end.x)
	var min_y = min(selection_start.y, selection_end.y)
	var max_x = max(selection_start.x, selection_end.x)
	var max_y = max(selection_start.y, selection_end.y)
	
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

## Load a map into the canvas
func load_map(map: FEMap):
	current_map = map
	current_tileset_data = AssetManager.get_tileset_data(map.tileset_id)
	
	if not current_tileset_data:
		push_error("Could not load tileset data for: " + map.tileset_id)
		return
	
	# Set up tilemap
	tilemap.tile_set = current_tileset_data.tileset_resource
	_refresh_tilemap()
	
	# Center the view
	_center_view()
	
	print("Map loaded in canvas: ", map.name, " (", map.width, "x", map.height, ")")

## Refresh the visual tilemap from map data
func _refresh_tilemap():
	if not current_map or not tilemap.tile_set:
		return
	
	tilemap.clear()
	
	for y in range(current_map.height):
		for x in range(current_map.width):
			var tile_index = current_map.get_tile_at(x, y)
			if tile_index >= 0:
				var atlas_coords = Vector2i(tile_index % 32, tile_index / 32)
				tilemap.set_cell(0, Vector2i(x, y), 0, atlas_coords)

## Convert world position to tile coordinates
func world_to_tile(world_pos: Vector2) -> Vector2i:
	# Account for scroll offset and zoom
	var scroll_offset = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
	var local_pos = (world_pos + scroll_offset) / zoom_level
	
	return Vector2i(int(local_pos.x / TILE_SIZE), int(local_pos.y / TILE_SIZE))

## Convert tile coordinates to world position
func tile_to_world(tile_pos: Vector2i) -> Vector2:
	var world_pos = Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE) * zoom_level
	var scroll_offset = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
	return world_pos - scroll_offset

## Check if tile position is valid
func _is_valid_tile_position(tile_pos: Vector2i) -> bool:
	if not current_map:
		return false
	return tile_pos.x >= 0 and tile_pos.x < current_map.width and tile_pos.y >= 0 and tile_pos.y < current_map.height

## Zoom in
func zoom_in():
	var new_zoom = zoom_level * zoom_speed
	if new_zoom <= max_zoom:
		set_zoom(new_zoom)

## Zoom out  
func zoom_out():
	var new_zoom = zoom_level / zoom_speed
	if new_zoom >= min_zoom:
		set_zoom(new_zoom)

## Set zoom level
func set_zoom(new_zoom: float):
	zoom_level = clamp(new_zoom, min_zoom, max_zoom)
	update_zoom()
	EventBus.emit_zoom_changed(zoom_level)

## Update zoom transform
func update_zoom():
	if tilemap:
		tilemap.scale = Vector2(zoom_level, zoom_level)
	queue_redraw()

## Center the view on the map
func _center_view():
	if not current_map:
		return
	
	var map_size = Vector2(current_map.width * TILE_SIZE, current_map.height * TILE_SIZE) * zoom_level
	var viewport_size = scroll_container.size
	
	var center_offset = (map_size - viewport_size) / 2
	center_offset = center_offset.max(Vector2.ZERO)
	
	scroll_container.scroll_horizontal = int(center_offset.x)
	scroll_container.scroll_vertical = int(center_offset.y)

## Draw overlay (grid, selection, etc.)
func _draw():
	if not current_map:
		return
	
	if show_grid:
		_draw_grid()
	
	if is_selecting:
		_draw_selection()

## Draw grid overlay
func _draw_grid():
	var viewport_rect = get_rect()
	var start_tile = world_to_tile(Vector2.ZERO)
	var end_tile = world_to_tile(viewport_rect.size)
	
	# Extend by a few tiles to ensure coverage
	start_tile -= Vector2i(2, 2)
	end_tile += Vector2i(2, 2)
	
	# Clamp to map bounds
	start_tile = start_tile.max(Vector2i.ZERO)
	end_tile = end_tile.min(Vector2i(current_map.width, current_map.height))
	
	var grid_color_with_alpha = Color(grid_color.r, grid_color.g, grid_color.b, grid_opacity)
	
	# Draw vertical lines
	for x in range(start_tile.x, end_tile.x + 1):
		var start_world = tile_to_world(Vector2i(x, start_tile.y))
		var end_world = tile_to_world(Vector2i(x, end_tile.y))
		draw_line(start_world, end_world, grid_color_with_alpha)
	
	# Draw horizontal lines
	for y in range(start_tile.y, end_tile.y + 1):
		var start_world = tile_to_world(Vector2i(start_tile.x, y))
		var end_world = tile_to_world(Vector2i(end_tile.x, y))
		draw_line(start_world, end_world, grid_color_with_alpha)

## Draw selection rectangle
func _draw_selection():
	var selection_rect = _get_selection_rect()
	if selection_rect.size == Vector2i.ZERO:
		return
	
	var start_world = tile_to_world(selection_rect.position)
	var end_world = tile_to_world(selection_rect.position + selection_rect.size)
	var world_rect = Rect2(start_world, end_world - start_world)
	
	draw_rect(world_rect, Color.YELLOW, false, 2.0)

# Event handlers
func _on_tool_changed(tool: EventBus.EditorTool):
	current_tool = tool
	# Stop any current operations
	is_painting = false
	is_selecting = false

func _on_tile_selected(tile_index: int):
	selected_tile_index = tile_index

func _on_zoom_changed(new_zoom: float):
	if abs(zoom_level - new_zoom) > 0.01:  # Avoid feedback loops
		zoom_level = new_zoom
		update_zoom()

func _on_grid_toggled(visible: bool):
	show_grid = visible
	queue_redraw()

## Get current map
func get_current_map() -> FEMap:
	return current_map

## Get current tool
func get_current_tool() -> EventBus.EditorTool:
	return current_tool

## Get selected tile index
func get_selected_tile() -> int:
	return selected_tile_index

## Get zoom information
func get_zoom_info() -> Dictionary:
	return {
		"current": zoom_level,
		"min": min_zoom,
		"max": max_zoom,
		"speed": zoom_speed
	}
