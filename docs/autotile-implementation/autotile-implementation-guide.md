# FE Map Creator: Autotiling Intelligence Implementation Guide

## Executive Summary

This document outlines how to extract autotiling intelligence from your existing FEMapCreator data pipeline. Instead of building tile placement rules from scratch, we'll analyze the 300+ professionally designed Fire Emblem maps you already have to learn how tiles should connect naturally.

## The Core Concept

Your existing maps are a **pattern database** - they show every possible way tiles can be arranged correctly. By analyzing these patterns, we can automatically generate maps that look as professional as the originals.

```
Original Perfect Maps → Pattern Analysis → Autotiling Database → Smart Map Generation
```

## Phase 1: Extend Your AssetManager with Pattern Analysis

### 1.1 Add Pattern Data Structures

Add these new classes to your existing resource system:

```gdscript
# scripts/resources/TilePattern.gd
class_name TilePattern
extends Resource

@export var center_terrain: int
@export var neighbor_terrains: Array[int] = []  # 8-directional neighbors
@export var valid_tiles: Array[int] = []        # Tiles that work in this context
@export var frequency: int = 1                  # How often this pattern appears
@export var source_maps: Array[String] = []     # Which maps this pattern came from

func create_signature() -> String:
    # Create unique key for this neighbor pattern
    return str(center_terrain) + "_" + "_".join(neighbor_terrains.map(str))
```

```gdscript
# scripts/resources/AutotilingDatabase.gd  
class_name AutotilingDatabase
extends Resource

@export var patterns: Dictionary = {}           # signature -> TilePattern
@export var terrain_tiles: Dictionary = {}     # terrain_id -> Array[tile_indices]  
@export var tile_relationships: Dictionary = {} # tile_index -> related_tiles
@export var tileset_id: String

func get_best_tile(center_terrain: int, neighbors: Array[int]) -> int:
    var signature = create_neighbor_signature(center_terrain, neighbors)
    
    if signature in patterns:
        var pattern = patterns[signature]
        return pattern.valid_tiles[randi() % pattern.valid_tiles.size()]
    else:
        # Fallback to any tile of the right terrain
        return get_default_tile_for_terrain(center_terrain)

func create_neighbor_signature(center: int, neighbors: Array[int]) -> String:
    return str(center) + "_" + "_".join(neighbors.map(str))
```

### 1.2 Extend FETilesetData

```gdscript
# In scripts/resources/FETilesetData.gd, add:
@export var autotiling_db: AutotilingDatabase
@export var pattern_analysis_complete: bool = false

func get_smart_tile(center_terrain: int, neighbors: Array[int]) -> int:
    if autotiling_db and pattern_analysis_complete:
        return autotiling_db.get_best_tile(center_terrain, neighbors)
    else:
        # Fallback to basic terrain lookup
        return get_basic_tile_for_terrain(center_terrain)
```

## Phase 2: Pattern Extraction Engine

### 2.1 Create Pattern Analyzer

