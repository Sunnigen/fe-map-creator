## Tile Animation System
##
## Handles animated tiles like water, lava, torches, etc.
## Updates tile frames based on timing and animation data.
class_name TileAnimationSystem
extends Node

# Animation state
var animated_tilemap: TileMap
var current_tileset_data: FETilesetData
var animation_enabled: bool = true
var animation_speed: float = 1.0
var global_time: float = 0.0

# Performance settings
var update_frequency: float = 1.0 / 15.0  # 15 FPS for animations
var max_animated_tiles: int = 500  # Limit for performance
var time_accumulator: float = 0.0

# Animated tile tracking
var animated_positions: Dictionary = {}  # Vector2i -> AnimatedTileData
var animation_groups: Dictionary = {}    # base_tile_index -> Array[Vector2i]

# Signals
signal animation_updated()

func _ready():
	set_process(animation_enabled)

func _process(delta: float):
	if not animation_enabled or not animated_tilemap or not current_tileset_data:
		return
	
	time_accumulator += delta * animation_speed
	
	if time_accumulator >= update_frequency:
		global_time += time_accumulator
		update_animations()
		time_accumulator = 0.0

## Initialize with a tilemap and tileset data
func initialize(tilemap: TileMap, tileset_data: FETilesetData):
	animated_tilemap = tilemap
	current_tileset_data = tileset_data
	
	# Build animation tracking data
	_build_animation_data()
	
	print("Animation system initialized with %d animation groups" % tileset_data.animated_tiles.size())

## Build animation tracking from tilemap
func _build_animation_data():
	if not animated_tilemap or not current_tileset_data:
		return
	
	animated_positions.clear()
	animation_groups.clear()
	
	# Scan all tiles in the tilemap
	var used_cells = animated_tilemap.get_used_cells(0)
	var animated_count = 0
	
	for cell_pos in used_cells:
		if animated_count >= max_animated_tiles:
			break
		
		var atlas_coords = animated_tilemap.get_cell_atlas_coords(0, cell_pos)
		var tile_index = atlas_coords.y * 32 + atlas_coords.x
		
		# Check if this tile is animated
		var anim_data = current_tileset_data.get_tile_animation(tile_index)
		if anim_data:
			animated_positions[cell_pos] = anim_data
			
			# Group by base tile index
			if not anim_data.base_tile_index in animation_groups:
				animation_groups[anim_data.base_tile_index] = []
			animation_groups[anim_data.base_tile_index].append(cell_pos)
			
			animated_count += 1
	
	if animated_count == max_animated_tiles:
		print("Warning: Animation limit reached (%d tiles)" % max_animated_tiles)

## Update all animated tiles
func update_animations():
	if not animated_tilemap or animated_positions.is_empty():
		return
	
	var global_frame = int(global_time * 60.0)  # Convert to 60 FPS frame count
	var updated_count = 0
	
	for pos in animated_positions:
		var anim_data = animated_positions[pos]
		var current_tile = anim_data.get_current_tile_index(global_frame)
		
		# Get current tile in tilemap
		var current_atlas_coords = animated_tilemap.get_cell_atlas_coords(0, pos)
		var current_tile_index = current_atlas_coords.y * 32 + current_atlas_coords.x
		
		if current_tile != current_tile_index:
			# Update the tile
			var new_atlas_coords = Vector2i(current_tile % 32, current_tile / 32)
			animated_tilemap.set_cell(0, pos, 0, new_atlas_coords)
			updated_count += 1
	
	if updated_count > 0:
		animation_updated.emit()

## Add a single animated tile at position
func add_animated_tile(pos: Vector2i, tile_index: int):
	if not current_tileset_data:
		return
	
	var anim_data = current_tileset_data.get_tile_animation(tile_index)
	if anim_data:
		animated_positions[pos] = anim_data
		
		# Add to animation group
		if not anim_data.base_tile_index in animation_groups:
			animation_groups[anim_data.base_tile_index] = []
		if not pos in animation_groups[anim_data.base_tile_index]:
			animation_groups[anim_data.base_tile_index].append(pos)

