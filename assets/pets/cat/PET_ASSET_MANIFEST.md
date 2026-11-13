# Couple Chaos 3D - Low-Poly Pet Asset System Manifest

## 1. Overview & Art Direction

- **Project:** Couple Chaos 3D (Cozy Vietnamese neighborhood life simulation).
- **Style:** Stylized low-poly 3D, warm pastel palette, cute chibi proportions, soft matte materials (roughness 0.85–0.95), rounded silhouettes.
- **Scale:** Matched to human characters (Boy & Girl ~1.28m). Cat dimensions: length ~0.38m, shoulder height ~0.22m, head height ~0.28m.
- **Collision:** Standalone `CollisionShape3D` capsule (radius: 0.14m, height: 0.38m, collision layer 4: NPCs/Pets, mask 1: World environment).

---

## 2. Primary Character: Orange Tabby Cat

- **Scene Wrapper:** `res://scenes/pets/orange_tabby_cat.tscn`
- **Root Script:** `res://scripts/pets/orange_tabby_cat.gd` (CharacterBody3D)
- **Visual Model Script:** `res://scripts/pets/cat_visual.gd` (Articulated low-poly mesh hierarchy)
- **Animation Controller:** `res://scripts/pets/pet_animation_controller.gd` (Dual-layer procedural & AnimationPlayer adapter)

### Joint Hierarchy:
```
OrangeTabbyCat (CharacterBody3D)
├── CollisionShape3D (CapsuleShape3D, horizontal r=0.14, h=0.38)
├── CatVisual (Node3D)
│   └── Root (Node3D)
│       ├── Body (Node3D)
│       │   ├── TorsoMesh (CapsuleMesh, coat orange #F59E56)
│       │   ├── BellyMesh (Cream white #FFF2DB)
│       │   ├── StripeMeshes (x3 ginger transverse stripes #BF531C)
│       │   └── ChestTuft (Cream fluff)
│       ├── Head (Node3D)
│       │   ├── SkullMesh (Rounded BoxMesh / Sphere)
│       │   ├── TabbyMarkingM (M-shape forehead crest #BF531C)
│       │   ├── EarLeft / EarRight (PrismMesh with pink inner ear #F8BBD0)
│       │   ├── Muzzle (Cream muzzle with pink nose #F48FB1 & whisker studs)
│       │   ├── EyeLeft / EyeRight (Emerald teal #26A69A + dark pupils #1A2327)
│       │   ├── HappyEyeLeft / HappyEyeRight (Curved crescent joyful eyes)
│       │   ├── Collar (Red woven collar #D32F2F)
│       │   └── Bell (Brass jingle bell #FFD700)
│       ├── LegFL / LegFR (Front legs with cream paws & pink pads)
│       ├── LegBL / LegBR (Hind legs with hock angles & cream paws)
│       ├── TailBase -> TailMid -> TailTip (Articulated J-curve ginger tail)
│       ├── MouthAnchor (Marker3D for holding toys or eating)
│       └── HeadAnchor (Marker3D for emote icons & petting sparkles)
└── PetAnimationController (Node)
    └── AnimationPlayer (Contains generated AnimationLibrary)
```

---

## 3. Required Animations (10/10)

| Animation | Duration | Loop | Description |
|---|---|---|---|
| `idle` | 2.4s | Yes | Gentle rhythmic breathing, chest bobbing, soft tail sway, ear twitch. |
| `walk` | 0.8s | Yes | 4-beat diagonal walking gait, alternating paw steps, body sway. |
| `run` | 0.45s | Yes | Fast bounding gallop, spine flexion/extension, tail streaming back. |
| `sit` | 1.0s | Yes | Haunches dropped, front legs upright and straight, tail curled around paws. |
| `sleep` | 3.0s | Yes | Curled into an adorable round ball, eyes closed, slow deep breathing. |
| `eat` | 0.6s | Yes | Head lowered to bowl/floor, rhythmic chewing head bobs, tail wagging slowly. |
| `drink` | 0.5s | Yes | Head dipped, rapid gentle tongue lap bobbing motion. |
| `play` | 1.2s | Yes | Play-bow crouch, butt wiggle, paw pounces, tail thrashing with excitement. |
| `happy` | 1.0s | Yes | High tail shake, chin tilt up, arched back, joyful purring wiggle. |
| `follow_turn` | 0.6s | Yes | Stepping turn on spot, curved spine lean, attentive head tracking. |

---

## 4. Required Props & Accessories (8/8)

All props are located in `res://scenes/pets/` and use `res://scripts/pets/pet_prop.gd`:

1. **Food Bowl (`prop_food_bowl.tscn`)**
   - Mint ceramic bowl with crunchy salmon kibbles.
   - Refillable by player (`E`), consumable by cat (`eat` animation).
2. **Water Bowl (`prop_water_bowl.tscn`)**
   - Sky-blue ceramic bowl with glistening translucent water surface.
   - Refillable by player (`E`), consumable by cat (`drink` animation).
3. **Pet Bed (`prop_pet_bed.tscn`)**
   - Donut-shaped peach fleece rim with cream cushion and paw-print motif.
   - Interactive pet target for curling up to `sleep`.
4. **Toy Ball (`prop_toy_ball.tscn`)**
   - Purple yarn ball with physics-enabled `RigidBody3D`, bouncy material, and jingle bell.
   - Can be kicked or batted around by player and pet (`play` animation).
5. **Cat Scratching Post (`prop_scratching_post.tscn`)**
   - Heavy square carpeted base, natural sisal rope post, wood cap, and dangling pom-pom.
   - Target for cat stretching, claw sharpening, and batting.
6. **Cat Toy Wand (`prop_cat_toy_wand.tscn`)**
   - Slender wood wand with coral handle grip and teal dangling teaser feather.
   - Interactive play item that triggers cat play-pouncing.
7. **Pet Food Package (`prop_pet_food_package.tscn`)**
   - Standing salmon kibble dry food pouch with crimped top and fish emblem.
   - Cosmetic and future pantry/market storage prop.
8. **Cat Collar with Bell (`prop_cat_collar.tscn`)**
   - Standalone red woven ribbon collar with gold buckle and spherical brass bell.
   - Equippable on pet (`has_collar = true/false` or `set_collar_visible()`).

---

## 5. Integration Guide for Gameplay Engineers

### Spawning the Cat in a Scene
```gdscript
var cat_scene: PackedScene = preload("res://scenes/pets/orange_tabby_cat.tscn")
var cat: OrangeTabbyCat = cat_scene.instantiate()
cat.position = Vector3(1.5, 0.0, -1.0)
add_child(cat)

# Control animations
cat.play_animation("idle")
cat.set_expression("happy") # "happy", "alert", "sleep", "wink"
```

### Making the Cat Use a Prop
```gdscript
var food_bowl: PetProp = get_node("PropFoodBowl")
cat.global_position = food_bowl.get_interaction_position()
food_bowl.use_by_pet(cat) # Triggers cat "eat" animation and depletes food
```

### Player Affection Interaction
The cat implements the standard `Interactable` interface (`available`, `prompt`, `interact`), automatically supported by `PlayerController`:
- Pressing `E` plays `happy` purring animation, changes eye expression to cute crescents, triggers heart particle feedback, and shows cozy toast notifications.
