#!/usr/bin/env python3
"""
Low-Poly Farming Asset Generator for Couple Chaos 3D.
Generates production-quality binary glTF 2.0 (.glb) models for:
- Environment (plot, raised bed, soils, fence, pathway, compost, seed box)
- Tools (watering can, shovel, hoe, harvest basket, seed packets)
- Crops (Lettuce, Tomato, Carrot) across 4 growth stages (Seeded, Sprout, Growing, Mature)
- Collectibles & Seed packets
All pivots are normalized at the ground base (Y=0, centered at X=0, Z=0).
"""

import os
import math
import struct
import json

OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../assets/farming"))

class GLBBuilder:
    def __init__(self, model_name="Model"):
        self.name = model_name
        self.materials = []
        self.mat_map = {}
        self.primitives = []
        # Each primitive has: mat_idx, vertices (x,y,z), normals (x,y,z), indices (base 0)

    def get_material(self, name, r, g, b, roughness=0.88, metallic=0.0):
        key = (name, round(r, 3), round(g, 3), round(b, 3), round(roughness, 3), round(metallic, 3))
        if key in self.mat_map:
            return self.mat_map[key]
        idx = len(self.materials)
        self.mat_map[key] = idx
        self.materials.append({
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": [r, g, b, 1.0],
                "roughnessFactor": roughness,
                "metallicFactor": metallic
            },
            "doubleSided": True
        })
        self.primitives.append({"mat_idx": idx, "vertices": [], "normals": [], "indices": []})
        return idx

    def _get_prim(self, mat_idx):
        return self.primitives[mat_idx]

    def add_box(self, cx, cy, cz, sx, sy, sz, mat_idx, rx=0.0, ry=0.0, rz=0.0):
        prim = self._get_prim(mat_idx)
        hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
        
        # 6 faces * 4 verts = 24 verts
        # Define face normals and 4 vertices per face
        faces = [
            # Front (+Z)
            (0, 0, 1, [(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]),
            # Back (-Z)
            (0, 0, -1, [(-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz), (hx, -hy, -hz)]),
            # Top (+Y)
            (0, 1, 0, [(-hx, hy, -hz), (-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz)]),
            # Bottom (-Y)
            (0, -1, 0, [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)]),
            # Right (+X)
            (1, 0, 0, [(hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (hx, -hy, hz)]),
            # Left (-X)
            (-1, 0, 0, [(-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz)]),
        ]
        
        cos_y, sin_y = math.cos(ry), math.sin(ry)
        cos_x, sin_x = math.cos(rx), math.sin(rx)
        cos_z, sin_z = math.cos(rz), math.sin(rz)
        
        def rot(x, y, z):
            # Rot X
            y, z = y * cos_x - z * sin_x, y * sin_x + z * cos_x
            # Rot Y
            x, z = x * cos_y + z * sin_y, -x * sin_y + z * cos_y
            # Rot Z
            x, y = x * cos_z - y * sin_z, x * sin_z + y * cos_z
            return x, y, z

        for nx, ny, nz, quad in faces:
            rnx, rny, rnz = rot(nx, ny, nz)
            base_idx = len(prim["vertices"]) // 3
            for vx, vy, vz in quad:
                rx_v, ry_v, rz_v = rot(vx, vy, vz)
                prim["vertices"].extend([cx + rx_v, cy + ry_v, cz + rz_v])
                prim["normals"].extend([rnx, rny, rnz])
            prim["indices"].extend([base_idx, base_idx + 1, base_idx + 2, base_idx, base_idx + 2, base_idx + 3])

    def add_cylinder(self, cx, cy, cz, radius, height, mat_idx, segments=12, top_radius=None):
        if top_radius is None:
            top_radius = radius
        prim = self._get_prim(mat_idx)
        hh = height * 0.5
        
        # Sides
        for i in range(segments):
            a0 = (i / segments) * 2 * math.pi
            a1 = ((i + 1) / segments) * 2 * math.pi
            c0, s0 = math.cos(a0), math.sin(a0)
            c1, s1 = math.cos(a1), math.sin(a1)
            
            # 4 vertices per quad
            base_idx = len(prim["vertices"]) // 3
            prim["vertices"].extend([
                cx + c0 * radius, cy - hh, cz + s0 * radius,
                cx + c1 * radius, cy - hh, cz + s1 * radius,
                cx + c1 * top_radius, cy + hh, cz + s1 * top_radius,
                cx + c0 * top_radius, cy + hh, cz + s0 * top_radius
            ])
            prim["normals"].extend([c0, 0, s0, c1, 0, s1, c1, 0, s1, c0, 0, s0])
            prim["indices"].extend([base_idx, base_idx + 1, base_idx + 2, base_idx, base_idx + 2, base_idx + 3])
            
        # Top cap
        if top_radius > 0:
            top_center = len(prim["vertices"]) // 3
            prim["vertices"].extend([cx, cy + hh, cz])
            prim["normals"].extend([0, 1, 0])
            for i in range(segments):
                a = (i / segments) * 2 * math.pi
                prim["vertices"].extend([cx + math.cos(a) * top_radius, cy + hh, cz + math.sin(a) * top_radius])
                prim["normals"].extend([0, 1, 0])
            for i in range(segments):
                i0 = top_center + 1 + i
                i1 = top_center + 1 + ((i + 1) % segments)
                prim["indices"].extend([top_center, i0, i1])

        # Bottom cap
        if radius > 0:
            bot_center = len(prim["vertices"]) // 3
            prim["vertices"].extend([cx, cy - hh, cz])
            prim["normals"].extend([0, -1, 0])
            for i in range(segments):
                a = (i / segments) * 2 * math.pi
                prim["vertices"].extend([cx + math.cos(a) * radius, cy - hh, cz + math.sin(a) * radius])
                prim["normals"].extend([0, -1, 0])
            for i in range(segments):
                i0 = bot_center + 1 + i
                i1 = bot_center + 1 + ((i + 1) % segments)
                prim["indices"].extend([bot_center, i1, i0])

    def add_sphere(self, cx, cy, cz, radius, mat_idx, segments=12, rings=8, scale_x=1.0, scale_y=1.0, scale_z=1.0):
        prim = self._get_prim(mat_idx)
        base_v = len(prim["vertices"]) // 3
        
        for r in range(rings + 1):
            theta = (r / rings) * math.pi
            sin_t = math.sin(theta)
            cos_t = math.cos(theta)
            for s in range(segments + 1):
                phi = (s / segments) * 2 * math.pi
                x = math.cos(phi) * sin_t
                y = cos_t
                z = math.sin(phi) * sin_t
                prim["vertices"].extend([cx + x * radius * scale_x, cy + y * radius * scale_y, cz + z * radius * scale_z])
                prim["normals"].extend([x, y, z])
                
        for r in range(rings):
            for s in range(segments):
                p0 = base_v + r * (segments + 1) + s
                p1 = p0 + 1
                p2 = p0 + (segments + 1)
                p3 = p2 + 1
                prim["indices"].extend([p0, p2, p1, p1, p2, p3])

    def add_cone(self, cx, cy, cz, radius, height, mat_idx, segments=10):
        self.add_cylinder(cx, cy, cz, radius, height, mat_idx, segments=segments, top_radius=0.0)

    def export(self, filepath):
        bin_data = bytearray()
        buffer_views = []
        accessors = []
        mesh_primitives = []
        
        for prim in self.primitives:
            if len(prim["indices"]) == 0:
                continue
            
            # Vertices
            v_bytes = struct.pack(f"<{len(prim['vertices'])}f", *prim["vertices"])
            v_offset = len(bin_data)
            bin_data.extend(v_bytes)
            while len(bin_data) % 4 != 0: bin_data.append(0)
            v_bv_idx = len(buffer_views)
            buffer_views.append({
                "buffer": 0, "byteOffset": v_offset, "byteLength": len(v_bytes), "target": 34962
            })
            
            # Min & Max
            xs = prim["vertices"][0::3]
            ys = prim["vertices"][1::3]
            zs = prim["vertices"][2::3]
            min_v = [min(xs), min(ys), min(zs)]
            max_v = [max(xs), max(ys), max(zs)]
            
            v_acc_idx = len(accessors)
            accessors.append({
                "bufferView": v_bv_idx, "byteOffset": 0, "componentType": 5126,
                "count": len(prim["vertices"]) // 3, "type": "VEC3",
                "min": min_v, "max": max_v
            })
            
            # Normals
            n_bytes = struct.pack(f"<{len(prim['normals'])}f", *prim["normals"])
            n_offset = len(bin_data)
            bin_data.extend(n_bytes)
            while len(bin_data) % 4 != 0: bin_data.append(0)
            n_bv_idx = len(buffer_views)
            buffer_views.append({
                "buffer": 0, "byteOffset": n_offset, "byteLength": len(n_bytes), "target": 34962
            })
            n_acc_idx = len(accessors)
            accessors.append({
                "bufferView": n_bv_idx, "byteOffset": 0, "componentType": 5126,
                "count": len(prim["normals"]) // 3, "type": "VEC3"
            })
            
            # Indices
            i_bytes = struct.pack(f"<{len(prim['indices'])}H", *prim["indices"])
            i_offset = len(bin_data)
            bin_data.extend(i_bytes)
            while len(bin_data) % 4 != 0: bin_data.append(0)
            i_bv_idx = len(buffer_views)
            buffer_views.append({
                "buffer": 0, "byteOffset": i_offset, "byteLength": len(i_bytes), "target": 34963
            })
            i_acc_idx = len(accessors)
            accessors.append({
                "bufferView": i_bv_idx, "byteOffset": 0, "componentType": 5123,
                "count": len(prim["indices"]), "type": "SCALAR"
            })
            
            mesh_primitives.append({
                "attributes": {"POSITION": v_acc_idx, "NORMAL": n_acc_idx},
                "indices": i_acc_idx,
                "material": prim["mat_idx"]
            })
            
        gltf = {
            "asset": {"version": "2.0", "generator": "CoupleChaos_FarmingAssetPack_MVP"},
            "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": [{"mesh": 0, "name": self.name}],
            "meshes": [{"name": self.name, "primitives": mesh_primitives}],
            "materials": self.materials,
            "buffers": [{"byteLength": len(bin_data)}],
            "bufferViews": buffer_views,
            "accessors": accessors
        }
        
        json_bytes = json.dumps(gltf, separators=(',', ':')).encode('utf-8')
        while len(json_bytes) % 4 != 0:
            json_bytes += b' '
            
        total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_data)
        header = struct.pack('<4sII', b'glTF', 2, total_len)
        json_chunk = struct.pack('<II', len(json_bytes), 0x4E4F534A) + json_bytes
        bin_chunk = struct.pack('<II', len(bin_data), 0x004E4942) + bytes(bin_data)
        
        with open(filepath, 'wb') as f:
            f.write(header + json_chunk + bin_chunk)
        print(f"Exported: {filepath} ({total_len} bytes)")