## Remove animated tile at position
func remove_animated_tile(pos: Vector2i):
	if pos in animated_positions:
		var anim_data = animated_positions[pos]
		animated_positions.erase(pos)
		
		# Remove from animation group
		if anim_data.base_tile_index in animation_groups:
			animation_groups[anim_data.base_tile_index].erase(pos)
			if animation_groups[anim_data.base_tile_index].is_empty():
				animation_groups.erase(anim_data.base_tile_index)

## Enable or disable animations
func set_animation_enabled(enabled: bool):
	animation_enabled = enabled
	set_process(enabled)
	
	if not enabled:
		# Reset all animated tiles to their base frame
		_reset_to_base_frames()

## Set animation speed multiplier
func set_animation_speed(speed: float):
	animation_speed = clamp(speed, 0.1, 5.0)

## Reset all animated tiles to their base frames
func _reset_to_base_frames():
	if not animated_tilemap:
		return
	
	for pos in animated_positions:
		var anim_data = animated_positions[pos]
		var base_atlas_coords = Vector2i(anim_data.base_tile_index % 32, anim_data.base_tile_index / 32)
		animated_tilemap.set_cell(0, pos, 0, base_atlas_coords)

## Get animation statistics
func get_animation_stats() -> Dictionary:
	return {
		"enabled": animation_enabled,
		"speed": animation_speed,
		"animated_tiles": animated_positions.size(),
		"animation_groups": animation_groups.size(),
		"global_time": global_time,
		"update_frequency": update_frequency
	}

## Synchronize animations (reset timing)
func synchronize_animations():
	global_time = 0.0
	time_accumulator = 0.0

## Set update frequency (lower = better performance, choppier animation)
func set_update_frequency(frequency: float):
	update_frequency = clamp(frequency, 1.0/60.0, 1.0/5.0)  # 60 FPS to 5 FPS

## Get all animated positions for debugging
func get_animated_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for pos in animated_positions.keys():
		positions.append(pos)
	return positions

## Check if position has animated tile
func is_position_animated(pos: Vector2i) -> bool:
	return pos in animated_positions

## Get animation data for position
func get_animation_at_position(pos: Vector2i) -> AnimatedTileData:
	return animated_positions.get(pos, null)

## Create staggered animation offsets for variety
func create_staggered_offsets():
	if animation_groups.is_empty():
		return
	
	# Add random start delays to create variety
	for base_tile in animation_groups:
		var positions = animation_groups[base_tile]
		
		for i in range(positions.size()):
			var pos = positions[i]
			if pos in animated_positions:
				var anim_data = animated_positions[pos]
				
				# Create a copy with offset
				var offset_anim = anim_data.create_offset_copy(i * 5)  # 5 frame stagger
				animated_positions[pos] = offset_anim

## Optimize performance by culling off-screen animations
func optimize_for_viewport(viewport_rect: Rect2):
	if not animated_tilemap:
		return
	
	var visible_positions = {}
	var culled_count = 0
	
	# Check which animated tiles are visible
	for pos in animated_positions:
		var world_pos = animated_tilemap.map_to_local(pos)
		if viewport_rect.has_point(world_pos):
			visible_positions[pos] = animated_positions[pos]
		else:
			culled_count += 1
	
	if culled_count > 0:
		print("Culled %d off-screen animated tiles" % culled_count)
		animated_positions = visible_positions
		
		# Rebuild animation groups
		animation_groups.clear()
		for pos in animated_positions:
			var anim_data = animated_positions[pos]
			if not anim_data.base_tile_index in animation_groups:
				animation_groups[anim_data.base_tile_index] = []
			animation_groups[anim_data.base_tile_index].append(pos)

## Force immediate animation update
func force_update():
	update_animations()

## Get performance metrics
func get_performance_metrics() -> Dictionary:
	return {
		"animated_tiles_count": animated_positions.size(),
		"animation_groups_count": animation_groups.size(),
		"max_tiles_limit": max_animated_tiles,
		"update_frequency_hz": 1.0 / update_frequency,
		"memory_usage_estimate": animated_positions.size() * 32,  # Rough estimate
		"performance_level": _get_performance_level()
	}

## Get performance level assessment
func _get_performance_level() -> String:
	var tile_count = animated_positions.size()
	
	if tile_count <= 50:
		return "Excellent"
	elif tile_count <= 150:
		return "Good"
	elif tile_count <= 300:
		return "Fair"
	elif tile_count <= 500:
		return "Poor"
	else:
		return "Critical"