```gdscript
# scripts/tools/PatternAnalyzer.gd
class_name PatternAnalyzer
extends RefCounted

# Main entry point for pattern analysis
static func analyze_all_original_maps(fe_data_path: String) -> Dictionary:
    print("🔍 Starting autotiling pattern analysis...")
    
    var tileset_databases = {}
    
    # Analyze each game's maps
    for game in ["FE6", "FE7", "FE8"]:
        var maps_path = fe_data_path + "/" + game + " Maps/"
        analyze_game_maps(maps_path, tileset_databases)
    
    print("✅ Pattern analysis complete!")
    return tileset_databases

static func analyze_game_maps(maps_path: String, databases: Dictionary):
    var dir = DirAccess.open(maps_path)
    if not dir:
        push_error("Cannot access maps directory: " + maps_path)
        return
    
    # Iterate through tileset folders
    dir.list_dir_begin()
    var folder_name = dir.get_next()
    
    while folder_name != "":
        if dir.current_is_dir():
            var tileset_path = maps_path + folder_name + "/"
            analyze_tileset_maps(tileset_path, folder_name, databases)
        folder_name = dir.get_next()

static func analyze_tileset_maps(tileset_path: String, tileset_id: String, databases: Dictionary):
    print("  📊 Analyzing tileset: ", tileset_id)
    
    if not tileset_id in databases:
        databases[tileset_id] = AutotilingDatabase.new()
        databases[tileset_id].tileset_id = tileset_id
    
    var db = databases[tileset_id]
    var dir = DirAccess.open(tileset_path)
    
    # Process all .map files in this tileset folder
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        if file_name.ends_with(".map"):
            var map_path = tileset_path + file_name
            extract_patterns_from_map(map_path, db)
        file_name = dir.get_next()

static func extract_patterns_from_map(map_path: String, db: AutotilingDatabase):
    # Load map using existing MapIO
    var map = MapIO.load_map_from_file(map_path)
    if not map:
        return
    
    var tileset_data = AssetManager.tileset_data.get(map.tileset_id)
    if not tileset_data:
        return
    
    # Analyze every tile position (except borders)
    for y in range(1, map.height - 1):
        for x in range(1, map.width - 1):
            analyze_tile_context(map, x, y, tileset_data, db, map_path)

static func analyze_tile_context(map: FEMap, x: int, y: int, tileset_data: FETilesetData, db: AutotilingDatabase, source_map: String):
    var center_tile = map.get_tile_at(x, y)
    var center_terrain = get_terrain_id_for_tile(center_tile, tileset_data)
    
    # Get 8-directional neighbors
    var neighbors = []
    var directions = [
        Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),  # NW, N, NE
        Vector2i(-1,  0),                   Vector2i(1,  0),  # W,     E  
        Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)   # SW, S, SE
    ]
    
    for dir in directions:
        var neighbor_tile = map.get_tile_at(x + dir.x, y + dir.y)
        var neighbor_terrain = get_terrain_id_for_tile(neighbor_tile, tileset_data)
        neighbors.append(neighbor_terrain)
    
    # Store this successful pattern
    store_pattern(db, center_terrain, neighbors, center_tile, source_map)

static func get_terrain_id_for_tile(tile_index: int, tileset_data: FETilesetData) -> int:
    if tile_index >= 0 and tile_index < tileset_data.terrain_tags.size():
        return tileset_data.terrain_tags[tile_index]
    return 0  # Default terrain

static func store_pattern(db: AutotilingDatabase, center_terrain: int, neighbors: Array, center_tile: int, source_map: String):
    var signature = create_pattern_signature(center_terrain, neighbors)
    
    if not signature in db.patterns:
        var pattern = TilePattern.new()
        pattern.center_terrain = center_terrain
        pattern.neighbor_terrains = neighbors.duplicate()
        pattern.valid_tiles = []
        pattern.frequency = 0
        pattern.source_maps = []
        db.patterns[signature] = pattern
    
    var pattern = db.patterns[signature]
    
    # Add this tile as a valid option for this pattern
    if not center_tile in pattern.valid_tiles:
        pattern.valid_tiles.append(center_tile)
    
    pattern.frequency += 1
    if not source_map in pattern.source_maps:
        pattern.source_maps.append(source_map)
    
    # Also track which tiles belong to each terrain
    if not center_terrain in db.terrain_tiles:
        db.terrain_tiles[center_terrain] = []
    if not center_tile in db.terrain_tiles[center_terrain]:
        db.terrain_tiles[center_terrain].append(center_tile)

static func create_pattern_signature(center_terrain: int, neighbors: Array) -> String:
    return str(center_terrain) + "_" + "_".join(neighbors.map(str))
```

### 2.2 Integrate Pattern Analysis into AssetManager

```gdscript
# In scripts/autoload/AssetManager.gd, extend the initialize function:

static func initialize(fe_data_path: String):
    print("🚀 Initializing FE Map Creator Asset Manager...")
    
    # Existing initialization
    load_terrain_data(fe_data_path + "/Terrain_Data.xml")
    load_tileset_data(fe_data_path + "/Tileset_Data.xml") 
    convert_png_tilesets(fe_data_path + "/Tilesets/")
    
    # NEW: Extract autotiling intelligence from original maps
    extract_autotiling_patterns(fe_data_path)
    
    print("✅ AssetManager initialization complete!")

static func extract_autotiling_patterns(fe_data_path: String):
    print("🧠 Extracting autotiling intelligence from original maps...")
    
    # Analyze all original maps to build pattern databases
    var pattern_databases = PatternAnalyzer.analyze_all_original_maps(fe_data_path)
    
    # Integrate pattern databases into tileset data
    for tileset_id in pattern_databases:
        if tileset_id in tileset_data:
            tileset_data[tileset_id].autotiling_db = pattern_databases[tileset_id]
            tileset_data[tileset_id].pattern_analysis_complete = true
            
            print("  📚 Tileset %s: %d patterns extracted" % [tileset_id, pattern_databases[tileset_id].patterns.size()])
    
    # Save pattern databases as resources for future use
    save_pattern_databases(pattern_databases)

static func save_pattern_databases(databases: Dictionary):
    var patterns_dir = "res://resources/autotiling_patterns/"
    
    # Create directory if needed
    if not DirAccess.dir_exists_absolute(patterns_dir):
        DirAccess.open("res://").make_dir_recursive(patterns_dir)
    
    # Save each database as a .tres resource
    for tileset_id in databases:
        var save_path = patterns_dir + tileset_id + "_patterns.tres"
        var error = ResourceSaver.save(databases[tileset_id], save_path)
        
        if error == OK:
            print("  💾 Saved patterns: ", save_path)
        else:
            push_error("Failed to save pattern database: " + save_path)
```

