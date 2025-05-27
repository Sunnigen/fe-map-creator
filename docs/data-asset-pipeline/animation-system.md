# FEMapCreator Animation System
## Technical Overview for Engineering & Product Teams

### Executive Summary
The FEMapCreator animation system enables dynamic tile animations (water, lava, torches) using a frame-swapping mechanism. The system encodes animation sequences as compact integer arrays, supporting multiple independent animation groups per tileset with configurable timing.

### Animation Data Structure

```xml
<Animated_Tile_Names>
  <Item>FieldWater1</Item>
  <Item>FieldWater2</Item>
</Animated_Tile_Names>
<Animated_Tile_Data>20 0 4 22 24 0 8 22</Animated_Tile_Data>
```

The data is parsed as 4-integer groups, each defining one animation sequence:
```
[Frame Count] [Start Delay] [Frame Duration] [Base Tile Index]
```

### Animation Sequence Decoding

**Example**: Water animation `20 0 4 22`
- **20**: Total frames in the animation cycle
- **0**: Delay before animation starts (in frames)
- **4**: Duration each frame is displayed
- **22**: Starting tile index in the tileset

This creates: Tile 22 → 23 → 24 → ... → 41 → 22 (loops)

### Multi-Animation Tilesets

Complex tilesets can have multiple animation groups:

```xml
<!-- Coastal Village with 7 animation groups -->
<Animated_Tile_Names>
  <Item>MountainVillageWater1</Item>
  <Item>MountainVillageWater2</Item>
  <Item>MountainVillageWater3</Item>
  <Item>MountainVillageWater4</Item>
  <Item>CoastalVillageWater1</Item>
  <Item>CoastalVillageWater2</Item>
  <Item>CoastalVillageWater3</Item>
</Animated_Tile_Names>
<Animated_Tile_Data>
  20 19 6 8    <!-- Group 1: Slow water -->
  26 14 6 13   <!-- Group 2: Offset water -->
  11 11 1 1    <!-- Group 3: Rapid flicker -->
  23 30 1 1    <!-- Group 4: Delayed flicker -->
  26 6 6 8     <!-- Group 5: Coastal waves -->
  20 6 6 8     <!-- Group 6: Shore waves -->
  13 11 7 2    <!-- Group 7: Torch flames -->
</Animated_Tile_Data>
```

### Animation Types by Environment

#### **Water Animations**
- Frame Count: 20-26 frames
- Frame Duration: 4-8 frames
- Creates smooth wave effects
- Often multiple groups for variety

#### **Lava Animations**
- Frame Count: 19-24 frames  
- Frame Duration: 5-8 frames
- Slower, bubbling effects
- Synchronized across map

#### **Torch/Fire Animations**
- Frame Count: 11-23 frames
- Frame Duration: 1-2 frames
- Rapid flickering effect
- Multiple offsets prevent synchronization

### Frame Timing Calculation

```gdscript
class TileAnimation:
    var frame_count: int
    var start_delay: int
    var frame_duration: int
    var base_tile: int
    var current_time: int = 0
    
    func get_current_tile(global_time: int) -> int:
        # Account for start delay
        if global_time < start_delay:
            return base_tile
            
        # Calculate animation progress
        var anim_time = global_time - start_delay
        var total_duration = frame_count * frame_duration
        var loop_time = anim_time % total_duration
        
        # Determine current frame
        var frame = loop_time / frame_duration
        return base_tile + frame
```

### Tileset Animation Mapping

The animation system needs to track which tiles should animate:

```gdscript
class AnimatedTileset:
    var animations: Array[TileAnimation] = []
    var animated_tiles: Dictionary = {}  # tile_id -> animation
    
    func initialize(anim_data: String, anim_names: Array):
        var values = anim_data.split(" ")
        for i in range(0, values.size(), 4):
            var anim = TileAnimation.new()
            anim.frame_count = values[i].to_int()
            anim.start_delay = values[i+1].to_int()
            anim.frame_duration = values[i+2].to_int()
            anim.base_tile = values[i+3].to_int()
            
            # Map all tiles in this animation
            for f in range(anim.frame_count):
                animated_tiles[anim.base_tile + f] = anim
            
            animations.append(anim)
```

