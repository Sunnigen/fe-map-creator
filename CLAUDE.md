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
# - GenerationData.gd (3-section .dat file parser)

# Always check AssetManager.is_ready() before accessing data
if AssetManager.is_ready():
	var terrain = AssetManager.get_terrain_data(terrain_id)
	var gen_data = AssetManager.get_generation_data(tileset_id)
```

## Essential Systems

### Map Generation - Enhanced Integration Approach
```gdscript
# scripts/tools/MapGenerator.gd - Enhanced tile selection
var params = MapGenerator.GenerationParams.new()
params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
params.map_theme = MapGenerator.MapTheme.FOREST
params.depth_complexity = 0.5  # Terrain variety (DepthUpDown parameter)
params.feature_spacing = 3.0   # Feature distribution (DistUpDown parameter)
var generated_map = MapGenerator.generate_map(params)

# Enhanced AutotilingDatabase integration:
# scripts/resources/AutotilingDatabase.gd
func get_intelligent_tile(terrain_id: int, neighbors: Dictionary, generation_data: GenerationData) -> int:
	# 1. Get candidates from existing patterns
	var candidates = get_tiles_for_context(terrain_id, neighbors)
	# 2. Apply 8 validation methods from Section 2
	candidates = apply_validation_rules(candidates, neighbors, generation_data)
	# 3. Apply priorities and identical tiles from Section 3
	return select_by_priority(candidates, generation_data)

# Current vs Target:
# CURRENT: Basic generation + existing pattern matching (~5-10 tiles)
# TARGET: Sophisticated generation + 3-section validation (~100+ tiles like original)
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

## Original FEMapCreator Algorithm Analysis

Based on reverse engineering of the original .NET executable, the generation was much more sophisticated than initially thought:

### Two-Phase Generation Process
1. **`generate_map()`** - Sophisticated terrain layout using depth/distance parameters + 8-method tile validation
2. **`repair_map()`** - Separate manual tool for fixing hand-edited maps (not part of generation)

### Key Generation Components Found
**Core Algorithm:**
- `Generation_Data` + `get_generation_data` - Core algorithm configuration
- `Identical_Tiles` + `get_identical_tiles` - Tile variety management
- 8 different `<valid_tiles>b__XX` methods - Complex validation system
- `tile_priorities` + `tile_priority` - Aesthetic weighting for tile selection

**UI Parameters:**
- `WidthUpDown`, `HeightUpDown` - Map dimensions
- `DepthUpDown` - Terrain variety complexity
- `DistUpDown` - Feature spacing/distribution

**Validation System:**
- `is_open_tile`, `test_valid_tiles` - Quality checking
- `matching_corners`, `matching_sides` - Edge compatibility (editor features)

### Binary Data Files (.dat) - Complex 3-Section Structure
The .dat files (14KB-351KB) contain sophisticated generation data in THREE sections:

**Section 1: Tile-Terrain Mappings**
- First 4 bytes: tile mapping count
- Each 4 bytes: [tile_id:2bytes][terrain_id:2bytes]
- Basic categorization of tiles by terrain type

**Section 2: Generation/Validation Rules** 
- Variable length rule data encoding the 8 validation methods
- Complex algorithms for intelligent tile selection
- Transition rules for proper terrain boundaries

**Section 3: Priority/Pattern Data**
- Tile priority weighting for aesthetic preferences
- Identical_Tiles groupings for variation management
- Position-based selection parameters

### Key Insights from Multi-Agent Analysis

**Three-Agent Investigation Revealed:**
1. **.dat files have 3-section structure** - tile mappings, validation rules, priorities
2. **Original maps use 100+ unique tiles** - evidence of sophisticated selection
3. **Identical_Tiles system confirmed** - deliberate variation patterns in uniform areas
4. **8 validation methods encoded in Section 2** - complex transition algorithms
5. **Tile priorities in Section 3** - aesthetic weighting system

**Architecture Decision:** Enhance existing AutotilingDatabase rather than separate classes

The original was "intelligent terrain layout + ultra-sophisticated tile selection using 3-section generation data". We were only using ~1% of the actual generation intelligence!

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