## Phase 3: Smart Map Generation Integration

### 3.1 Upgrade MapGenerator with Pattern Intelligence

```gdscript
# In scripts/tools/MapGenerator.gd, replace random tile placement:

class_name MapGenerator
extends RefCounted

# Enhanced generation that uses autotiling patterns
static func generate_map(params: Dictionary) -> FEMap:
    var map = FEMap.new()
    map.width = params.get("width", 20)
    map.height = params.get("height", 15) 
    map.tileset_id = params.get("tileset_id", "01000703")
    map.tile_data = []
    
    # Initialize with default terrain
    map.tile_data.resize(map.width * map.height)
    map.tile_data.fill(0)
    
    # Generate terrain layout (high-level planning)
    generate_terrain_layout(map, params)
    
    # Convert terrain types to specific tiles using autotiling intelligence
    apply_autotiling_intelligence(map)
    
    return map

static func generate_terrain_layout(map: FEMap, params: Dictionary):
    # Generate high-level terrain distribution
    var algorithm = params.get("algorithm", "perlin")
    
    match algorithm:
        "perlin":
            generate_perlin_terrain(map, params)
        "cellular":
            generate_cellular_terrain(map, params)
        "strategic":
            generate_strategic_terrain(map, params)
        _:
            generate_random_terrain(map, params)

static func apply_autotiling_intelligence(map: FEMap):
    print("🎨 Applying autotiling intelligence...")
    
    var tileset_data = AssetManager.tileset_data.get(map.tileset_id)
    if not tileset_data or not tileset_data.pattern_analysis_complete:
        push_warning("No autotiling data available for tileset: " + map.tileset_id)
        return
    
    # Multiple passes to handle tile dependencies
    for pass in range(3):  # Usually 2-3 passes is enough
        var changes_made = false
        
        for y in range(map.height):
            for x in range(map.width):
                var old_tile = map.get_tile_at(x, y)
                var new_tile = get_smart_tile_for_position(map, x, y, tileset_data)
                
                if new_tile != old_tile:
                    map.set_tile_at(x, y, new_tile)
                    changes_made = true
        
        if not changes_made:
            break  # Converged
    
    print("  ✨ Autotiling complete!")

static func get_smart_tile_for_position(map: FEMap, x: int, y: int, tileset_data: FETilesetData) -> int:
    var current_tile = map.get_tile_at(x, y)
    var current_terrain = get_terrain_for_tile(current_tile, tileset_data)
    
    # Analyze neighbors
    var neighbors = get_neighbor_terrains(map, x, y, tileset_data)
    
    # Use autotiling database to find best tile
    return tileset_data.get_smart_tile(current_terrain, neighbors)

static func get_neighbor_terrains(map: FEMap, x: int, y: int, tileset_data: FETilesetData) -> Array[int]:
    var neighbors = []
    var directions = [
        Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),  # NW, N, NE
        Vector2i(-1,  0),                   Vector2i(1,  0),  # W,     E  
        Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)   # SW, S, SE
    ]
    
    for dir in directions:
        var nx = x + dir.x
        var ny = y + dir.y
        
        if nx >= 0 and nx < map.width and ny >= 0 and ny < map.height:
            var neighbor_tile = map.get_tile_at(nx, ny)
            var neighbor_terrain = get_terrain_for_tile(neighbor_tile, tileset_data)
            neighbors.append(neighbor_terrain)
        else:
            # Handle map borders - assume same terrain as center or void
            neighbors.append(0)  # Or use center terrain for seamless borders
    
    return neighbors

static func get_terrain_for_tile(tile_index: int, tileset_data: FETilesetData) -> int:
    if tile_index >= 0 and tile_index < tileset_data.terrain_tags.size():
        return tileset_data.terrain_tags[tile_index]
    return 0  # Default terrain
```

### 3.2 Upgrade MapCanvas for Smart Painting

