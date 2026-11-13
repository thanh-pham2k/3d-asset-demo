# Couple Chaos 3D - Low-Poly Farming Asset Pack MVP Manifest

## 1. Overview & Art Direction

- **Project:** Couple Chaos 3D (Cozy Vietnamese neighborhood life simulation).
- **Style:** Stylized low-poly 3D, warm pastel palette, cute rounded proportions, soft matte materials (roughness 0.85–0.95, metallic 0.0–0.6), clean readable silhouettes.
- **Scale:** Matched to human characters (Boy & Girl height reference ~1.28m) and existing home garden area:
  - Garden Plot: 1.25m × 1.25m footprint, 0.20m height.
  - Raised Bed: 1.36m × 0.92m footprint, 0.44m height.
  - Tools: 0.32m to 0.98m ergonomic length.
  - Crops & Collectibles: 0.16m to 0.50m height, distinct silhouettes.
- **Pivots & Origins:** All asset pivots normalized at ground base (`Y = 0`, centered at `X = 0`, `Z = 0`).
- **Collision Separation:** Every physical item features a separate, accurately sized `CollisionShape3D` (`BoxShape3D`, `CylinderShape3D`, or `SphereShape3D`) independent of visual meshes.

---

## 2. Palette & Material Specifications

| Material Name | Base Color Hex | Roughness | Metallic | Usage |
|---|---|---|---|---|
| **TilledSoil** | `#734E38` | 0.90 | 0.0 | Standard garden soil mound |
| **SoilDry** | `#B8946B` | 0.95 | 0.0 | Pale thirsty parched soil |
| **SoilWatered** | `#472E1F` | 0.45 | 0.0 | Moist rich loam with wet sheen |
| **PlanterWood** | `#A66B40` | 0.85 | 0.0 | Raised bed planks and corner posts |
| **FenceWood** | `#C78F5C` | 0.88 | 0.0 | Garden fence posts, pickets, and rails |
| **PaverPeach** | `#DB9E85` | 0.92 | 0.0 | Terracotta garden stepping pavers |
| **Burlap** | `#D1B385` | 0.95 | 0.0 | Compost sack fabric |
| **MintTeal** | `#66C2B3` | 0.55 | 0.3 | Watering can metal body |
| **BrassRose** | `#F5D147` | 0.40 | 0.6 | Sprinkler rose head and chest latch |
| **SpadeSteel** | `#808C94` | 0.45 | 0.5 | Shovel and hoe metal heads |
| **Wicker** | `#CCA36B` | 0.92 | 0.0 | Woven harvest basket |
| **LettuceDark** | `#52B857` | 0.88 | 0.0 | Outer ruffled lettuce foliage |
| **LettuceHeart**| `#A6EB80` | 0.88 | 0.0 | Crisp pale lettuce heart |
| **TomatoRed** | `#EB382E` | 0.45 | 0.0 | Ripe shiny red tomatoes |
| **CalyxGreen** | `#4DA640` | 0.85 | 0.0 | Tomato sepals and leafy vine |
| **CarrotOrange**| `#F5851F` | 0.80 | 0.0 | Fresh tapered carrot root |
| **CarrotFrond** | `#59BF4D` | 0.85 | 0.0 | Feathery parsley-like foliage |

---

## 3. Asset Inventory & File Mapping

### A. Environment Assets (9 Assets)
| Asset | GLB File (`assets/farming/`) | Scene Wrapper (`scenes/farming/`) | Collision Type |
|---|---|---|---|
| **Small Garden Plot** | `plot_small.glb` | `plot_small.tscn` | `BoxShape3D` (1.25 × 0.20 × 1.25m) |
| **Raised Garden Bed** | `raised_bed.glb` | `raised_bed.tscn` | `BoxShape3D` (1.36 × 0.44 × 0.92m) |
| **Empty Soil** | `soil_empty.glb` | `soil_empty.tscn` | Ground surface marker |
| **Dry Soil** | `soil_dry.glb` | `soil_dry.tscn` | Ground surface marker |
| **Watered Soil** | `soil_watered.glb` | `soil_watered.tscn` | Ground surface marker |
| **Wooden Garden Fence**| `garden_fence.glb` | `garden_fence.tscn` | `BoxShape3D` (1.50 × 0.85 × 0.12m) |
| **Garden Pathway** | `garden_pathway.glb` | `garden_pathway.tscn`| Ground pathway surface |
| **Compost Bag** | `compost_bag.glb` | `compost_bag.tscn` | `BoxShape3D` (0.40 × 0.52 × 0.28m) |
| **Seed Storage Box** | `seed_storage_box.glb`| `seed_storage_box.tscn`| `BoxShape3D` (0.58 × 0.32 × 0.40m) |

