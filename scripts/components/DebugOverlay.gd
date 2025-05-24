## Debug Overlay
##
## Displays debugging information and system statistics during development.
## Can be toggled on/off and shows performance metrics, system status, etc.
extends CanvasLayer

# UI References
@onready var debug_panel: Panel = $DebugPanel
@onready var debug_label: RichTextLabel = $DebugPanel/VBoxContainer/DebugLabel
@onready var toggle_button: Button = $ToggleButton

# Debug state
var is_visible: bool = false
var update_interval: float = 0.5
var time_accumulator: float = 0.0

# References to systems we want to debug
var map_canvas: MapCanvas
var current_map: FEMap
var animation_system: TileAnimationSystem

func _ready():
	# Set up UI
	debug_panel.visible = false
	toggle_button.text = "Debug"
	toggle_button.pressed.connect(_toggle_debug)
	
	# Connect to EventBus for system updates
	EventBus.map_loaded.connect(_on_map_loaded)
	
	# Position debug panel
	debug_panel.position = Vector2(10, 50)
	debug_panel.size = Vector2(350, 400)
	
	print("Debug overlay ready - Press F3 or click Debug button to toggle")

func _input(event: InputEvent):
	if event.is_action_pressed("toggle_debug"):
		_toggle_debug()

func _process(delta: float):
	if not is_visible:
		return
	
	time_accumulator += delta
	if time_accumulator >= update_interval:
		_update_debug_display()
		time_accumulator = 0.0

## Toggle debug overlay visibility
func _toggle_debug():
	is_visible = !is_visible
	debug_panel.visible = is_visible
	
	if is_visible:
		_update_debug_display()

## Set references to systems we want to debug
func set_debug_targets(canvas: MapCanvas, anim_sys: TileAnimationSystem = null):
	map_canvas = canvas
	animation_system = anim_sys
	
	if map_canvas:
		current_map = map_canvas.get_current_map()

## Update debug display with current information
func _update_debug_display():
	var debug_text = "[b]FE Map Creator Debug[/b]\n\n"
	
	# System Status
	debug_text += "[color=yellow]System Status:[/color]\n"
	debug_text += "FPS: %d\n" % Engine.get_frames_per_second()
	debug_text += "Memory: %.1f MB\n" % (OS.get_static_memory_usage() / 1024.0 / 1024.0)
	debug_text += "AssetManager: %s\n" % ("Ready" if AssetManager.is_ready() else "Not Ready")
	
	var asset_status = AssetManager.get_status()
	debug_text += "Terrain Types: %d\n" % asset_status.terrain_count
	debug_text += "Tilesets: %d\n" % asset_status.tileset_count
	debug_text += "Textures: %d\n\n" % asset_status.texture_count
	
	# Map Information
	debug_text += "[color=yellow]Current Map:[/color]\n"
	if current_map:
		debug_text += "Name: %s\n" % current_map.name
		debug_text += "Size: %dx%d\n" % [current_map.width, current_map.height]
		debug_text += "Tileset: %s\n" % current_map.tileset_id
		debug_text += "Total Tiles: %d\n" % current_map.tile_data.size()
		
		var validation = MapValidator.validate_map(current_map)
		debug_text += "Validation: %s\n" % ("PASS" if validation.is_valid else "FAIL")
		if validation.issues.size() > 0:
			debug_text += "Issues: %d\n" % validation.issues.size()
	else:
		debug_text += "No map loaded\n"
	
	debug_text += "\n"
	
	# MapCanvas Information
	debug_text += "[color=yellow]Map Canvas:[/color]\n"
	if map_canvas:
		var zoom_info = map_canvas.get_zoom_info()
		debug_text += "Zoom: %.0f%%\n" % (zoom_info.current * 100)
		debug_text += "Tool: %s\n" % EventBus.get_tool_name(map_canvas.get_current_tool())
		debug_text += "Selected Tile: %d\n" % map_canvas.get_selected_tile()
		debug_text += "Grid Visible: %s\n" % str(map_canvas.show_grid)
	else:
		debug_text += "No canvas available\n"
	
	debug_text += "\n"
	
	# Animation System
	debug_text += "[color=yellow]Animations:[/color]\n"
	if animation_system:
		var anim_stats = animation_system.get_animation_stats()
		debug_text += "Enabled: %s\n" % str(anim_stats.enabled)
		debug_text += "Speed: %.1fx\n" % anim_stats.speed
		debug_text += "Animated Tiles: %d\n" % anim_stats.animated_tiles
		debug_text += "Animation Groups: %d\n" % anim_stats.animation_groups
		
		var perf_metrics = animation_system.get_performance_metrics()
		debug_text += "Performance: %s\n" % perf_metrics.performance_level
	else:
		debug_text += "No animation system\n"
	
	debug_text += "\n"
	
	# Performance Metrics
	debug_text += "[color=yellow]Performance:[/color]\n"
	#debug_text += "Process Time: %.2fms\n" % (Engine.get_process_frame_time() * 1000)
	#debug_text += "Physics Time: %.2fms\n" % (Engine.get_physics_frame_time() * 1000)
	
	# Godot version info
	debug_text += "\n[color=gray]Godot %s[/color]" % Engine.get_version_info().string
	
	debug_label.text = debug_text