def build_all():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # -------------------------------------------------------------
    # 1. Environment: Small Garden Plot
    # -------------------------------------------------------------
    b = GLBBuilder("PlotSmall")
    m_stone = b.get_material("StoneBorder", 0.76, 0.74, 0.72, roughness=0.92)
    m_soil = b.get_material("TilledSoil", 0.45, 0.31, 0.22, roughness=0.90)
    # Raised soil mound
    b.add_box(0, 0.08, 0, 1.15, 0.16, 1.15, m_soil)
    # Border stones around 4 sides
    for x in [-0.55, 0.55]:
        b.add_box(x, 0.10, 0, 0.14, 0.20, 1.25, m_stone)
    for z in [-0.55, 0.55]:
        b.add_box(0, 0.10, z, 1.25, 0.20, 0.14, m_stone)
    b.export(os.path.join(OUTPUT_DIR, "plot_small.glb"))

    # -------------------------------------------------------------
    # 2. Environment: Raised Garden Bed
    # -------------------------------------------------------------
    b = GLBBuilder("RaisedGardenBed")
    m_wood = b.get_material("PlanterWood", 0.65, 0.42, 0.25, roughness=0.85)
    m_soil = b.get_material("BedSoil", 0.38, 0.25, 0.18, roughness=0.92)
    # 4 Corner posts
    for x in [-0.62, 0.62]:
        for z in [-0.40, 0.40]:
            b.add_box(x, 0.22, z, 0.12, 0.44, 0.12, m_wood)
    # Side planks
    for z in [-0.40, 0.40]:
        b.add_box(0, 0.20, z, 1.16, 0.36, 0.06, m_wood)
    for x in [-0.62, 0.62]:
        b.add_box(x, 0.20, 0, 0.06, 0.36, 0.72, m_wood)
    # Soil inside
    b.add_box(0, 0.22, 0, 1.14, 0.32, 0.72, m_soil)
    b.export(os.path.join(OUTPUT_DIR, "raised_bed.glb"))

    # -------------------------------------------------------------
    # 3. Environment: Soils (Empty, Dry, Watered)
    # -------------------------------------------------------------
    for name, filename, color, rough in [
        ("SoilEmpty", "soil_empty.glb", (0.50, 0.36, 0.25), 0.90),
        ("SoilDry", "soil_dry.glb", (0.72, 0.58, 0.42), 0.95),
        ("SoilWatered", "soil_watered.glb", (0.28, 0.18, 0.12), 0.45)
    ]:
        b = GLBBuilder(name)
        m = b.get_material(name, *color, roughness=rough)
        b.add_box(0, 0.04, 0, 1.0, 0.08, 1.0, m)
        # 3 Furrow ridges
        for z in [-0.28, 0.0, 0.28]:
            b.add_box(0, 0.08, z, 0.96, 0.06, 0.18, m)
        b.export(os.path.join(OUTPUT_DIR, filename))

    # -------------------------------------------------------------
    # 4. Environment: Wooden Garden Fence
    # -------------------------------------------------------------
    b = GLBBuilder("GardenFence")
    m_wood = b.get_material("FenceWood", 0.78, 0.56, 0.36, roughness=0.88)
    # 2 Main posts
    for x in [-0.70, 0.70]:
        b.add_box(x, 0.42, 0, 0.10, 0.84, 0.10, m_wood)
        b.add_cylinder(x, 0.86, 0, 0.06, 0.06, m_wood, segments=8)
    # 2 Horizontal rails
    b.add_box(0, 0.28, 0, 1.34, 0.06, 0.05, m_wood)
    b.add_box(0, 0.62, 0, 1.34, 0.06, 0.05, m_wood)
    # 3 Vertical pickets
    for x in [-0.35, 0.0, 0.35]:
        b.add_box(x, 0.44, 0.03, 0.08, 0.74, 0.03, m_wood)
    b.export(os.path.join(OUTPUT_DIR, "garden_fence.glb"))

    # -------------------------------------------------------------
    # 5. Environment: Garden Pathway
    # -------------------------------------------------------------
    b = GLBBuilder("GardenPathway")
    m_stone1 = b.get_material("PaverPeach", 0.86, 0.62, 0.52, roughness=0.92)
    m_stone2 = b.get_material("PaverSand", 0.78, 0.70, 0.58, roughness=0.92)
    b.add_box(-0.25, 0.02, -0.22, 0.38, 0.04, 0.28, m_stone1, ry=0.08)
    b.add_box(0.24, 0.02, -0.18, 0.34, 0.04, 0.32, m_stone2, ry=-0.05)
    b.add_box(-0.18, 0.02, 0.22, 0.36, 0.04, 0.30, m_stone2, ry=0.12)
    b.add_box(0.25, 0.02, 0.24, 0.35, 0.04, 0.28, m_stone1, ry=-0.08)
    b.export(os.path.join(OUTPUT_DIR, "garden_pathway.glb"))

    # -------------------------------------------------------------
    # 6. Environment: Compost Bag
    # -------------------------------------------------------------
    b = GLBBuilder("CompostBag")
    m_burlap = b.get_material("Burlap", 0.82, 0.70, 0.52, roughness=0.95)
    m_tie = b.get_material("CordTie", 0.45, 0.32, 0.20, roughness=0.85)
    m_leaf = b.get_material("LeafTag", 0.42, 0.75, 0.40, roughness=0.88)
    # Bag body
    b.add_box(0, 0.24, 0, 0.38, 0.48, 0.26, m_burlap)
    # Crimped/tied neck
    b.add_cylinder(0, 0.49, 0, 0.09, 0.04, m_tie, segments=10)
    # Gathered top rim
    b.add_box(0, 0.53, 0, 0.24, 0.06, 0.16, m_burlap)
    # Organic leaf emblem
    b.add_box(0, 0.26, 0.135, 0.16, 0.12, 0.01, m_leaf)
    b.export(os.path.join(OUTPUT_DIR, "compost_bag.glb"))

    # -------------------------------------------------------------
    # 7. Environment: Seed Storage Box
    # -------------------------------------------------------------
    b = GLBBuilder("SeedStorageBox")
    m_wood = b.get_material("CrateWood", 0.72, 0.50, 0.30, roughness=0.85)
    m_latch = b.get_material("BrassLatch", 0.95, 0.80, 0.25, roughness=0.35, metallic=0.7)
    # Main box chest
    b.add_box(0, 0.14, 0, 0.56, 0.28, 0.38, m_wood)
    # Box lid
    b.add_box(0, 0.29, 0, 0.58, 0.04, 0.40, m_wood)
    # Metal latch
    b.add_box(0, 0.22, 0.195, 0.04, 0.07, 0.015, m_latch)
    b.export(os.path.join(OUTPUT_DIR, "seed_storage_box.glb"))

    # -------------------------------------------------------------
    # 8. Tool: Watering Can
    # -------------------------------------------------------------
    b = GLBBuilder("ToolWateringCan")
    m_metal = b.get_material("MintTeal", 0.40, 0.76, 0.70, roughness=0.55, metallic=0.3)
    m_rose = b.get_material("BrassRose", 0.96, 0.82, 0.28, roughness=0.40, metallic=0.6)
    # Can body
    b.add_cylinder(0, 0.16, 0, 0.13, 0.26, m_metal, segments=12)
    # Spout (angled cylinder)
    b.add_cylinder(0.18, 0.22, 0, 0.03, 0.26, m_metal, segments=8)
    # Rose sprinkler head
    b.add_cylinder(0.28, 0.32, 0, 0.055, 0.03, m_rose, segments=10)
    # Arch handle
    b.add_box(-0.16, 0.18, 0, 0.03, 0.24, 0.03, m_metal)
    b.add_box(-0.06, 0.31, 0, 0.20, 0.03, 0.03, m_metal)
    b.export(os.path.join(OUTPUT_DIR, "tool_watering_can.glb"))

    # -------------------------------------------------------------
    # 9. Tool: Shovel
    # -------------------------------------------------------------
    b = GLBBuilder("ToolShovel")
    m_shaft = b.get_material("ShaftAshWood", 0.82, 0.68, 0.48, roughness=0.85)
    m_steel = b.get_material("SpadeSteel", 0.50, 0.55, 0.58, roughness=0.45, metallic=0.5)
    # Shaft
    b.add_cylinder(0, 0.45, 0, 0.018, 0.70, m_shaft, segments=8)
    # T-handle
    b.add_cylinder(0, 0.81, 0, 0.02, 0.16, m_shaft, segments=8)
    # Spade blade
    b.add_box(0, 0.10, 0, 0.18, 0.20, 0.02, m_steel)
    b.add_cone(0, 0.0, 0, 0.09, 0.08, m_steel, segments=8)
    b.export(os.path.join(OUTPUT_DIR, "tool_shovel.glb"))

    # -------------------------------------------------------------
    # 10. Tool: Hoe
    # -------------------------------------------------------------
    b = GLBBuilder("ToolHoe")
    m_shaft = b.get_material("HoeWood", 0.82, 0.68, 0.48, roughness=0.85)
    m_iron = b.get_material("HoeIron", 0.35, 0.38, 0.40, roughness=0.50, metallic=0.6)
    # Long handle
    b.add_cylinder(0, 0.50, 0, 0.018, 0.95, m_shaft, segments=8)
    # Angled ferrule & blade
    b.add_box(0, 0.05, 0.06, 0.18, 0.10, 0.025, m_iron)
    b.export(os.path.join(OUTPUT_DIR, "tool_hoe.glb"))

    # -------------------------------------------------------------
    # 11. Tool: Harvest Basket
    # -------------------------------------------------------------
    b = GLBBuilder("ToolHarvestBasket")
    m_wicker = b.get_material("WovenWicker", 0.80, 0.64, 0.42, roughness=0.92)
    # Basket body
    b.add_box(0, 0.11, 0, 0.38, 0.22, 0.28, m_wicker)
    # Arched handle
    b.add_box(0, 0.28, 0, 0.34, 0.03, 0.03, m_wicker)
    for x in [-0.17, 0.17]:
        b.add_box(x, 0.20, 0, 0.03, 0.18, 0.03, m_wicker)
    b.export(os.path.join(OUTPUT_DIR, "tool_harvest_basket.glb"))

    # -------------------------------------------------------------
    # 12. Tool: Seed Packets Display
    # -------------------------------------------------------------
    b = GLBBuilder("ToolSeedPackets")
    m_box = b.get_material("TrayWood", 0.70, 0.50, 0.32, roughness=0.88)
    m_p1 = b.get_material("PackLettuce", 0.42, 0.82, 0.45, roughness=0.85)
    m_p2 = b.get_material("PackTomato", 0.92, 0.32, 0.25, roughness=0.85)
    m_p3 = b.get_material("PackCarrot", 0.96, 0.58, 0.18, roughness=0.85)
    # Wooden display tray
    b.add_box(0, 0.04, 0, 0.32, 0.08, 0.20, m_box)
    # 3 Paper packets leaning inside
    b.add_box(-0.08, 0.11, 0, 0.07, 0.12, 0.015, m_p1)
    b.add_box(0.0, 0.115, 0.01, 0.07, 0.12, 0.015, m_p2)
    b.add_box(0.08, 0.11, 0.02, 0.07, 0.12, 0.015, m_p3)
    b.export(os.path.join(OUTPUT_DIR, "tool_seed_packets.glb"))

    # -------------------------------------------------------------
    # 13. Collectibles: Lettuce, Tomato, Carrot & Seed Packets
    # -------------------------------------------------------------
    # Collectible: Lettuce
    b = GLBBuilder("CollectibleLettuce")
    m_green_outer = b.get_material("LettuceDark", 0.32, 0.72, 0.34, roughness=0.88)
    m_green_inner = b.get_material("LettuceHeart", 0.65, 0.92, 0.50, roughness=0.88)
    b.add_sphere(0, 0.10, 0, 0.11, m_green_outer, scale_y=0.8)
    b.add_sphere(0, 0.12, 0, 0.08, m_green_inner, scale_y=0.9)
    # Stem cut base
    b.add_cylinder(0, 0.02, 0, 0.035, 0.04, m_green_inner)
    b.export(os.path.join(OUTPUT_DIR, "collectible_lettuce.glb"))

    # Collectible: Tomato
    b = GLBBuilder("CollectibleTomato")
    m_red = b.get_material("TomatoRed", 0.92, 0.22, 0.18, roughness=0.45)
    m_calyx = b.get_material("CalyxGreen", 0.30, 0.65, 0.25, roughness=0.85)
    b.add_sphere(0, 0.08, 0, 0.08, m_red, scale_y=0.9)
    # 4-star calyx leaves & stem
    for deg in [0, 90, 180, 270]:
        rad = math.radians(deg)
        b.add_box(math.cos(rad)*0.03, 0.155, math.sin(rad)*0.03, 0.04, 0.008, 0.015, m_calyx)
    b.add_cylinder(0, 0.17, 0, 0.008, 0.03, m_calyx)
    b.export(os.path.join(OUTPUT_DIR, "collectible_tomato.glb"))

    # Collectible: Carrot
    b = GLBBuilder("CollectibleCarrot")
    m_orange = b.get_material("CarrotOrange", 0.96, 0.52, 0.12, roughness=0.82)
    m_frond = b.get_material("CarrotFrond", 0.35, 0.75, 0.30, roughness=0.85)
    # Tapered root
    b.add_cone(0, 0.10, 0, 0.04, 0.20, m_orange, segments=10)
    # Frond tufts
    b.add_cylinder(0, 0.23, 0, 0.015, 0.08, m_frond)
    b.add_sphere(0, 0.28, 0, 0.04, m_frond, scale_y=1.5)
    b.export(os.path.join(OUTPUT_DIR, "collectible_carrot.glb"))

    # Seed Packets (3 individual items)
    for name, filename, color in [
        ("SeedPacketLettuce", "seed_packet_lettuce.glb", (0.38, 0.78, 0.42)),
        ("SeedPacketTomato", "seed_packet_tomato.glb", (0.92, 0.28, 0.22)),
        ("SeedPacketCarrot", "seed_packet_carrot.glb", (0.96, 0.54, 0.14))
    ]:
        b = GLBBuilder(name)
        m_paper = b.get_material("PaperPack", 0.96, 0.94, 0.88, roughness=0.90)
        m_tag = b.get_material("CropTag", *color, roughness=0.85)
        # Envelope pouch
        b.add_box(0, 0.08, 0, 0.10, 0.16, 0.015, m_paper)
        # Color label with crop banner
        b.add_box(0, 0.085, 0.009, 0.08, 0.09, 0.003, m_tag)
        b.export(os.path.join(OUTPUT_DIR, filename))

    # -------------------------------------------------------------
    # 14. Crops across 4 Stages (Lettuce, Tomato, Carrot)
    # -------------------------------------------------------------
    # Shared Seeded Mound
    for crop in ["lettuce", "tomato", "carrot"]:
        b = GLBBuilder(f"Crop_{crop.capitalize()}_Seeded")
        m_soil = b.get_material("SeededMound", 0.44, 0.30, 0.20, roughness=0.92)
        m_seed = b.get_material("SeedFurrow", 0.25, 0.18, 0.12, roughness=0.95)
        b.add_sphere(0, 0.02, 0, 0.14, m_soil, scale_y=0.35)
        b.add_box(0, 0.05, 0, 0.16, 0.02, 0.04, m_seed)
        b.export(os.path.join(OUTPUT_DIR, f"crop_{crop}_seeded.glb"))

    # Crop: Lettuce Sprout, Growing, Mature
    # Sprout
    b = GLBBuilder("Crop_Lettuce_Sprout")
    m_stem = b.get_material("SproutStem", 0.60, 0.88, 0.45, roughness=0.85)
    b.add_cylinder(0, 0.04, 0, 0.008, 0.08, m_stem)
    b.add_sphere(-0.025, 0.07, 0, 0.02, m_stem, scale_y=0.6)
    b.add_sphere(0.025, 0.07, 0, 0.02, m_stem, scale_y=0.6)
    b.export(os.path.join(OUTPUT_DIR, "crop_lettuce_sprout.glb"))

    # Growing
    b = GLBBuilder("Crop_Lettuce_Growing")
    m_leaf = b.get_material("LettuceMid", 0.45, 0.82, 0.40, roughness=0.88)
    b.add_sphere(0, 0.07, 0, 0.07, m_leaf, scale_y=0.7)
    for deg in [0, 72, 144, 216, 288]:
        rad = math.radians(deg)
        b.add_sphere(math.cos(rad)*0.05, 0.06, math.sin(rad)*0.05, 0.035, m_leaf, scale_y=0.5)
    b.export(os.path.join(OUTPUT_DIR, "crop_lettuce_growing.glb"))

    # Mature
    b = GLBBuilder("Crop_Lettuce_Mature")
    m_out = b.get_material("LettuceHeadDark", 0.32, 0.72, 0.34, roughness=0.88)
    m_in = b.get_material("LettuceHeadLight", 0.62, 0.90, 0.48, roughness=0.88)
    b.add_sphere(0, 0.12, 0, 0.14, m_out, scale_y=0.85)
    b.add_sphere(0, 0.15, 0, 0.09, m_in, scale_y=0.9)
    for deg in [0, 60, 120, 180, 240, 300]:
        rad = math.radians(deg)
        b.add_sphere(math.cos(rad)*0.10, 0.09, math.sin(rad)*0.10, 0.06, m_out, scale_y=0.5)
    b.export(os.path.join(OUTPUT_DIR, "crop_lettuce_mature.glb"))

    # Crop: Tomato Sprout, Growing, Mature
    # Sprout
    b = GLBBuilder("Crop_Tomato_Sprout")
    m_stem = b.get_material("TomatoShoot", 0.45, 0.78, 0.35, roughness=0.85)
    b.add_cylinder(0, 0.06, 0, 0.009, 0.12, m_stem)
    b.add_box(0.03, 0.11, 0, 0.04, 0.01, 0.02, m_stem)
    b.add_box(-0.03, 0.09, 0, 0.04, 0.01, 0.02, m_stem)
    b.export(os.path.join(OUTPUT_DIR, "crop_tomato_sprout.glb"))

    # Growing
    b = GLBBuilder("Crop_Tomato_Growing")
    m_stem = b.get_material("TomatoStem", 0.38, 0.70, 0.30, roughness=0.85)
    m_leaf = b.get_material("TomatoLeaves", 0.32, 0.65, 0.25, roughness=0.88)
    m_flower = b.get_material("BlossomYellow", 0.98, 0.88, 0.25, roughness=0.85)
    m_green_tom = b.get_material("UnripeTomato", 0.55, 0.82, 0.35, roughness=0.60)
    # Vine stalk
    b.add_cylinder(0, 0.18, 0, 0.014, 0.36, m_stem)
    # Foliage cluster
    b.add_sphere(0, 0.22, 0, 0.12, m_leaf)
    # Little yellow blossoms & baby green tomatoes
    b.add_sphere(0.08, 0.25, 0.06, 0.025, m_flower)
    b.add_sphere(-0.07, 0.18, 0.08, 0.028, m_green_tom)
    b.export(os.path.join(OUTPUT_DIR, "crop_tomato_growing.glb"))

    # Mature
    b = GLBBuilder("Crop_Tomato_Mature")
    m_stake = b.get_material("BambooStake", 0.75, 0.65, 0.42, roughness=0.85)
    m_stem = b.get_material("TomatoStem", 0.35, 0.68, 0.28, roughness=0.85)
    m_leaf = b.get_material("TomatoLush", 0.30, 0.62, 0.24, roughness=0.88)
    m_ripe = b.get_material("RipeTomato", 0.94, 0.20, 0.15, roughness=0.45)
    # Garden stake
    b.add_cylinder(-0.06, 0.32, -0.04, 0.012, 0.64, m_stake)
    # Lush vine
    b.add_cylinder(0, 0.25, 0, 0.018, 0.50, m_stem)
    b.add_sphere(0, 0.30, 0, 0.18, m_leaf)
    b.add_sphere(0, 0.42, 0, 0.12, m_leaf)
    # Ripe crimson tomato cluster
    b.add_sphere(0.08, 0.22, 0.10, 0.055, m_ripe)
    b.add_sphere(-0.09, 0.24, 0.08, 0.050, m_ripe)
    b.add_sphere(0.02, 0.16, 0.12, 0.048, m_ripe)
    b.add_sphere(0.07, 0.34, 0.06, 0.042, m_ripe)
    b.export(os.path.join(OUTPUT_DIR, "crop_tomato_mature.glb"))

    # Crop: Carrot Sprout, Growing, Mature
    # Sprout
    b = GLBBuilder("Crop_Carrot_Sprout")
    m_feathery = b.get_material("CarrotSprout", 0.40, 0.82, 0.35, roughness=0.85)
    b.add_cylinder(0, 0.04, 0, 0.006, 0.08, m_feathery)
    b.add_cone(0, 0.07, 0, 0.02, 0.05, m_feathery)
    b.export(os.path.join(OUTPUT_DIR, "crop_carrot_sprout.glb"))

    # Growing
    b = GLBBuilder("Crop_Carrot_Growing")
    m_fronds = b.get_material("CarrotFrondsMid", 0.35, 0.75, 0.30, roughness=0.88)
    for deg in [0, 90, 180, 270]:
        rad = math.radians(deg)
        b.add_cylinder(math.cos(rad)*0.03, 0.10, math.sin(rad)*0.03, 0.008, 0.20, m_fronds)
    b.add_sphere(0, 0.16, 0, 0.08, m_fronds, scale_y=1.4)
    b.export(os.path.join(OUTPUT_DIR, "crop_carrot_growing.glb"))

    # Mature
    b = GLBBuilder("Crop_Carrot_Mature")
    m_soil = b.get_material("MoundSoil", 0.40, 0.28, 0.18, roughness=0.92)
    m_orange = b.get_material("CarrotCrown", 0.96, 0.50, 0.12, roughness=0.80)
    m_leaf = b.get_material("CarrotFrondsLush", 0.30, 0.70, 0.26, roughness=0.88)
    # Soil mound & peeking carrot shoulder
    b.add_sphere(0, 0.02, 0, 0.12, m_soil, scale_y=0.4)
    b.add_cylinder(0, 0.04, 0, 0.045, 0.05, m_orange)
    # Tall bushy feathery fronds
    b.add_cylinder(0, 0.18, 0, 0.015, 0.25, m_leaf)
    b.add_sphere(0, 0.26, 0, 0.11, m_leaf, scale_y=1.5)
    b.add_sphere(0.05, 0.22, 0.04, 0.07, m_leaf, scale_y=1.3)
    b.add_sphere(-0.05, 0.22, -0.04, 0.07, m_leaf, scale_y=1.3)
    b.export(os.path.join(OUTPUT_DIR, "crop_carrot_mature.glb"))

    print("\nSUCCESS: All low-poly farming GLB assets generated!")

if __name__ == "__main__":
    build_all()
