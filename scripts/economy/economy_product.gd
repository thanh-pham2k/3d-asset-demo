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
			"tool_repair_kit", "Bộ dụng cụ sửa xe", "repair_tool",
			10000, "Bộ dụng cụ sửa xe đa năng (Repair Kit) — mỗi lần sửa xe tiêu hao 1 bộ", false, "garage"
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
		
		# Decorative bathroom and utility furniture
		EconomyProduct.new("furn_bath_sink", "Chậu rửa phòng tắm", "furniture", 60000, "Đồ trang trí low-poly cho ngôi nhà", true, "house"),
		EconomyProduct.new("furn_bath_mirror", "Gương phòng tắm", "furniture", 35000, "Đồ trang trí low-poly cho ngôi nhà", true, "house"),
		EconomyProduct.new("furn_shower", "Vòi sen", "furniture", 80000, "Đồ trang trí low-poly cho ngôi nhà", true, "house"),
		EconomyProduct.new("furn_toilet", "Bồn cầu", "furniture", 90000, "Đồ trang trí low-poly cho ngôi nhà", true, "house"),
		EconomyProduct.new("furn_towel_rack", "Giá treo khăn", "furniture", 30000, "Đồ trang trí low-poly cho ngôi nhà", true, "house"),
		EconomyProduct.new("furn_washing_machine", "Máy giặt", "furniture", 120000, "Đồ trang trí low-poly cho ngôi nhà", true, "house"),
		EconomyProduct.new("furn_laundry_basket", "Giỏ đồ giặt", "furniture", 25000, "Đồ trang trí low-poly cho ngôi nhà", true, "house"),
		EconomyProduct.new("furn_clothes_hanger", "Giá treo quần áo", "furniture", 40000, "Đồ trang trí low-poly cho ngôi nhà", true, "house"),
		EconomyProduct.new("furn_broom", "Chổi quét nhà", "furniture", 12000, "Đồ trang trí low-poly cho ngôi nhà", true, "house"),
		EconomyProduct.new("furn_mop", "Cây lau nhà", "furniture", 14000, "Đồ trang trí low-poly cho ngôi nhà", true, "house"),

		# --- 4. Business Upgrades (Nâng cấp tiệm kinh doanh) ---
		# Motorcycle Shop: Additional bay, Better tools, Faster service
		EconomyProduct.new(
			"upg_garage_second_bay", "Khoang sửa xe mở rộng", "business_upgrade",
			150000, "Mở rộng thêm khoang sửa xe hoàn chỉnh, tăng gấp đôi lượng khách phục vụ cùng lúc", true, "garage"
		),
		EconomyProduct.new(
			"upg_garage_tools", "Bộ đồ nghề sửa xe cao cấp", "business_upgrade",
			80000, "Bộ dụng cụ thợ máy chuyên nghiệp, tăng 30% tiền công tip từ mỗi khách sửa xe", true, "garage"
		),
		EconomyProduct.new(
			"upg_garage_compressor", "Máy nén khí siêu tốc", "business_upgrade",
			120000, "Bơm lốp siêu tốc tự động, khách đến nhanh hơn và kiên nhẫn chờ đợi lâu hơn 40%", true, "garage"
		),
		
		# Hu Tieu Shop: Additional seating, Faster cooking equipment, Improved kitchen capacity
		EconomyProduct.new(
			"upg_hutieu_extra_table", "Bàn ăn ngoài trời thứ 4", "business_upgrade",
			120000, "Kê thêm bàn ăn số 4 và ghế tựa ngoài trời có dù che, tăng công suất đón khách", true, "hutieu"
		),
		EconomyProduct.new(
			"upg_hutieu_quick_stove", "Bếp trụng áp suất cao đa năng", "business_upgrade",
			100000, "Trụng hủ tiếu siêu nhanh 0.4s và tăng gấp đôi tốc độ chuẩn bị quán mở cửa", true, "hutieu"
		),
		EconomyProduct.new(
			"upg_hutieu_kitchen_capacity", "Quầy bếp dung tích lớn", "business_upgrade",
			140000, "Mở rộng quầy chế biến và tặng trà đá, khách kiên nhẫn hơn và tăng 25% doanh thu mỗi tô", true, "hutieu"
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
		),

		# --- 6. Pet System (Thú cưng & Vật dụng chăm sóc) ---
		EconomyProduct.new(
			"pet_cat_adoption", "Nhận nuôi mèo vàng Miu Miu", "pet",
			100000, "Nhận nuôi chú mèo mướp lông vàng đáng yêu về bầu bạn cùng gia đình", true, "house"
		),
		EconomyProduct.new(
			"pet_food_salmon", "Gói hạt cá hồi dinh dưỡng", "pet",
			15000, "Thức ăn hạt cá hồi tươi ngon bổ dưỡng cho mèo cưng", false, "house"
		),
		EconomyProduct.new(
			"furn_pet_food_bowl", "Bát ăn gốm sứ cho mèo", "pet",
			25000, "Bát ăn gốm sứ men ngọc chống trượt đựng hạt cá hồi", true, "house"
		),
		EconomyProduct.new(
			"furn_pet_water_bowl", "Bát nước mát gốm sứ", "pet",
			20000, "Bát đựng nước uống trong lành sạch sẽ cho thú cưng", true, "house"
		),
		EconomyProduct.new(
			"furn_pet_bed", "Nệm ngủ thú cưng êm ái", "pet",
			60000, "Nệm tròn lót bông nỉ mềm mại cho mèo cuộn tròn ngủ ngon", true, "house"
		),
		EconomyProduct.new(
			"furn_pet_toy_wand", "Cần câu lông vũ đùa mèo", "pet",
			30000, "Đồ chơi tương tác cần câu lông vũ đung đưa kèm chuông", true, "house"
		),
		EconomyProduct.new(
			"furn_pet_scratching_post", "Trụ cào móng dây thừng", "pet",
			50000, "Trụ quấn dây thừng tự nhiên cho mèo mài móng và tập thể dục", true, "house"
		),
		EconomyProduct.new(
			"furn_pet_toy_ball", "Quả bóng len lục lạc", "pet",
			15000, "Quả bóng len lăn tròn phát ra tiếng chuông vui nhộn", true, "house"
		),

		# --- 7. Farming System (Hạt giống & Nông sản vườn nhà) ---
		EconomyProduct.new(
			"seed_lettuce", "Hạt giống rau cải xanh", "farming_seed",
			5000, "Túi hạt giống cải xanh ngọt, lớn nhanh sau 1 ngày chăm sóc", false, "house"
		),
		EconomyProduct.new(
			"seed_tomato", "Hạt giống cà chua bi", "farming_seed",
			8000, "Túi hạt giống cà chua bi đỏ mọng sai trĩu quả", false, "house"
		),
		EconomyProduct.new(
			"seed_carrot", "Hạt giống cà rốt ngọt", "farming_seed",
			6000, "Túi hạt giống cà rốt củ to giòn ngọt giàu vitamin", false, "house"
		),
		EconomyProduct.new(
			"produce_lettuce", "Rau cải xanh tươi", "produce",
			12000, "Bó rau cải xanh tươi mơn mởn thu hoạch từ vườn nhà", false, "house"
		),
		EconomyProduct.new(
			"produce_tomato", "Cà chua bi chín mọng", "produce",
			18000, "Cà chua bi đỏ mọng ngọt thanh thu hoạch từ vườn nhà", false, "house"
		),
		EconomyProduct.new(
			"produce_carrot", "Củ cà rốt tươi giòn", "produce",
			15000, "Củ cà rốt cam tươi giòn ngọt thu hoạch từ vườn nhà", false, "house"
		)
	]
	
	for prod in list:
		catalog[prod.id] = prod
	
	return catalog
