## Tileset Viewer
##
## Displays a tileset as a clickable grid for tile selection.
## Shows 32x32 grid of 16x16 tiles with selection highlighting.
class_name TilesetViewer
extends Control

# Current tileset data
var tileset_texture: Texture2D
var tileset_data: FETilesetData
var selected_tile: int = 0

# Display settings
var tile_display_size: Vector2i = Vector2i(16, 16)
var tiles_per_row: int = 32
var show_terrain_info: bool = false
var show_animation_indicators: bool = true

# Colors
var selection_color: Color = Color.YELLOW
var hover_color: Color = Color.WHITE
var animated_tile_color: Color = Color.CYAN

# State
var hovered_tile: int = -1
var is_hovering: bool = false

# Signals
signal tile_clicked(tile_index: int)
signal tile_hovered(tile_index: int)

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Set minimum size based on tileset dimensions
	custom_minimum_size = Vector2(tiles_per_row * tile_display_size.x, 32 * tile_display_size.y)

func _gui_input(event: InputEvent):
	if not tileset_texture:
		return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var tile_index = _get_tile_at_position(event.position)
			if tile_index >= 0:
				_select_tile(tile_index)
	
	elif event is InputEventMouseMotion:
		var tile_index = _get_tile_at_position(event.position)
		if tile_index != hovered_tile:
			hovered_tile = tile_index
			tile_hovered.emit(tile_index)
			queue_redraw()

func _draw():
	if not tileset_texture:
		return
	
	var rows = 32
	var cols = tiles_per_row
	
	# Draw all tiles
	for row in range(rows):
		for col in range(cols):
			var tile_index = row * cols + col
			var dest_pos = Vector2(col * tile_display_size.x, row * tile_display_size.y)
			var dest_rect = Rect2(dest_pos, Vector2(tile_display_size))
			var src_rect = Rect2(col * 16, row * 16, 16, 16)
			
			# Draw the tile
			draw_texture_rect_region(tileset_texture, dest_rect, src_rect)
			
			# Draw animation indicator
			if show_animation_indicators and tileset_data and tileset_data.is_tile_animated(tile_index):
				var indicator_rect = Rect2(dest_pos + Vector2(12, 0), Vector2(4, 4))
				draw_rect(indicator_rect, animated_tile_color)
			
			# Draw selection highlight
			if tile_index == selected_tile:
				draw_rect(dest_rect, selection_color, false, 2.0)
			elif tile_index == hovered_tile and is_hovering:
				draw_rect(dest_rect, hover_color, false, 1.0)

## Display a tileset
func display_tileset(data: FETilesetData):
	tileset_data = data
	tileset_texture = data.texture
	
	if tileset_texture:
		queue_redraw()
		print("TilesetViewer displaying: ", data.name)
	else:
		push_error("No texture found for tileset: " + data.name)

## Select a tile
func _select_tile(tile_index: int):
	if tile_index >= 0 and tile_index < 1024:
		selected_tile = tile_index
		tile_clicked.emit(tile_index)
		queue_redraw()

## Get tile index at screen position
func _get_tile_at_position(pos: Vector2) -> int:
	var col = int(pos.x / tile_display_size.x)
	var row = int(pos.y / tile_display_size.y)
	
	if col >= 0 and col < tiles_per_row and row >= 0 and row < 32:
		return row * tiles_per_row + col
	
	return -1

## Get tile position from index
func _get_tile_position(tile_index: int) -> Vector2:
	var col = tile_index % tiles_per_row
	var row = tile_index / tiles_per_row
	return Vector2(col * tile_display_size.x, row * tile_display_size.y)

## Set selected tile externally
func set_selected_tile(tile_index: int):
	if tile_index >= 0 and tile_index < 1024:
		selected_tile = tile_index
		queue_redraw()

## Get selected tile
func get_selected_tile() -> int:
	return selected_tile

## Get hovered tile
func get_hovered_tile() -> int:
	return hovered_tile if is_hovering else -1

## Get tile information for display
func get_tile_info(tile_index: int) -> Dictionary:
	var info = {
		"index": tile_index,
		"atlas_coords": Vector2i(tile_index % 32, tile_index / 32),
		"animated": false,
		"terrain_type": 0,
		"terrain_name": "Unknown"
	}
	
	if tileset_data:
		info.animated = tileset_data.is_tile_animated(tile_index)
		info.terrain_type = tileset_data.get_terrain_type(tile_index)
		
		var terrain_data = AssetManager.get_terrain_data(info.terrain_type)
		if terrain_data:
			info.terrain_name = terrain_data.name
	
	return info

## Scroll to show a specific tile
func scroll_to_tile(tile_index: int):
	var tile_pos = _get_tile_position(tile_index)
	var parent_scroll = get_parent()
	
	if parent_scroll is ScrollContainer:
		var scroll_container = parent_scroll as ScrollContainer
		var viewport_size = scroll_container.size
		
		# Center the tile in the viewport
		var target_scroll = tile_pos - viewport_size / 2
		target_scroll = target_scroll.max(Vector2.ZERO)
		
		scroll_container.scroll_offset = target_scroll

## Set display size for tiles
func set_tile_display_size(size: Vector2i):
	tile_display_size = size
	custom_minimum_size = Vector2(tiles_per_row * tile_display_size.x, 32 * tile_display_size.y)
	queue_redraw()

## Toggle terrain info display
func set_show_terrain_info(show: bool):
	show_terrain_info = show
	queue_redraw()

## Toggle animation indicators
func set_show_animation_indicators(show: bool):
	show_animation_indicators = show
	queue_redraw()

## Get tiles by terrain type
func get_tiles_by_terrain(terrain_type: int) -> Array[int]:
	if not tileset_data:
		return []
	
	return tileset_data.get_tiles_with_terrain(terrain_type)

## Get animated tiles
func get_animated_tiles() -> Array[int]:
	var animated: Array[int] = []
	
	if tileset_data:
		for i in range(1024):
			if tileset_data.is_tile_animated(i):
				animated.append(i)
	
	return animated

## Filter tiles by criteria
func filter_tiles(criteria: Dictionary) -> Array[int]:
	var filtered: Array[int] = []
	
	if not tileset_data:
		return filtered
	
	for i in range(1024):
		var matches = true
		
		# Check terrain type filter
		if "terrain_type" in criteria:
			var tile_terrain = tileset_data.get_terrain_type(i)
			if tile_terrain != criteria.terrain_type:
				matches = false
		
		# Check animation filter
		if "animated" in criteria:
			var is_animated = tileset_data.is_tile_animated(i)
			if is_animated != criteria.animated:
				matches = false
		
		# Check passable filter
		if "passable" in criteria and "faction" in criteria and "unit_type" in criteria:
			var terrain_id = tileset_data.get_terrain_type(i)
			var terrain = AssetManager.get_terrain_data(terrain_id)
			if terrain:
				var is_passable = terrain.is_passable(criteria.faction, criteria.unit_type)
				if is_passable != criteria.passable:
					matches = false
		
		if matches:
			filtered.append(i)
	
	return filtered

func _on_mouse_entered():
	is_hovering = true

func _on_mouse_exited():
	is_hovering = false
	hovered_tile = -1
	queue_redraw()

## Get tileset statistics for display
func get_tileset_stats() -> Dictionary:
	if not tileset_data:
		return {}
	
	return tileset_data.get_stats()
