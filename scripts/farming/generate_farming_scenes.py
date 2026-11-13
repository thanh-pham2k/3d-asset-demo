#!/usr/bin/env python3
"""
Generates Godot 4 (.tscn) scene wrappers for all low-poly farming assets:
- Environment (plot_small, raised_bed, soils, fence, pathway, compost, seed box)
- Tools (watering can, shovel, hoe, harvest basket, seed packets)
- Crops (lettuce, tomato, carrot) with 4-stage dynamic switching (Seeded, Sprout, Growing, Mature)
- Collectibles & Individual Seed Packets
"""

import os

SCENES_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../scenes/farming"))
os.makedirs(SCENES_DIR, exist_ok=True)

def write_tscn(filename, content):
    path = os.path.join(SCENES_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
    print(f"Created: {path}")

# =====================================================================
# 1. ENVIRONMENT SCENES
# =====================================================================
write_tscn("plot_small.tscn", """
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/plot_small.glb" id="2"]

[sub_resource type="BoxShape3D" id="BoxShape3D_plot"]
size = Vector3(1.25, 0.20, 1.25)

[node name="PlotSmall" type="StaticBody3D"]
collision_layer = 1
collision_mask = 0
script = ExtResource("1")
prop_category = "plot"
item_id = "plot_small"
display_name = "Luống đất làm vườn nhỏ"

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.10, 0)
shape = SubResource("BoxShape3D_plot")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

write_tscn("raised_bed.tscn", """
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/raised_bed.glb" id="2"]

[sub_resource type="BoxShape3D" id="BoxShape3D_bed"]
size = Vector3(1.36, 0.44, 0.92)

[node name="RaisedGardenBed" type="StaticBody3D"]
collision_layer = 1
collision_mask = 0
script = ExtResource("1")
prop_category = "raised_bed"
item_id = "raised_bed"
display_name = "Bồn gỗ trồng rau cao ráo"

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.22, 0)
shape = SubResource("BoxShape3D_bed")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

for name, cat, disp, glb in [
    ("soil_empty", "soil", "Đất xới tơi xốp", "soil_empty.glb"),
    ("soil_dry", "soil", "Đất khô cần tưới", "soil_dry.glb"),
    ("soil_watered", "soil", "Đất ẩm đã tưới nước", "soil_watered.glb"),
    ("garden_pathway", "pathway", "Lối đi lát đá sân vườn", "garden_pathway.glb")
]:
    write_tscn(f"{name}.tscn", f"""
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/{glb}" id="2"]

[node name="{name.capitalize()}" type="Node3D"]
script = ExtResource("1")
prop_category = "{cat}"
item_id = "{name}"
display_name = "{disp}"

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

write_tscn("garden_fence.tscn", """
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/garden_fence.glb" id="2"]

[sub_resource type="BoxShape3D" id="BoxShape3D_fence"]
size = Vector3(1.50, 0.85, 0.12)

[node name="GardenFence" type="StaticBody3D"]
collision_layer = 1
collision_mask = 0
script = ExtResource("1")
prop_category = "fence"
item_id = "garden_fence"
display_name = "Hàng rào gỗ sân vườn"

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.42, 0)
shape = SubResource("BoxShape3D_fence")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

write_tscn("compost_bag.tscn", """
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/compost_bag.glb" id="2"]

[sub_resource type="BoxShape3D" id="BoxShape3D_compost"]
size = Vector3(0.40, 0.52, 0.28)

[node name="CompostBag" type="StaticBody3D"]
collision_layer = 1
collision_mask = 0
script = ExtResource("1")
prop_category = "compost"
item_id = "compost_bag"
display_name = "Bao phân bón hữu cơ"

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.26, 0)
shape = SubResource("BoxShape3D_compost")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

write_tscn("seed_storage_box.tscn", """
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/seed_storage_box.glb" id="2"]

[sub_resource type="BoxShape3D" id="BoxShape3D_seedbox"]
size = Vector3(0.58, 0.32, 0.40)

[node name="SeedStorageBox" type="StaticBody3D"]
collision_layer = 1
collision_mask = 0
script = ExtResource("1")
prop_category = "seed_box"
item_id = "seed_storage_box"
display_name = "Rương chứa hạt giống"

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.16, 0)
shape = SubResource("BoxShape3D_seedbox")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

# =====================================================================
# 2. TOOL SCENES
# =====================================================================
write_tscn("tool_watering_can.tscn", """
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/tool_watering_can.glb" id="2"]

[sub_resource type="CylinderShape3D" id="CylinderShape3D_can"]
height = 0.32
radius = 0.18

[node name="ToolWateringCan" type="Node3D"]
script = ExtResource("1")
prop_category = "tool"
item_id = "tool_watering_can"
display_name = "Bình tưới cây hoa sen"

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.16, 0)
shape = SubResource("CylinderShape3D_can")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

write_tscn("tool_shovel.tscn", """
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/tool_shovel.glb" id="2"]

[sub_resource type="BoxShape3D" id="BoxShape3D_shovel"]
size = Vector3(0.22, 0.85, 0.08)

[node name="ToolShovel" type="Node3D"]
script = ExtResource("1")
prop_category = "tool"
item_id = "tool_shovel"
display_name = "Xẻng làm vườn cán gỗ"

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.42, 0)
shape = SubResource("BoxShape3D_shovel")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

write_tscn("tool_hoe.tscn", """
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/tool_hoe.glb" id="2"]

[sub_resource type="BoxShape3D" id="BoxShape3D_hoe"]
size = Vector3(0.22, 0.98, 0.12)

[node name="ToolHoe" type="Node3D"]
script = ExtResource("1")
prop_category = "tool"
item_id = "tool_hoe"
display_name = "Cuốc xới đất làm cỏ"

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.49, 0)
shape = SubResource("BoxShape3D_hoe")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

write_tscn("tool_harvest_basket.tscn", """
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/tool_harvest_basket.glb" id="2"]

[sub_resource type="BoxShape3D" id="BoxShape3D_basket"]
size = Vector3(0.40, 0.32, 0.30)

[node name="ToolHarvestBasket" type="Node3D"]
script = ExtResource("1")
prop_category = "tool"
item_id = "tool_harvest_basket"
display_name = "Giỏ mây thu hoạch rau củ"

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.16, 0)
shape = SubResource("BoxShape3D_basket")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

write_tscn("tool_seed_packets.tscn", """
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/tool_seed_packets.glb" id="2"]

[sub_resource type="BoxShape3D" id="BoxShape3D_packs"]
size = Vector3(0.34, 0.20, 0.22)

[node name="ToolSeedPackets" type="Node3D"]
script = ExtResource("1")
prop_category = "seed_packet"
item_id = "tool_seed_packets"
display_name = "Khay các gói hạt giống"

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.10, 0)
shape = SubResource("BoxShape3D_packs")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

# =====================================================================
# 3. CROPS WITH 4 DYNAMIC STAGES
# =====================================================================
crops = [
    ("lettuce", "Cải xanh / Xà lách"),
    ("tomato", "Cà chua"),
    ("carrot", "Cà rốt")
]

for crop_id, crop_name in crops:
    write_tscn(f"crop_{crop_id}.tscn", f"""
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/farming/crop_visual.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/soil_empty.glb" id="2"]
[ext_resource type="PackedScene" path="res://assets/farming/crop_{crop_id}_seeded.glb" id="3"]
[ext_resource type="PackedScene" path="res://assets/farming/crop_{crop_id}_sprout.glb" id="4"]
[ext_resource type="PackedScene" path="res://assets/farming/crop_{crop_id}_growing.glb" id="5"]
[ext_resource type="PackedScene" path="res://assets/farming/crop_{crop_id}_mature.glb" id="6"]

[node name="Crop{crop_id.capitalize()}" type="Node3D"]
script = ExtResource("1")
crop_type = "{crop_id}"
current_stage = 0

[node name="Soil" type="Node3D" parent="."]

[node name="SoilModel" parent="Soil" instance=ExtResource("2")]

[node name="StageSeeded" type="Node3D" parent="."]

[node name="ModelSeeded" parent="StageSeeded" instance=ExtResource("3")]

[node name="StageSprout" type="Node3D" parent="."]
visible = false

[node name="ModelSprout" parent="StageSprout" instance=ExtResource("4")]

[node name="StageGrowing" type="Node3D" parent="."]
visible = false

[node name="ModelGrowing" parent="StageGrowing" instance=ExtResource("5")]

[node name="StageMature" type="Node3D" parent="."]
visible = false

[node name="ModelMature" parent="StageMature" instance=ExtResource("6")]
""")

# =====================================================================
# 4. COLLECTIBLES & INDIVIDUAL SEED PACKETS
# =====================================================================
collectibles = [
    ("collectible_lettuce", "lettuce", "Rau cải xanh tươi", "collectible_lettuce.glb", "SphereShape3D", "radius = 0.12", 0.10),
    ("collectible_tomato", "tomato", "Cà chua chín mọng", "collectible_tomato.glb", "SphereShape3D", "radius = 0.10", 0.08),
    ("collectible_carrot", "carrot", "Củ cà rốt tươi ngon", "collectible_carrot.glb", "CylinderShape3D", "height = 0.28\\nradius = 0.06", 0.14)
]

for name, item_id, disp, glb, shape_type, shape_def, cy in collectibles:
    write_tscn(f"{name}.tscn", f"""
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/{glb}" id="2"]

[sub_resource type="{shape_type}" id="{shape_type}_{name}"]
{shape_def}

[node name="{name.capitalize()}" type="Node3D"]
script = ExtResource("1")
prop_category = "collectible"
item_id = "{item_id}"
display_name = "{disp}"
is_collectible = true

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {cy}, 0)
shape = SubResource("{shape_type}_{name}")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

seed_packets = [
    ("seed_packet_lettuce", "seed_lettuce", "Gói hạt giống rau cải xanh", "seed_packet_lettuce.glb"),
    ("seed_packet_tomato", "seed_tomato", "Gói hạt giống cà chua bi", "seed_packet_tomato.glb"),
    ("seed_packet_carrot", "seed_carrot", "Gói hạt giống cà rốt ngọt", "seed_packet_carrot.glb")
]

for name, item_id, disp, glb in seed_packets:
    write_tscn(f"{name}.tscn", f"""
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/farming/farming_prop.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/farming/{glb}" id="2"]

[sub_resource type="BoxShape3D" id="BoxShape3D_{name}"]
size = Vector3(0.12, 0.18, 0.04)

[node name="{name.capitalize()}" type="Node3D"]
script = ExtResource("1")
prop_category = "seed_packet"
item_id = "{item_id}"
display_name = "{disp}"
is_collectible = true

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.09, 0)
shape = SubResource("BoxShape3D_{name}")

[node name="Visual" type="Node3D" parent="."]

[node name="Model" parent="Visual" instance=ExtResource("2")]
""")

print("\nSUCCESS: All Godot farming scene wrappers (.tscn) generated!")
