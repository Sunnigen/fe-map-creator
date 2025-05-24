## Animated Tile Data Resource
##
## Defines animation properties for tiles like water, lava, torches, etc.
@tool
class_name AnimatedTileData  
extends Resource

## Number of frames in the animation cycle
@export var frame_count: int = 1

## Delay before animation starts (in frames at 60 FPS)
@export var start_delay: int = 0

## Duration each frame is displayed (in frames at 60 FPS)
@export var frame_duration: int = 1

## Starting tile index in the tileset (0-1023)
@export var base_tile_index: int = 0

## Animation name for debugging/identification
@export var name: String = ""

## Current animation time for this tile
var current_time: int = 0

## Gets the current tile index based on global animation time
func get_current_tile_index(global_time: int) -> int:
	# Account for start delay
	if global_time < start_delay:
		return base_tile_index
		
	# Calculate animation progress
	var anim_time = global_time - start_delay
	var total_duration = frame_count * frame_duration
	
	if total_duration <= 0:
		return base_tile_index
		
	var loop_time = anim_time % total_duration
	
	# Determine current frame
	var frame = loop_time / frame_duration
	return base_tile_index + frame

## Gets the current frame number (0 to frame_count-1)
func get_current_frame(global_time: int) -> int:
	if global_time < start_delay:
		return 0
		
	var anim_time = global_time - start_delay
	var total_duration = frame_count * frame_duration
	
	if total_duration <= 0:
		return 0
		
	var loop_time = anim_time % total_duration
	return loop_time / frame_duration

## Checks if this tile should be animated at the current time
func should_animate(global_time: int) -> bool:
	return global_time >= start_delay and frame_count > 1

## Gets animation progress as a float (0.0 to 1.0)
func get_animation_progress(global_time: int) -> float:
	if global_time < start_delay or frame_count <= 1:
		return 0.0
		
	var anim_time = global_time - start_delay
	var total_duration = frame_count * frame_duration
	
	if total_duration <= 0:
		return 0.0
		
	var loop_time = anim_time % total_duration
	return float(loop_time) / float(total_duration)

## Creates a copy of this animation data with an offset
func create_offset_copy(time_offset: int) -> AnimatedTileData:
	var copy = AnimatedTileData.new()
	copy.frame_count = frame_count
	copy.start_delay = start_delay + time_offset
	copy.frame_duration = frame_duration
	copy.base_tile_index = base_tile_index
	copy.name = name + "_offset"
	return copy

func _to_string() -> String:
	return "AnimatedTile(%s): %d frames, %d delay, %d duration, base %d" % [
		name, frame_count, start_delay, frame_duration, base_tile_index
	]
