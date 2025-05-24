## Settings Manager
##
## Manages user preferences and application settings.
## Settings are automatically saved and loaded.
extends Node

# Settings file path
const SETTINGS_FILE = "user://fe_map_creator_settings.cfg"

# Default settings
var default_settings = {
	"general": {
		"fe_data_path": "",
		"recent_files": [],
		"max_recent_files": 10,
		"auto_save_interval": 300, # seconds
		"auto_save_enabled": true
	},
	"editor": {
		"default_map_width": 20,
		"default_map_height": 15,
		"default_tool": EventBus.EditorTool.PAINT,
		"show_grid": true,
		"grid_color": Color.WHITE,
		"grid_opacity": 0.3,
		"zoom_speed": 1.2,
		"min_zoom": 0.1,
		"max_zoom": 8.0,
		"pan_speed": 1.0
	},
	"ui": {
		"tileset_panel_width": 300,
		"terrain_inspector_height": 200,
		"show_tooltips": true,
		"animation_enabled": true,
		"animation_speed": 1.0
	},
	"export": {
		"default_format": "map",
		"export_path": "",
		"include_metadata": true
	}
}

# Current settings
var settings = {}

# Config object
var config: ConfigFile

func _ready():
	config = ConfigFile.new()
	load_settings()

## Load settings from file
func load_settings():
	settings = default_settings.duplicate(true)
	
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		print("Settings file not found, using defaults")
		save_settings()
		return
	
	# Load each section
	for section_name in default_settings.keys():
		if not config.has_section(section_name):
			continue
			
		for key in default_settings[section_name].keys():
			if config.has_section_key(section_name, key):
				settings[section_name][key] = config.get_value(section_name, key)
	
	print("Settings loaded from: ", SETTINGS_FILE)

## Save settings to file
func save_settings():
	# Write all settings to config
	for section_name in settings.keys():
		for key in settings[section_name].keys():
			config.set_value(section_name, key, settings[section_name][key])
	
	var err = config.save(SETTINGS_FILE)
	if err != OK:
		push_error("Failed to save settings: " + str(err))
	else:
		print("Settings saved to: ", SETTINGS_FILE)

## Get a setting value
func get_setting(section: String, key: String, default_value = null):
	if section in settings and key in settings[section]:
		return settings[section][key]
	return default_value

## Set a setting value
func set_setting(section: String, key: String, value):
	if not section in settings:
		settings[section] = {}
	
	settings[section][key] = value
	save_settings()
	
	# Emit settings changed event
	EventBus.emit_settings_changed(settings)

## Get FE data path
func get_fe_data_path() -> String:
	return get_setting("general", "fe_data_path", "")

## Set FE data path
func set_fe_data_path(path: String):
	set_setting("general", "fe_data_path", path)

## Get recent files list
func get_recent_files() -> Array[String]:
	var recent = get_setting("general", "recent_files", [])
	var result: Array[String] = []
	for item in recent:
		result.append(str(item))
	return result

## Add file to recent files
func add_recent_file(file_path: String):
	var recent_files = get_recent_files()
	var max_files = get_setting("general", "max_recent_files", 10)
	
	# Remove if already exists
	if file_path in recent_files:
		recent_files.erase(file_path)
	
	# Add to beginning
	recent_files.insert(0, file_path)
	
	# Trim to max size
	while recent_files.size() > max_files:
		recent_files.pop_back()
	
	set_setting("general", "recent_files", recent_files)
	EventBus.recent_files_updated.emit(recent_files)

## Get default map dimensions
func get_default_map_size() -> Vector2i:
	var width = get_setting("editor", "default_map_width", 20)
	var height = get_setting("editor", "default_map_height", 15)
	return Vector2i(width, height)

## Set default map dimensions
func set_default_map_size(size: Vector2i):
	set_setting("editor", "default_map_width", size.x)
	set_setting("editor", "default_map_height", size.y)

## Get default tool
func get_default_tool() -> EventBus.EditorTool:
	return get_setting("editor", "default_tool", EventBus.EditorTool.PAINT)

