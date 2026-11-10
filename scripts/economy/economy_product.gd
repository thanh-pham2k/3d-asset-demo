class_name EconomyProduct
extends Resource

## Data definition for purchasable goods, upgrades, furniture, and tools
## in the persistent economy of Couple Chaos.

@export var id: String = ""
@export var name: String = ""
@export var category: String = "general" # "food_ingredient", "repair_tool", "furniture", "business_upgrade", "house_upgrade"
@export var price: int = 10000
@export var description: String = ""
@export var is_unique: bool = false # If true, can only be purchased once (e.g. furniture, upgrades)
@export var target_system: String = "general" # "garage", "hutieu", "house", "general"

func _init(
	p_id := "",
	p_name := "",
	p_cat := "general",
	p_price := 10000,
	p_desc := "",
	p_unique := false,
	p_target := "general"
) -> void:
	id = p_id
	name = p_name
	category = p_cat
	price = p_price
	description = p_desc
	is_unique = p_unique
	target_system = p_target

static func create_default_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	
	var list: Array[EconomyProduct] = [
		# --- 1. Food Ingredients (Nguyên liệu nấu ăn) ---
		EconomyProduct.new(
			"ing_rice_noodle", "Bánh hủ tiếu tươi", "food_ingredient",
			15000, "Bánh hủ tiếu sợi dai truyền thống Sa Đéc", false, "hutieu"
		),
		EconomyProduct.new(
			"ing_fresh_shrimp", "Tôm sú tươi sống", "food_ingredient",
			30000, "Tôm sú Cà Mau tươi ngon ngọt thịt", false, "hutieu"
		),
		EconomyProduct.new(
			"ing_pork_ribs", "Sườn non heo sạch", "food_ingredient",
			35000, "Sườn heo non hầm nước lèo ngọt thanh", false, "hutieu"
		),
		EconomyProduct.new(
			"ing_cracklings", "Tóp mỡ giòn & hành phi", "food_ingredient",
			12000, "Tóp mỡ giòn rụm thơm nức mũi", false, "hutieu"
		),
		
		# --- 2. Repair Tools & Supplies (Dụng cụ sửa xe) ---
		EconomyProduct.new(
			"tool_patch_strip", "Miếng vá săm cao cấp", "repair_tool",
			10000, "Bộ 5 miếng vá cao su chịu nhiệt độ bền cao", false, "garage"
		),
		EconomyProduct.new(
			"tool_spare_tire", "Lốp xe máy không ruột", "repair_tool",
			45000, "Lốp xe chính hãng bám đường chống trơn trượt", false, "garage"
		),
		EconomyProduct.new(
			"tool_air_wrench", "Súng xiết bu-lông khí nén", "repair_tool",
			80000, "Dụng cụ tháo lắp bánh xe chuyên nghiệp nhanh chóng", true, "garage"
		),
		
		# --- 3. Furniture (Nội thất & Gia dụng) ---
		EconomyProduct.new(
			"furn_deluxe_sofa", "Sofa nệm xanh vintage", "furniture",
			150000, "Sofa êm ái cho phòng khách đôi lứa", true, "house"
		),
		EconomyProduct.new(
			"furn_wooden_bed", "Giường ngủ đôi gỗ sồi", "furniture",
			160000, "Giường ngủ đôi gỗ sồi kèm tab đầu giường", true, "house"
		),
		EconomyProduct.new(
			"furn_smart_tv", "Tivi LED 55 inch", "furniture",
			250000, "Màn hình giải trí xem phim buổi tối", true, "house"
		),
		EconomyProduct.new(
			"furn_inverter_fridge", "Tủ lạnh hai cánh Inverter", "furniture",
			300000, "Bảo quản nguyên liệu tươi lâu tiết kiệm điện", true, "house"
		),
		EconomyProduct.new(
			"furn_oak_table", "Bàn ăn gỗ sồi tự nhiên", "furniture",
			180000, "Bàn ăn ấm cúng cho hai vợ chồng", true, "house"
		),
		EconomyProduct.new(
			"furn_chair", "Ghế tựa đệm êm", "furniture",
			35000, "Ghế ngồi thư giãn đệm mút êm ái", false, "house"
		),
		EconomyProduct.new(
			"furn_wardrobe", "Tủ quần áo gỗ 2 cánh", "furniture",
			120000, "Tủ quần áo gỗ tự nhiên có ngăn kéo", true, "house"
		),
		EconomyProduct.new(
			"furn_coffee_table", "Bàn trà phòng khách", "furniture",
			50000, "Bàn trà nhỏ gọn uống trà đàm đạo", true, "house"
		),
		EconomyProduct.new(
			"furn_floor_lamp", "Đèn cây phòng khách", "furniture",
			40000, "Đèn đứng ánh sáng vàng ấm cúng", true, "house"
		),
		EconomyProduct.new(
			"furn_bookshelf", "Kệ sách đứng hiện đại", "furniture",
			70000, "Kệ sách nhiều tầng trưng bày sách và quà lưu niệm", true, "house"
		),
		EconomyProduct.new(
			"furn_potted_plant", "Chậu cây cảnh phong thủy", "furniture",
			30000, "Cây xanh thanh lọc không khí mang tài lộc", false, "house"
		),
		
		# --- 4. Business Upgrades (Nâng cấp tiệm kinh doanh) ---
		EconomyProduct.new(
			"upg_garage_second_bay", "Khoang sửa xe thứ 2", "business_upgrade",
			200000, "Mở rộng thêm 1 khoang phục vụ khách đôi", true, "garage"
		),
		EconomyProduct.new(
			"upg_garage_compressor", "Máy nén khí siêu tốc", "business_upgrade",
			120000, "Tăng tốc độ bơm hơi và áp suất tự động", true, "garage"
		),
		EconomyProduct.new(
			"upg_hutieu_extra_table", "Bàn ăn ngoài trời thứ 4", "business_upgrade",
			150000, "Tăng công suất đón thêm nhiều lượt khách", true, "hutieu"
		),
		EconomyProduct.new(
			"upg_hutieu_quick_stove", "Bếp hầm áp suất đa năng", "business_upgrade",
			140000, "Rút ngắn thời gian trụng bánh và nấu nước lèo", true, "hutieu"
		),
		
		# --- 5. House Upgrades (Nâng cấp ngôi nhà tân hôn) ---
		EconomyProduct.new(
			"upg_house_level_2", "Nâng cấp nhà Cấp 2: Căn hộ ấm cúng", "house_upgrade",
			75000, "Nâng cấp nhà chính, mở rộng phòng khách và bếp tiện nghi", true, "house"
		),
		EconomyProduct.new(
			"upg_house_level_3", "Nâng cấp nhà Cấp 3: Biệt thự sân vườn", "house_upgrade",
			150000, "Xây thêm phòng đọc sách ngắm cảnh và sân vườn xanh mát", true, "house"
		),
		EconomyProduct.new(
			"upg_house_tile_yard", "Lát gạch sân trước nhà", "house_upgrade",
			180000, "Sân trước sạch đẹp với gạch bông cổ điển", true, "house"
		),
		EconomyProduct.new(
			"upg_house_flower_garden", "Vườn hoa rực rỡ quanh sân", "house_upgrade",
			120000, "Trồng thêm luống hoa mười giờ và hoa giấy", true, "house"
		),
		EconomyProduct.new(
			"upg_house_modern_kitchen", "Mở rộng gian bếp hiện đại", "house_upgrade",
			350000, "Kệ bếp ốp đá hoa cương sang trọng", true, "house"
		)
	]
	
	for prod in list:
		catalog[prod.id] = prod
	
	return catalog