### B. Garden Tools (5 Assets)
| Asset | GLB File (`assets/farming/`) | Scene Wrapper (`scenes/farming/`) | Collision Type |
|---|---|---|---|
| **Watering Can** | `tool_watering_can.glb` | `tool_watering_can.tscn` | `CylinderShape3D` (r=0.18m, h=0.32m) |
| **Shovel** | `tool_shovel.glb` | `tool_shovel.tscn` | `BoxShape3D` (0.22 × 0.85 × 0.08m) |
| **Hoe** | `tool_hoe.glb` | `tool_hoe.tscn` | `BoxShape3D` (0.22 × 0.98 × 0.12m) |
| **Harvest Basket** | `tool_harvest_basket.glb`| `tool_harvest_basket.tscn`| `BoxShape3D` (0.40 × 0.32 × 0.30m) |
| **Seed Packets Display**| `tool_seed_packets.glb` | `tool_seed_packets.tscn` | `BoxShape3D` (0.34 × 0.20 × 0.22m) |

### C. Crops & 4-Stage Visual System (3 Crops × 4 Stages = 12 Visual Models)
All wrapped in `crop_<type>.tscn` controlled by `scripts/farming/crop_visual.gd`:

1. **Lettuce / Vietnamese Leafy Greens (`crop_lettuce.tscn`)**
   - Stage 0 (`SEEDED`): `crop_lettuce_seeded.glb` (Seeded soil mound furrow).
   - Stage 1 (`SPROUT`): `crop_lettuce_sprout.glb` (Twin pale-green cotyledon shoot).
   - Stage 2 (`GROWING`): `crop_lettuce_growing.glb` (Expanding leafy rosette).
   - Stage 3 (`MATURE`): `crop_lettuce_mature.glb` (Full lush harvest-ready ruffled head).

2. **Tomato (`crop_tomato.tscn`)**
   - Stage 0 (`SEEDED`): `crop_tomato_seeded.glb` (Seeded mound).
   - Stage 1 (`SPROUT`): `crop_tomato_sprout.glb` (Slender seedling shoot with leaves).
   - Stage 2 (`GROWING`): `crop_tomato_growing.glb` (Branching vine with yellow blossom stars and baby green tomatoes).
   - Stage 3 (`MATURE`): `crop_tomato_mature.glb` (Lush staked vine with clusters of ripe crimson tomatoes).

3. **Carrot (`crop_carrot.tscn`)**
   - Stage 0 (`SEEDED`): `crop_carrot_seeded.glb` (Seeded soil mound).
   - Stage 1 (`SPROUT`): `crop_carrot_sprout.glb` (Fine feathery seedling frond).
   - Stage 2 (`GROWING`): `crop_carrot_growing.glb` (Bushy parsley-like fronds).
   - Stage 3 (`MATURE`): `crop_carrot_mature.glb` (Tall vibrant fronds with peeking orange carrot crown).

### D. Collectibles & Seed Packets (6 Assets)
| Asset | GLB File (`assets/farming/`) | Scene Wrapper (`scenes/farming/`) | Collision Type |
|---|---|---|---|
| **Harvested Lettuce** | `collectible_lettuce.glb` | `collectible_lettuce.tscn` | `SphereShape3D` (r=0.12m) |
| **Harvested Tomato** | `collectible_tomato.glb` | `collectible_tomato.tscn` | `SphereShape3D` (r=0.10m) |
| **Harvested Carrot** | `collectible_carrot.glb` | `collectible_carrot.tscn` | `CylinderShape3D` (r=0.06m, h=0.28m) |
| **Lettuce Seed Packet** | `seed_packet_lettuce.glb` | `seed_packet_lettuce.tscn`| `BoxShape3D` (0.12 × 0.18 × 0.04m) |
| **Tomato Seed Packet** | `seed_packet_tomato.glb` | `seed_packet_tomato.tscn` | `BoxShape3D` (0.12 × 0.18 × 0.04m) |
| **Carrot Seed Packet** | `seed_packet_carrot.glb` | `seed_packet_carrot.tscn` | `BoxShape3D` (0.12 × 0.18 × 0.04m) |

---

## 4. Technical Integration Guide

### Swapping Crop Stages Dynamically
```gdscript
var crop: CropVisual = load("res://scenes/farming/crop_lettuce.tscn").instantiate()
add_child(crop)

# Advance to sprout with cute bounce effect
crop.set_stage(CropVisual.Stage.SPROUT)

# Later advance to mature
crop.set_stage(CropVisual.Stage.MATURE)

# Change soil moisture visually
crop.soil_moisture = "watered" # "watered", "dry", "empty"

# Check if harvest ready
if crop.is_harvest_ready():
    print("Crop is ready for harvest!")
```

### Spawning Tools & Collectibles
```gdscript
# Spawn watering can
var can: FarmingProp = load("res://scenes/farming/tool_watering_can.tscn").instantiate()
can.position = Vector3(2.0, 0.0, 1.0)
add_child(can)

# Spawn harvested carrot reward
var carrot: FarmingProp = load("res://scenes/farming/collectible_carrot.tscn").instantiate()
carrot.position = Vector3(2.0, 0.1, 1.0)
add_child(carrot)
```