```gdscript
# In scripts/components/MapCanvas.gd, enhance tile painting:

func _paint_tile(pos: Vector2i):
    if not is_valid_position(pos):
        return
    
    var old_tile = current_map.get_tile_at(pos.x, pos.y)
    
    # Place the selected tile
    current_map.set_tile_at(pos.x, pos.y, selected_tile_index)
    
    # Apply autotiling intelligence to surrounding area
    if current_tileset_data.pattern_analysis_complete:
        apply_local_autotiling(pos)
    
    # Update visual representation
    refresh_tile_at(pos)
    
    # Emit signal for undo/redo system
    tile_painted.emit(pos, old_tile, selected_tile_index)

func apply_local_autotiling(center_pos: Vector2i):
    # Update center tile and neighbors to ensure coherent patterns
    var update_area = Rect2i(center_pos - Vector2i(2, 2), Vector2i(5, 5))
    
    for y in range(update_area.position.y, update_area.end.y):
        for x in range(update_area.position.x, update_area.end.x):
            if is_valid_position(Vector2i(x, y)):
                var smart_tile = get_smart_tile_for_position(x, y)
                if smart_tile != current_map.get_tile_at(x, y):
                    current_map.set_tile_at(x, y, smart_tile)
                    refresh_tile_at(Vector2i(x, y))

func get_smart_tile_for_position(x: int, y: int) -> int:
    var current_tile = current_map.get_tile_at(x, y)
    var current_terrain = get_terrain_for_tile(current_tile)
    var neighbors = get_neighbor_terrains(x, y)
    
    return current_tileset_data.get_smart_tile(current_terrain, neighbors)
```

## Phase 4: Testing and Validation

### 4.1 Pattern Analysis Validation

```gdscript
# scripts/tools/PatternValidator.gd
class_name PatternValidator
extends RefCounted

static func validate_pattern_database(db: AutotilingDatabase) -> Dictionary:
    var results = {
        "total_patterns": db.patterns.size(),
        "terrain_coverage": {},
        "pattern_quality": {},
        "recommendations": []
    }
    
    # Check terrain coverage
    for terrain_id in AssetManager.terrain_data:
        var terrain_patterns = get_patterns_for_terrain(db, terrain_id)
        results.terrain_coverage[terrain_id] = terrain_patterns.size()
        
        if terrain_patterns.size() < 5:
            results.recommendations.append("Terrain %d has limited patterns (%d)" % [terrain_id, terrain_patterns.size()])
    
    # Check pattern quality (frequency analysis)
    for signature in db.patterns:
        var pattern = db.patterns[signature]
        results.pattern_quality[signature] = {
            "frequency": pattern.frequency,
            "tile_variants": pattern.valid_tiles.size(),
            "source_maps": pattern.source_maps.size()
        }
    
    return results

static func get_patterns_for_terrain(db: AutotilingDatabase, terrain_id: int) -> Array:
    var patterns = []
    for signature in db.patterns:
        var pattern = db.patterns[signature]
        if pattern.center_terrain == terrain_id:
            patterns.append(pattern)
    return patterns
```

### 4.2 Map Quality Testing

```gdscript
# Add to scripts/tools/TestRunner.gd:

func test_autotiling_generation():
    print("🧪 Testing autotiling generation...")
    
    for tileset_id in AssetManager.tileset_data:
        if AssetManager.tileset_data[tileset_id].pattern_analysis_complete:
            test_tileset_autotiling(tileset_id)

func test_tileset_autotiling(tileset_id: String):
    print("  Testing tileset: ", tileset_id)
    
    # Generate a test map
    var params = {
        "width": 15,
        "height": 12,
        "tileset_id": tileset_id,
        "algorithm": "perlin"
    }
    
    var generated_map = MapGenerator.generate_map(params)
    
    # Validate the map looks coherent
    var quality_score = analyze_map_coherence(generated_map)
    print("    Quality score: %.2f/10.0" % quality_score)
    
    if quality_score < 6.0:
        push_warning("Low quality generation for tileset: " + tileset_id)

func analyze_map_coherence(map: FEMap) -> float:
    var coherence_score = 0.0
    var total_positions = 0
    
    # Check each position for logical tile placement
    for y in range(1, map.height - 1):
        for x in range(1, map.width - 1):
            var position_score = score_tile_coherence(map, x, y)
            coherence_score += position_score
            total_positions += 1
    
    return (coherence_score / total_positions) * 10.0

func score_tile_coherence(map: FEMap, x: int, y: int) -> float:
    # Analyze if the tile at this position makes sense given its neighbors
    var center_tile = map.get_tile_at(x, y)
    var tileset_data = AssetManager.tileset_data[map.tileset_id]
    
    if not tileset_data.pattern_analysis_complete:
        return 0.5  # Can't evaluate without pattern data
    
    var center_terrain = get_terrain_for_tile(center_tile, tileset_data)
    var neighbors = get_neighbor_terrains_for_analysis(map, x, y, tileset_data)
    
    # Check if this exact pattern exists in our database
    var signature = create_pattern_signature(center_terrain, neighbors)
    var db = tileset_data.autotiling_db
    
    if signature in db.patterns:
        var pattern = db.patterns[signature]
        if center_tile in pattern.valid_tiles:
            return 1.0  # Perfect match - this is exactly what the pros did
        else:
            return 0.7  # Pattern exists but different tile variant
    else:
        return 0.3  # Unusual pattern not seen in original maps
```