## Set default tool
func set_default_tool(tool: EventBus.EditorTool):
	set_setting("editor", "default_tool", tool)

## Get grid settings
func get_grid_visible() -> bool:
	return get_setting("editor", "show_grid", true)

func set_grid_visible(visible: bool):
	set_setting("editor", "show_grid", visible)

func get_grid_color() -> Color:
	return get_setting("editor", "grid_color", Color.WHITE)

func set_grid_color(color: Color):
	set_setting("editor", "grid_color", color)

func get_grid_opacity() -> float:
	return get_setting("editor", "grid_opacity", 0.3)

func set_grid_opacity(opacity: float):
	set_setting("editor", "grid_opacity", opacity)

## Get zoom settings
func get_zoom_speed() -> float:
	return get_setting("editor", "zoom_speed", 1.2)

func get_min_zoom() -> float:
	return get_setting("editor", "min_zoom", 0.1)

func get_max_zoom() -> float:
	return get_setting("editor", "max_zoom", 8.0)

func get_pan_speed() -> float:
	return get_setting("editor", "pan_speed", 1.0)

## Get UI settings
func get_tileset_panel_width() -> int:
	return get_setting("ui", "tileset_panel_width", 300)

func set_tileset_panel_width(width: int):
	set_setting("ui", "tileset_panel_width", width)

func get_terrain_inspector_height() -> int:
	return get_setting("ui", "terrain_inspector_height", 200)

func set_terrain_inspector_height(height: int):
	set_setting("ui", "terrain_inspector_height", height)

func get_show_tooltips() -> bool:
	return get_setting("ui", "show_tooltips", true)

func set_show_tooltips(show: bool):
	set_setting("ui", "show_tooltips", show)

## Get animation settings
func get_animation_enabled() -> bool:
	return get_setting("ui", "animation_enabled", true)

func set_animation_enabled(enabled: bool):
	set_setting("ui", "animation_enabled", enabled)

func get_animation_speed() -> float:
	return get_setting("ui", "animation_speed", 1.0)

func set_animation_speed(speed: float):
	set_setting("ui", "animation_speed", speed)

## Get auto-save settings
func get_auto_save_enabled() -> bool:
	return get_setting("general", "auto_save_enabled", true)

func set_auto_save_enabled(enabled: bool):
	set_setting("general", "auto_save_enabled", enabled)

func get_auto_save_interval() -> int:
	return get_setting("general", "auto_save_interval", 300)

func set_auto_save_interval(seconds: int):
	set_setting("general", "auto_save_interval", seconds)

## Get export settings
func get_default_export_format() -> String:
	return get_setting("export", "default_format", "map")

func set_default_export_format(format: String):
	set_setting("export", "default_format", format)

func get_export_path() -> String:
	return get_setting("export", "export_path", "")

func set_export_path(path: String):
	set_setting("export", "export_path", path)

## Reset all settings to defaults
func reset_to_defaults():
	settings = default_settings.duplicate(true)
	save_settings()
	EventBus.emit_settings_changed(settings)

## Get all settings (for debugging/export)
func get_all_settings() -> Dictionary:
	return settings.duplicate(true)

## Import settings from dictionary
func import_settings(imported_settings: Dictionary):
	# Merge with current settings
	for section in imported_settings.keys():
		if section in settings:
			for key in imported_settings[section].keys():
				if key in settings[section]:
					settings[section][key] = imported_settings[section][key]
	
	save_settings()
	EventBus.emit_settings_changed(settings)

## Get settings summary for display
func get_settings_summary() -> Dictionary:
	return {
		"FE Data Path": get_fe_data_path(),
		"Recent Files": get_recent_files().size(),
		"Default Map Size": "%dx%d" % [get_default_map_size().x, get_default_map_size().y],
		"Grid Visible": get_grid_visible(),
		"Animation Enabled": get_animation_enabled(),
		"Auto-save Enabled": get_auto_save_enabled()
	}