## Handle map loaded events
func _on_map_loaded(map: FEMap):
	current_map = map

## Get debug information as dictionary (for external use)
func get_debug_info() -> Dictionary:
	var info = {}
	
	info["system"] = {
		"fps": Engine.get_frames_per_second(),
		"memory_mb": OS.get_static_memory_usage() / 1024.0 / 1024.0,
		"asset_manager_ready": AssetManager.is_ready()
	}
	
	if AssetManager.is_ready():
		info["assets"] = AssetManager.get_status()
	
	if current_map:
		info["map"] = {
			"name": current_map.name,
			"size": [current_map.width, current_map.height],
			"tileset": current_map.tileset_id,
			"tile_count": current_map.tile_data.size()
		}
		
		var validation = MapValidator.validate_map(current_map)
		info["map"]["validation"] = {
			"valid": validation.is_valid,
			"issues": validation.issues.size()
		}
	
	if map_canvas:
		var zoom_info = map_canvas.get_zoom_info()
		info["canvas"] = {
			"zoom": zoom_info.current,
			"tool": EventBus.get_tool_name(map_canvas.get_current_tool()),
			"selected_tile": map_canvas.get_selected_tile(),
			"grid_visible": map_canvas.show_grid
		}
	
	if animation_system:
		info["animations"] = animation_system.get_animation_stats()
		info["animation_performance"] = animation_system.get_performance_metrics()
	
	return info

## Export debug info to file
func export_debug_info(file_path: String):
	var debug_info = get_debug_info()
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		file.store_string(JSON.stringify(debug_info, "\t"))
		file.close()
		print("Debug info exported to: ", file_path)
	else:
		print("Failed to export debug info")

## Set update interval for debug display
func set_update_interval(interval: float):
	update_interval = clamp(interval, 0.1, 5.0)

## Add custom debug information
func add_custom_debug_info(section_name: String, info_dict: Dictionary):
	# This could be used by other systems to add their debug info
	pass

## Show debug console with interactive commands
func show_debug_console():
	# This could open a simple console for debug commands
	print("Debug console not implemented yet")

## Quick performance test
func run_performance_test():
	print("=== Performance Test ===")
	
	var start_time = Time.get_time_dict_from_system()
	
	# Test map generation
	if AssetManager.is_ready():
		var tileset_ids = AssetManager.get_tileset_ids()
		if not tileset_ids.is_empty():
			var params = MapGenerator.create_preset("small_skirmish", tileset_ids[0])
			var test_map = MapGenerator.generate_map(params)
			
			if test_map:
				print("✓ Map generation: PASS")
				
				# Test validation
				var validation = MapValidator.validate_map(test_map)
				print("✓ Map validation: %s" % ("PASS" if validation.is_valid else "FAIL"))
			else:
				print("✗ Map generation: FAIL")
	
	var end_time = Time.get_time_dict_from_system()
	var duration = end_time.seconds - start_time.seconds
	print("Performance test completed in %.3f seconds" % duration)