## Phase 5: Integration and Usage

### 5.1 Update Your Main Initialization

```gdscript
# In your main scene or initialization code:

func _ready():
    # Initialize with pattern analysis
    AssetManager.initialize("/Users/sunnigen/Godot/FEMapCreator")
    
    # Test the autotiling system
    test_autotiling_system()

func test_autotiling_system():
    print("🎮 Testing autotiling generation...")
    
    # Generate a test map with each available tileset
    for tileset_id in AssetManager.tileset_data:
        if AssetManager.tileset_data[tileset_id].pattern_analysis_complete:
            generate_test_map(tileset_id)

func generate_test_map(tileset_id: String):
    var params = {
        "width": 20,
        "height": 15,
        "tileset_id": tileset_id,
        "algorithm": "strategic"
    }
    
    var map = MapGenerator.generate_map(params)
    print("Generated %dx%d map with tileset %s" % [map.width, map.height, tileset_id])
    
    # Optionally save for inspection
    MapIO.save_map_to_file(map, "res://test_output/" + tileset_id + "_generated.map")
```

### 5.2 Add Debug Tools

```gdscript
# Add to your debug overlay or console commands:

func debug_show_patterns(tileset_id: String):
    var tileset_data = AssetManager.tileset_data.get(tileset_id)
    if not tileset_data or not tileset_data.pattern_analysis_complete:
        print("No pattern data for tileset: ", tileset_id)
        return
    
    var db = tileset_data.autotiling_db
    print("=== Autotiling Patterns for %s ===" % tileset_id)
    print("Total patterns: %d" % db.patterns.size())
    
    # Show most common patterns
    var patterns_by_frequency = []
    for signature in db.patterns:
        patterns_by_frequency.append([signature, db.patterns[signature].frequency])
    
    patterns_by_frequency.sort_custom(func(a, b): return a[1] > b[1])
    
    print("Top 10 most common patterns:")
    for i in range(min(10, patterns_by_frequency.size())):
        var signature = patterns_by_frequency[i][0]
        var frequency = patterns_by_frequency[i][1]
        var pattern = db.patterns[signature]
        print("  %s: %d occurrences, %d tile variants" % [signature, frequency, pattern.valid_tiles.size()])
```

## Expected Results

After implementing this system, your map generator should produce:

✅ **Natural Terrain Flow**: Forests connect properly, rivers have banks, roads have curves  
✅ **Professional Appearance**: Maps that look as polished as original Fire Emblem maps  
✅ **Tactical Coherence**: Terrain placement that makes sense for strategic gameplay  
✅ **Authentic Style**: Using the exact tile arrangements that Fire Emblem designers chose  

## Performance Considerations

- **Pattern Database Size**: Each tileset might have 500-2000 unique patterns
- **Memory Usage**: Pattern databases are small (~1-5MB total) and cached
- **Generation Speed**: Pattern lookup is fast (O(1) dictionary access)
- **Analysis Time**: One-time analysis takes 30-60 seconds but results are saved

## Implementation Timeline

1. **Day 1-2**: Implement PatternAnalyzer and extract patterns from your existing maps
2. **Day 3**: Integrate pattern databases into AssetManager initialization  
3. **Day 4**: Update MapGenerator to use autotiling intelligence
4. **Day 5**: Test and validate results, tune pattern selection algorithms

## Success Metrics

- Generated maps should score >8.0/10.0 in coherence analysis
- Each tileset should have 200+ distinct patterns extracted
- Visual inspection: maps should look indistinguishable from hand-crafted originals
- No obvious tile placement errors (forests floating in water, etc.)

Your existing data pipeline is perfect for this approach - you just need to mine the intelligence that's already there in your 300+ professional map examples!