### Rendering Pipeline Integration

```gdscript
extends TileMap
class_name AnimatedTileMap

var tileset_animations: AnimatedTileset
var animation_time: float = 0.0
var frame_time: float = 1.0 / 60.0  # 60 FPS

func _ready():
    # Load animation data for current tileset
    tileset_animations = load_animations(tileset_id)

func _process(delta):
    animation_time += delta
    
    # Update every frame (60Hz)
    if animation_time >= frame_time:
        update_animated_tiles()
        animation_time = 0.0

func update_animated_tiles():
    var global_frame = Engine.get_frames_drawn()
    
    for cell in get_used_cells(0):
        var atlas_coords = get_cell_atlas_coords(0, cell)
        var tile_index = atlas_coords.y * 32 + atlas_coords.x
        
        if tile_index in tileset_animations.animated_tiles:
            var anim = tileset_animations.animated_tiles[tile_index]
            var new_tile = anim.get_current_tile(global_frame)
            
            if new_tile != tile_index:
                var new_x = new_tile % 32
                var new_y = new_tile / 32
                set_cell(0, cell, 0, Vector2i(new_x, new_y))
```

### Performance Optimization Strategies

#### **1. Dirty Rectangle Tracking**
Only update regions with animated tiles:
```gdscript
var animated_regions: Array[Rect2i] = []

func mark_animated_region(pos: Vector2i):
    for region in animated_regions:
        if region.has_point(pos):
            return
    animated_regions.append(Rect2i(pos - Vector2i(5, 5), Vector2i(10, 10)))
```

#### **2. Animation LOD System**
Reduce update frequency for distant tiles:
```gdscript
func should_animate_tile(tile_pos: Vector2i, camera_pos: Vector2i) -> bool:
    var distance = tile_pos.distance_to(camera_pos)
    if distance > 20:
        return Engine.get_frames_drawn() % 4 == 0  # 15 FPS
    elif distance > 10:
        return Engine.get_frames_drawn() % 2 == 0  # 30 FPS
    return true  # 60 FPS
```

#### **3. Shader-Based Animation**
Move animation logic to GPU for large maps:
```gdscript
shader_type canvas_item;
uniform sampler2D animation_lut;
uniform float time;

void fragment() {
    vec2 tile_uv = UV * 32.0;
    int tile_index = int(tile_uv.y) * 32 + int(tile_uv.x);
    
    // Lookup animation data
    vec4 anim_data = texture(animation_lut, vec2(float(tile_index) / 1024.0, 0.0));
    
    if (anim_data.a > 0.0) {
        // Animated tile detected
        float frame = mod(time / anim_data.g, anim_data.r);
        tile_index = int(anim_data.b) + int(frame);
    }
    
    // Remap UV to new tile
    COLOR = texture(TEXTURE, calculate_new_uv(tile_index));
}
```

### Animation Synchronization

Different animation groups can be synchronized or offset:

- **Synchronized**: All water tiles move together (realistic ocean)
- **Offset**: Each torch flickers independently (natural fire)
- **Delayed**: Staggered start times create wave effects

### Common Animation Patterns

| Environment | Frames | Duration | Effect |
|------------|--------|----------|---------|
| Ocean Water | 20-26 | 4-6 | Smooth waves |
| River Water | 16-20 | 3-4 | Faster flow |
| Lava Pool | 24 | 8 | Slow bubbling |
| Torch Fire | 11 | 1 | Rapid flicker |
| Magic Glow | 16 | 2 | Pulsing effect |

### Debugging Tools

```gdscript
# Animation debugger overlay
func _draw():
    if debug_animations:
        for cell in get_used_cells(0):
            var tile_index = get_cell_tile_index(cell)
            if tile_index in tileset_animations.animated_tiles:
                var anim = tileset_animations.animated_tiles[tile_index]
                draw_rect(Rect2(map_to_local(cell), Vector2(16, 16)), 
                         Color.RED, false, 2.0)
                draw_string(font, map_to_local(cell), 
                           str(anim.get_current_frame()), Color.WHITE)
```

---
*This animation system brings Fire Emblem's world to life through efficient, data-driven tile animations while maintaining performance across varying hardware configurations.*