# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4.3+ project that recreates the Fire Emblem Map Creator tool for creating tactical battle maps using authentic Fire Emblem assets from the GBA trilogy (FE6, FE7, FE8). The project implements a complete map editing suite with procedural generation, asset conversion, and validation systems.

## Key Commands

### Running the Project
```bash
# Open in Godot Editor
godot project.godot

# Run main test scene (default)
godot --main-pack scenes/main/Main.tscn

# Run editor scene directly  
godot --main-pack scenes/main/Editor.tscn
```

### Testing
```gdscript
# In Main test scene, use these buttons:
# - "Initialize AssetManager" - loads FE data and converts assets
# - "Run All Tests" - comprehensive test suite via TestRunner
# - "Quick Demo" - basic functionality verification
# - "Generate Maps" - test procedural generation

# Individual test scenes (run directly):
# - TestMapGeneration.tscn - map generation tests
# - DebugAssetManager.tscn - asset loading tests
# - Phase1Verification.tscn - system verification
```

### Debug Tools
```gdscript
# F3 - Toggle debug overlay (performance metrics, memory usage)
# G - Toggle grid display in editor
# F12 - Output validation results to console
```

## Architecture Overview

### Three-Layer Autoload System
```gdscript
# scripts/autoload/AssetManager.gd - Core data conversion and asset management
AssetManager.initialize(fe_data_path)  # Must be called first
AssetManager.get_terrain_data(terrain_id)
AssetManager.get_tileset_data(tileset_id)

# scripts/autoload/EventBus.gd - Global event communication
EventBus.editor_ready.emit()
EventBus.map_loaded.connect(callback)

# scripts/autoload/Settings.gd - User preferences and configuration
Settings.get_setting("ui_theme", "default")
```

### Core Data Flow
```
FEMapCreator XML/PNG → AssetManager → Godot Resources → Editor Components → Export
	   ↓                    ↓              ↓               ↓             ↓
• Terrain_Data.xml    • Parse/Convert  • TerrainData    • Visual Edit  • .map
• Tileset_Data.xml    • Validate       • FETilesetData  • Tools        • .tscn
• PNG Tilesets        • Generate       • TileSet        • Animation    • .json
• .map Files          • Cache          • Texture2D      • Validation   
```

### Resource Management Pattern
```gdscript
# All custom resources extend Godot's Resource class:
# - FEMap.gd (map data structure)
# - TerrainData.gd (gameplay properties) 
# - FETilesetData.gd (tileset metadata)
# - AnimatedTileData.gd (animation sequences)

# Always check AssetManager.is_ready() before accessing data
if AssetManager.is_ready():
	var terrain = AssetManager.get_terrain_data(terrain_id)
```

## Essential Systems

### Map Generation
```gdscript
# scripts/tools/MapGenerator.gd
var params = MapGenerator.GenerationParams.new()
params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
params.map_theme = MapGenerator.MapTheme.FOREST
var generated_map = MapGenerator.generate_map(params)
```

### Testing Framework
```gdscript
# scripts/tools/TestRunner.gd
var test_runner = TestRunner.new()
test_runner.run_all_tests()  # Comprehensive test suite
test_runner.run_tests(TestRunner.TestCategory.ASSET_LOADING)
```

### File I/O
```gdscript
# scripts/managers/MapIO.gd
var map = MapIO.load_map(file_path)
MapIO.save_map(map, output_path)
var available_maps = MapIO.get_available_maps(fe_data_path)
```

### Validation System
```gdscript
# scripts/managers/MapValidator.gd
var validation = MapValidator.validate_map(map)
if validation.has_critical_issues():
	MapValidator.auto_fix_map(map, validation.issues)
```

## Data Path Configuration

The project requires original FEMapCreator data. Set the path in Main.gd or Editor.gd:

```gdscript
# Expected structure:
fe_data_path/
├── Terrain_Data.xml        # Terrain properties and movement costs
├── Tileset_Data.xml        # Tileset metadata and tile mappings  
├── FE6 Maps/              # Game-specific map collections
├── FE7 Maps/
├── FE8 Maps/
└── Tilesets/              # PNG tileset images
	├── FE6 - Plains - 01020304.png
	├── FE7 - Castle - 0a000b0c.png
	└── FE8 - Fields - 01000203.png
```

## Editor Tools & Input Map

### Keyboard Shortcuts (defined in project.godot)
```
B - Paint tool
F - Fill tool  
S - Select tool
I - Eyedropper tool
G - Toggle grid
F3 - Toggle debug overlay
Ctrl+Z/Y - Undo/Redo
```

### Scene Structure
```
scenes/main/Editor.tscn - Main map editor interface
├── TilesetPanel - Tile selection and search
├── MapCanvas - Primary editing viewport with tools
├── TerrainInspector - Terrain properties and statistics  
└── Dialogs/ - Map properties and generation dialogs
```

## Animation System

The TileAnimationSystem handles animated tiles (water, lava, torches):

```gdscript
# scripts/components/TileAnimationSystem.gd
var animation_system = TileAnimationSystem.new()
animation_system.initialize(tilemap, tileset_data)
animation_system.set_animation_speed(1.5)  # Viewport culling automatic
```

## Development Patterns

### Error Handling
Always check AssetManager initialization before accessing data. Use validation for maps before export.

### Performance
- Animation system automatically culls off-screen tiles
- Large maps use viewport culling and LOD
- Debug overlay monitors memory usage and performance

### Testing
Run TestRunner.run_all_tests() frequently during development. Individual test scenes available for specific components.

### Resource Generation
Tilesets and animations are generated automatically from PNG files during AssetManager.initialize(). Generated resources are cached for performance.
