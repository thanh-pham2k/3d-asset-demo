class_name NPCData
extends Resource

## Data-driven definition for a neighborhood NPC, including personality, appearance,
## dialogue lines, and daily routine schedule.

@export var id: String = ""
@export var name: String = ""
@export var role: String = ""
@export var gender: String = "boy" # "boy" or "girl"
@export var shirt_color: Color = Color("f4c451")
@export var pants_color: Color = Color("39465e")
@export var hair_color: Color = Color("594339")
@export var skin_color: Color = Color("f4c9ab")
@export var accessory: String = "none" # "none", "conical_hat", "cap", "apron", "glasses", "backpack"

@export var home_position: Vector3 = Vector3.ZERO
@export var work_position: Vector3 = Vector3.ZERO
@export var lunch_position: Vector3 = Vector3.ZERO
@export var leisure_position: Vector3 = Vector3.ZERO

# Dialogues organized by time-of-day: "morning", "noon", "evening", "night"
@export var dialogues: Dictionary = {}

# Daily schedule entries sorted by start_hour (0.0 to 24.0)
# Each entry: { "start_hour": float, "end_hour": float, "activity": String, "position": Vector3, "dialogue_key": String, "wait_duration": float }
@export var schedule: Array[Dictionary] = []

static func create_default_database() -> Array[NPCData]:
	var list: Array[NPCData] = []

	# 1. Chú Ba - Motorcycle Mechanic at Repair Shop
	var chu_ba := NPCData.new()
	chu_ba.id = "chu_ba"
	chu_ba.name = "Chú Ba"
	chu_ba.role = "Thợ sửa xe máy"
	chu_ba.gender = "boy"
	chu_ba.shirt_color = Color("3a6b8c") # Mechanic blue
	chu_ba.pants_color = Color("2c3e50")
	chu_ba.accessory = "cap"
	chu_ba.home_position = Vector3(-39, 0.2, -72)
	chu_ba.work_position = Vector3(-105, 0.2, -14) # Garage
	chu_ba.lunch_position = Vector3(-50, 0.2, -22) # Hu Tieu stall
	chu_ba.leisure_position = Vector3(-100, 0.2, 22) # Food street cafe
	chu_ba.dialogues = {
		"morning": [
			"Chào hai đứa! Xe cộ chạy êm ru không? Cần tăng sên hay bơm bánh cứ ghé chú nha!",
			"Sáng sớm hít thở không khí xóm mình thích thật, chú chuẩn bị mở tiệm đây."
		],
		"noon": [
			"Giờ trưa làm tô hủ tiếu cô Bảy ấm bụng rồi chiều lại vá xe tiếp!",
			"Nắng gắt quá, hai đứa đi chợ nhớ ghé uống ly nước mía giải nhiệt nhé."
		],
		"evening": [
			"Xong một ngày lao động, ghé làm ly cà phê đá ngắm phố xá là nhất đời!",
			"Tối nay chú dọn đồ sớm, chúc hai đứa buổi tối vui vẻ nha."
		]
	}
	chu_ba.schedule = [
		{"start_hour": 6.0, "end_hour": 11.5, "activity": "work", "position": chu_ba.work_position, "dialogue_key": "morning", "wait_duration": 18.0},
		{"start_hour": 11.5, "end_hour": 14.0, "activity": "lunch", "position": chu_ba.lunch_position, "dialogue_key": "noon", "wait_duration": 15.0},
		{"start_hour": 14.0, "end_hour": 18.0, "activity": "work", "position": chu_ba.work_position, "dialogue_key": "noon", "wait_duration": 20.0},
		{"start_hour": 18.0, "end_hour": 21.0, "activity": "leisure", "position": chu_ba.leisure_position, "dialogue_key": "evening", "wait_duration": 12.0},
		{"start_hour": 21.0, "end_hour": 24.0, "activity": "home", "position": chu_ba.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 6.0, "activity": "home", "position": chu_ba.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(chu_ba)

	# 2. Cô Bảy - Hu Tieu Stall Owner
	var co_bay := NPCData.new()
	co_bay.id = "co_bay"
	co_bay.name = "Cô Bảy"
	co_bay.role = "Chủ quán hủ tiếu Nam Vang"
	co_bay.gender = "girl"
	co_bay.shirt_color = Color("e08b79") # Warm apricot
	co_bay.pants_color = Color("4a423d")
	co_bay.accessory = "apron"
	co_bay.home_position = Vector3(-58, 0.2, -72)
	co_bay.work_position = Vector3(-50, 0.2, -18) # Noodle stall
	co_bay.lunch_position = Vector3(31, 0.2, -28) # Wet market (buying fresh greens)
	co_bay.leisure_position = Vector3(42, 0.2, 40) # Park
	co_bay.dialogues = {
		"morning": [
			"Hủ tiếu nóng hổi vừa ra lò đây! Nước lèo hầm xương từ 4 giờ sáng ngọt thanh lắm đó!",
			"Hai đứa ăn tô hủ tiếu mực hay thập cẩm? Cô cho thêm nhiều tóp mỡ giòn rụm nha!"
		],
		"noon": [
			"Cô tranh thủ qua chợ mua thêm tôm tươi và rau cần tàu cho nồi nước lèo chiều nay.",
			"Ăn uống đúng giờ nghen hai đứa, bận mấy cũng phải giữ gìn sức khỏe đó!"
		],
		"evening": [
			"Hết sạch nồi nước lèo rồi! Dọn quán xong cô đi dạo công viên hóng gió chút đây.",
			"Tối rồi về nhà nghỉ ngơi sớm đi hai con, xóm mình tối nay gió mát lắm."
		]
	}
	co_bay.schedule = [
		{"start_hour": 6.0, "end_hour": 11.5, "activity": "work", "position": co_bay.work_position, "dialogue_key": "morning", "wait_duration": 20.0},
		{"start_hour": 11.5, "end_hour": 13.5, "activity": "lunch", "position": co_bay.lunch_position, "dialogue_key": "noon", "wait_duration": 14.0},
		{"start_hour": 13.5, "end_hour": 18.5, "activity": "work", "position": co_bay.work_position, "dialogue_key": "noon", "wait_duration": 20.0},
		{"start_hour": 18.5, "end_hour": 20.5, "activity": "leisure", "position": co_bay.leisure_position, "dialogue_key": "evening", "wait_duration": 15.0},
		{"start_hour": 20.5, "end_hour": 24.0, "activity": "home", "position": co_bay.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 6.0, "activity": "home", "position": co_bay.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(co_bay)

	# 3. Bác Năm - Retired Elder at Park & Pond
	var bac_nam := NPCData.new()
	bac_nam.id = "bac_nam"
	bac_nam.name = "Bác Năm"
	bac_nam.role = "Lão nông về hưu"
	bac_nam.gender = "boy"
	bac_nam.shirt_color = Color("8c7553") # Traditional brown áo bà ba
	bac_nam.pants_color = Color("383025")
	bac_nam.accessory = "conical_hat"
	bac_nam.home_position = Vector3(-64, 0.2, -40)
	bac_nam.work_position = Vector3(42, 0.2, 53) # Park promenade
	bac_nam.lunch_position = Vector3(-110, 0.2, 22) # Cafe on food street
	bac_nam.leisure_position = Vector3(54, 0.2, 60) # Park pond
	bac_nam.dialogues = {
		"morning": [
			"Sáng nào bác cũng ra hồ ngắm cá, tập dưỡng sinh. Ở quê thanh bình vầy là sướng nhất!",
			"Hai đứa dạo này chăm sóc nhà cửa khang trang ghê, bà con chòm xóm ai cũng khen."
		],
		"noon": [
			"Trưa nắng ngồi quán nước mía đầu phố nghe đài phát thanh, cuộc sống thảnh thơi quá con à.",
			"Uống miếng trà đá đi hai đứa, đừng chạy nhảy ngoài nắng kẻo cảm đó."
		],
		"evening": [
			"Chiều xuống gió hồ mát rượi, ngồi ngắm hoàng hôn ráng vàng trên mái ngói đẹp biết bao.",
			"Tối xóm mình yên tĩnh lắm, bác về cho mấy con chim ăn rồi nghỉ sớm đây."
		]
	}
	bac_nam.schedule = [
		{"start_hour": 6.0, "end_hour": 11.0, "activity": "leisure", "position": bac_nam.work_position, "dialogue_key": "morning", "wait_duration": 15.0},
		{"start_hour": 11.0, "end_hour": 14.0, "activity": "lunch", "position": bac_nam.lunch_position, "dialogue_key": "noon", "wait_duration": 18.0},
		{"start_hour": 14.0, "end_hour": 18.0, "activity": "leisure", "position": bac_nam.leisure_position, "dialogue_key": "evening", "wait_duration": 16.0},
		{"start_hour": 18.0, "end_hour": 24.0, "activity": "home", "position": bac_nam.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 6.0, "activity": "home", "position": bac_nam.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(bac_nam)

	# 4. Chị Lan - Banh Mi Vendor on Food Street
	var chi_lan := NPCData.new()
	chi_lan.id = "chi_lan"
	chi_lan.name = "Chị Lan"
	chi_lan.role = "Bán bánh mì thịt nướng"
	chi_lan.gender = "girl"
	chi_lan.shirt_color = Color("f3c442") # Bright sunny yellow
	chi_lan.pants_color = Color("2e3b4e")
	chi_lan.accessory = "cap"
	chi_lan.home_position = Vector3(-20, 0.2, -72)
	chi_lan.work_position = Vector3(-102, 0.2, 19) # Food street banh mi
	chi_lan.lunch_position = Vector3(42, 0.2, -28) # Wet market ingredient stall
	chi_lan.leisure_position = Vector3(28, 0.2, 50) # Park
	chi_lan.dialogues = {
		"morning": [
			"Bánh mì nóng giòn rụm vừa nướng xong đây! Pate béo ngậy, dưa chua giòn sần sật!",
			"Hai em làm hai ổ đặc biệt không? Chị chan thêm nước sốt thịt đậm đà nha!"
		],
		"noon": [
			"Giờ trưa chị lượn qua chợ mua thêm dưa leo, ngò rí và ớt sừng tươi rói.",
			"Buôn bán đắt hàng quá, ổ bánh mì giòn tan ai ăn cũng tấm tắc khen đó em!"
		],
		"evening": [
			"Bán hết vèo mấy trăm ổ rồi, chị dọn xe về nghỉ ngơi đây!",
			"Tối thong thả dạo phố một vòng, hít thở gió sông mát rượi thật sảng khoái."
		]
	}
	chi_lan.schedule = [
		{"start_hour": 6.0, "end_hour": 12.0, "activity": "work", "position": chi_lan.work_position, "dialogue_key": "morning", "wait_duration": 22.0},
		{"start_hour": 12.0, "end_hour": 14.0, "activity": "lunch", "position": chi_lan.lunch_position, "dialogue_key": "noon", "wait_duration": 14.0},
		{"start_hour": 14.0, "end_hour": 18.5, "activity": "work", "position": chi_lan.work_position, "dialogue_key": "noon", "wait_duration": 20.0},
		{"start_hour": 18.5, "end_hour": 21.0, "activity": "leisure", "position": chi_lan.leisure_position, "dialogue_key": "evening", "wait_duration": 12.0},
		{"start_hour": 21.0, "end_hour": 24.0, "activity": "home", "position": chi_lan.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 6.0, "activity": "home", "position": chi_lan.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(chi_lan)

	# 5. Anh Tuấn - Barista at Cafe
	var anh_tuan := NPCData.new()
	anh_tuan.id = "anh_tuan"
	anh_tuan.name = "Anh Tuấn"
	anh_tuan.role = "Pha chế cà phê phố"
	anh_tuan.gender = "boy"
	anh_tuan.shirt_color = Color("2a323d") # Cool dark shirt
	anh_tuan.pants_color = Color("8c9199")
	anh_tuan.accessory = "glasses"
	anh_tuan.home_position = Vector3(-109, 0.2, -70)
	anh_tuan.work_position = Vector3(-110, 0.2, 19) # Food street cafe
	anh_tuan.lunch_position = Vector3(-55, 0.2, -23) # Noodle stall
	anh_tuan.leisure_position = Vector3(42, 0.2, 35) # Park promenade
	anh_tuan.dialogues = {
		"morning": [
			"Cà phê phin Robusta Tây Nguyên đậm đà thơm nức mũi! Sáng làm một ly đen đá là tỉnh táo liền!",
			"Bạc xỉu ba tầng béo ngậy cho bạn nữ nè, uống vào ngày mới tràn đầy hứng khởi nhé."
		],
		"noon": [
			"Trưa ngồi dưới tán dù nhâm nhi ly trà đào cam sả thanh mát, trò chuyện rôm rả vui ghê.",
			"Hôm nay trời nắng đẹp, khách ghé uống cà phê đông vui nhộn nhịp cả con phố."
		],
		"evening": [
			"Chiều tối phố lên đèn, mùi cà phê rang xay thơm ngào ngạt khắp góc đường.",
			"Tối nay ghé quán nghe chút nhạc acoustic không hai bạn? Luôn chào đón nha!"
		]
	}
	anh_tuan.schedule = [
		{"start_hour": 6.5, "end_hour": 11.5, "activity": "work", "position": anh_tuan.work_position, "dialogue_key": "morning", "wait_duration": 20.0},
		{"start_hour": 11.5, "end_hour": 13.5, "activity": "lunch", "position": anh_tuan.lunch_position, "dialogue_key": "noon", "wait_duration": 15.0},
		{"start_hour": 13.5, "end_hour": 19.0, "activity": "work", "position": anh_tuan.work_position, "dialogue_key": "noon", "wait_duration": 22.0},
		{"start_hour": 19.0, "end_hour": 21.5, "activity": "leisure", "position": anh_tuan.leisure_position, "dialogue_key": "evening", "wait_duration": 14.0},
		{"start_hour": 21.5, "end_hour": 24.0, "activity": "home", "position": anh_tuan.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 6.5, "activity": "home", "position": anh_tuan.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(anh_tuan)

	# 6. Chị Hoa - Fruit & Veggie Vendor at Wet Market
	var chi_hoa := NPCData.new()
	chi_hoa.id = "chi_hoa"
	chi_hoa.name = "Chị Hoa"
	chi_hoa.role = "Tiểu thương chợ truyền thống"
	chi_hoa.gender = "girl"
	chi_hoa.shirt_color = Color("76a877") # Sage green
	chi_hoa.pants_color = Color("383838")
	chi_hoa.accessory = "conical_hat"
	chi_hoa.home_position = Vector3(39, 0.2, -72)
	chi_hoa.work_position = Vector3(31, 0.2, -32) # Wet market fruit stall
	chi_hoa.lunch_position = Vector3(-94, 0.2, 19) # Food street juice
	chi_hoa.leisure_position = Vector3(42, 0.2, 65) # Park pond
	chi_hoa.dialogues = {
		"morning": [
			"Trái cây miệt vườn tươi rói ngọt lịm đây em ơi! Xoài cát Hòa Lộc, chôm chôm, măng cụt ngon số một!",
			"Mua mớ rau muống hay rổ cà chua ủng hộ chị đi hai đứa, chị tặng thêm mớ hành lá ngò gai nè!"
		],
		"noon": [
			"Trưa chợ vãn khách, chị tạt qua xe nước mía làm ly nước mía sầu riêng thơm lừng đã khát ghê.",
			"Đi chợ giờ trưa thoải mái lựa đồ ngon, cần món gì chị để dành cho nghen!"
		],
		"evening": [
			"Rau củ trái cây bán hết veo rồi, chị dọn sạp quét dọn sạch sẽ rồi về ăn cơm gia đình đây.",
			"Tối mát mẻ hai đứa dẫn nhau đi dạo công viên ngắm trăng nghen, vui lắm đó!"
		]
	}
	chi_hoa.schedule = [
		{"start_hour": 5.5, "end_hour": 11.5, "activity": "work", "position": chi_hoa.work_position, "dialogue_key": "morning", "wait_duration": 22.0},
		{"start_hour": 11.5, "end_hour": 13.5, "activity": "lunch", "position": chi_hoa.lunch_position, "dialogue_key": "noon", "wait_duration": 15.0},
		{"start_hour": 13.5, "end_hour": 17.5, "activity": "work", "position": chi_hoa.work_position, "dialogue_key": "noon", "wait_duration": 18.0},
		{"start_hour": 17.5, "end_hour": 20.0, "activity": "leisure", "position": chi_hoa.leisure_position, "dialogue_key": "evening", "wait_duration": 14.0},
		{"start_hour": 20.0, "end_hour": 24.0, "activity": "home", "position": chi_hoa.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 5.5, "activity": "home", "position": chi_hoa.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(chi_hoa)

	# 7. Anh Dũng - Furniture Store Manager
	var anh_dung := NPCData.new()
	anh_dung.id = "anh_dung"
	anh_dung.name = "Anh Dũng"
	anh_dung.role = "Chủ tiệm nội thất & điện máy"
	anh_dung.gender = "boy"
	anh_dung.shirt_color = Color("4b779a") # Denim shirt
	anh_dung.pants_color = Color("c4a682") # Khaki pants
	anh_dung.accessory = "none"
	anh_dung.home_position = Vector3(20, 0.2, -72)
	anh_dung.work_position = Vector3(105, 0.2, -18) # Furniture store entrance
	anh_dung.lunch_position = Vector3(-50, 0.2, -22) # Noodle stall
	anh_dung.leisure_position = Vector3(105, 0.2, 50) # Expansion lot / boulevard
	anh_dung.dialogues = {
		"morning": [
			"Chào bạn trẻ! Tiệm anh mới về bộ sofa da cao cấp với mẫu tủ lạnh Inverter tiết kiệm điện lắm nha!",
			"Nhà mới cần sắm giường nệm êm ái hay bàn trà gỗ sồi cứ ghé tiệm anh, bảo hành chu đáo tận tâm!"
		],
		"noon": [
			"Trưa ra ăn tô hủ tiếu hít hà cay nồng lấy sức chiều tư vấn nội thất cho bà con.",
			"Khu phố mình sắp mở rộng thêm nhiều nhà mới, anh đang nhập thêm mẫu mã đa dạng đón đầu đây."
		],
		"evening": [
			"Dạo này nhà hai bạn trang trí ấm cúng ghê! Có cần kệ tivi hay đèn ngủ xinh xắn thì nhắn anh nhé.",
			"Buổi tối phố xá bình yên thật, kết thúc một ngày làm việc hiệu quả!"
		]
	}
	anh_dung.schedule = [
		{"start_hour": 7.0, "end_hour": 12.0, "activity": "work", "position": anh_dung.work_position, "dialogue_key": "morning", "wait_duration": 18.0},
		{"start_hour": 12.0, "end_hour": 14.0, "activity": "lunch", "position": anh_dung.lunch_position, "dialogue_key": "noon", "wait_duration": 15.0},
		{"start_hour": 14.0, "end_hour": 18.5, "activity": "work", "position": anh_dung.work_position, "dialogue_key": "noon", "wait_duration": 20.0},
		{"start_hour": 18.5, "end_hour": 21.0, "activity": "leisure", "position": anh_dung.leisure_position, "dialogue_key": "evening", "wait_duration": 15.0},
		{"start_hour": 21.0, "end_hour": 24.0, "activity": "home", "position": anh_dung.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 7.0, "activity": "home", "position": anh_dung.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(anh_dung)

	# 8. Cô Mai - Primary School Teacher
	var co_mai := NPCData.new()
	co_mai.id = "co_mai"
	co_mai.name = "Cô Mai"
	co_mai.role = "Giáo viên trường tiểu học"
	co_mai.gender = "girl"
	co_mai.shirt_color = Color("e8d073") # Pastel gold áo dài tone
	co_mai.pants_color = Color("f5f5ee")
	co_mai.accessory = "glasses"
	co_mai.home_position = Vector3(-109, 0.2, 82)
	co_mai.work_position = Vector3(105, 0.2, -75) # School front courtyard
	co_mai.lunch_position = Vector3(96, 0.2, -76) # School bench
	co_mai.leisure_position = Vector3(42, 0.2, 45) # Park promenade
	co_mai.dialogues = {
		"morning": [
			"Chào hai bạn! Tiếng trống trường điểm báo hiệu giờ vào lớp rộn rã khắp xóm rồi.",
			"Các em học sinh trong khu phố ngoan ngoãn lễ phép lắm, gặp người lớn là khoanh tay chào ngay."
		],
		"noon": [
			"Giờ ra chơi các em ùa ra sân đá cầu, nhảy dây rộn ràng cả một góc trời tuổi thơ.",
			"Trưa ngồi dưới bóng cây phượng vĩ sân trường đọc sách thật yên bình."
		],
		"evening": [
			"Tan trường rồi, cô đi dạo ngắm hoa viên và ghé chợ mua chút đồ chuẩn bị giáo án cho ngày mai.",
			"Chúc hai bạn có một buổi tối thật ngọt ngào và ấm áp bên nhau nhé!"
		]
	}
	co_mai.schedule = [
		{"start_hour": 6.5, "end_hour": 11.5, "activity": "work", "position": co_mai.work_position, "dialogue_key": "morning", "wait_duration": 20.0},
		{"start_hour": 11.5, "end_hour": 13.5, "activity": "lunch", "position": co_mai.lunch_position, "dialogue_key": "noon", "wait_duration": 18.0},
		{"start_hour": 13.5, "end_hour": 17.0, "activity": "work", "position": co_mai.work_position, "dialogue_key": "noon", "wait_duration": 20.0},
		{"start_hour": 17.0, "end_hour": 20.0, "activity": "leisure", "position": co_mai.leisure_position, "dialogue_key": "evening", "wait_duration": 14.0},
		{"start_hour": 20.0, "end_hour": 24.0, "activity": "home", "position": co_mai.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 6.5, "activity": "home", "position": co_mai.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(co_mai)

	# 9. Bé An - Energetic School Kid
	var be_an := NPCData.new()
	be_an.id = "be_an"
	be_an.name = "Bé An"
	be_an.role = "Học sinh tiểu học"
	be_an.gender = "boy"
	be_an.shirt_color = Color("f0ece1") # White school uniform
	be_an.pants_color = Color("1e3352") # Navy shorts
	be_an.accessory = "backpack"
	be_an.home_position = Vector3(-29, 0.2, 36)
	be_an.work_position = Vector3(105, 0.2, -71) # School
	be_an.lunch_position = Vector3(-102, 0.2, 24) # Food street table
	be_an.leisure_position = Vector3(28, 0.2, 63) # Playground & slide
	be_an.dialogues = {
		"morning": [
			"Em chào anh chị ạ! Hôm nay em được điểm 10 môn tập làm văn đó nha!",
			"Em đang chạy nhanh tới trường kẻo bác bảo vệ đóng cổng nè hihi!"
		],
		"noon": [
			"Trưa em được mẹ cho tiền mua bánh mì que và ly kem mát rượi, ngon tuyệt cú mèo!",
			"Anh chị có muốn chơi trốn tìm với tụi em ở công viên không nè?"
		],
		"evening": [
			"Cầu trượt ở công viên trượt nhanh như bay luôn, em chơi hoài không biết chán!",
			"Tối rồi em phải về nhà ăn cơm với mẹ rồi làm bài tập về nhà đây ạ. Em chào anh chị!"
		]
	}
	be_an.schedule = [
		{"start_hour": 7.0, "end_hour": 11.5, "activity": "work", "position": be_an.work_position, "dialogue_key": "morning", "wait_duration": 18.0},
		{"start_hour": 11.5, "end_hour": 13.5, "activity": "lunch", "position": be_an.lunch_position, "dialogue_key": "noon", "wait_duration": 14.0},
		{"start_hour": 13.5, "end_hour": 16.5, "activity": "work", "position": be_an.work_position, "dialogue_key": "noon", "wait_duration": 16.0},
		{"start_hour": 16.5, "end_hour": 19.5, "activity": "leisure", "position": be_an.leisure_position, "dialogue_key": "evening", "wait_duration": 15.0},
		{"start_hour": 19.5, "end_hour": 24.0, "activity": "home", "position": be_an.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 7.0, "activity": "home", "position": be_an.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(be_an)

	# 10. Chú Tư - Neighborhood Neighborhood Representative
	var chu_tu := NPCData.new()
	chu_tu.id = "chu_tu"
	chu_tu.name = "Chú Tư"
	chu_tu.role = "Tổ trưởng dân phố"
	chu_tu.gender = "boy"
	chu_tu.shirt_color = Color("6d8271") # Khaki green officer shirt
	chu_tu.pants_color = Color("383838")
	chu_tu.accessory = "none"
	chu_tu.home_position = Vector3(-109, 0.2, -40)
	chu_tu.work_position = Vector3(6, 0.2, 0) # Central boulevard inspection
	chu_tu.lunch_position = Vector3(38, 0.2, -26) # Wet market visit
	chu_tu.leisure_position = Vector3(27, 0.2, 40) # Park gazebo
	chu_tu.dialogues = {
		"morning": [
			"Chào bà con! Sáng nay chú đi kiểm tra an ninh trật tự và vệ sinh môi trường xóm mình.",
			"Đường sá sạch đẹp, hoa nở rực rỡ, tổ dân phố mình đạt chuẩn khu dân cư kiểu mẫu đó nghen!"
		],
		"noon": [
			"Trưa ghé qua chợ nhắc nhở tiểu thương giữ gìn vệ sinh quầy sạp an toàn thực phẩm.",
			"Hai cháu sống ở đây thấy thoải mái không? Có khó khăn gì cứ báo chú hỗ trợ liền nha!"
		],
		"evening": [
			"Chiều mát ngồi vọng lâu công viên họp bàn việc tổ chức hội trăng rằm cho các cháu thiếu nhi.",
			"Bà con trong xóm đoàn kết gắn bó, tối lửa tắt đèn có nhau thật đáng quý!"
		]
	}
	chu_tu.schedule = [
		{"start_hour": 6.5, "end_hour": 11.0, "activity": "work", "position": chu_tu.work_position, "dialogue_key": "morning", "wait_duration": 16.0},
		{"start_hour": 11.0, "end_hour": 14.0, "activity": "lunch", "position": chu_tu.lunch_position, "dialogue_key": "noon", "wait_duration": 16.0},
		{"start_hour": 14.0, "end_hour": 18.0, "activity": "work", "position": chu_tu.work_position, "dialogue_key": "noon", "wait_duration": 18.0},
		{"start_hour": 18.0, "end_hour": 21.0, "activity": "leisure", "position": chu_tu.leisure_position, "dialogue_key": "evening", "wait_duration": 14.0},
		{"start_hour": 21.0, "end_hour": 24.0, "activity": "home", "position": chu_tu.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 6.5, "activity": "home", "position": chu_tu.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(chu_tu)

	# 11. Bác Tám - Grocery Store Owner
	var bac_tam := NPCData.new()
	bac_tam.id = "bac_tam"
	bac_tam.name = "Bác Tám"
	bac_tam.role = "Chủ tiệm tạp hóa Bách Hóa Xanh"
	bac_tam.gender = "boy"
	bac_tam.shirt_color = Color("c76e4c") # Terracotta apron shirt
	bac_tam.pants_color = Color("3d434d")
	bac_tam.accessory = "glasses"
	bac_tam.home_position = Vector3(-105, 0.2, 35) # Grocery back room
	bac_tam.work_position = Vector3(-107, 0.2, 34) # Inside grocery store
	bac_tam.lunch_position = Vector3(-50, 0.2, -22) # Noodle shop
	bac_tam.leisure_position = Vector3(-105, 0.2, 28) # Grocery front porch
	bac_tam.dialogues = {
		"morning": [
			"Tiệm tạp hóa bác Tám cái gì cũng có! Gạo thơm ST25, mắm nhĩ Phú Quốc, gia vị bánh kẹo đủ cả!",
			"Hai đứa mở tủ lạnh lấy nước ngọt hay kem que cứ tự nhiên, bác tính giá hữu nghị cho xóm nhà lá nè!"
		],
		"noon": [
			"Trưa giao mấy thùng nước khoáng cho bà con xong ghé làm bát hủ tiếu nóng là ấm lòng.",
			"Cần mua bột giặt, dầu ăn hay gói mì gói khuya đói bụng thì cứ ới bác bất cứ lúc nào nghen!"
		],
		"evening": [
			"Tối bác ngồi trước hiên quạt mo cau hóng gió, nhìn xóm mình sáng đèn ấm cúng ghê.",
			"Cảm ơn hai đứa đã ủng hộ tiệm bác nhé, chúc hai đứa nhiều sức khỏe và hạnh phúc!"
		]
	}
	bac_tam.schedule = [
		{"start_hour": 6.0, "end_hour": 12.0, "activity": "work", "position": bac_tam.work_position, "dialogue_key": "morning", "wait_duration": 22.0},
		{"start_hour": 12.0, "end_hour": 14.0, "activity": "lunch", "position": bac_tam.lunch_position, "dialogue_key": "noon", "wait_duration": 15.0},
		{"start_hour": 14.0, "end_hour": 19.0, "activity": "work", "position": bac_tam.work_position, "dialogue_key": "noon", "wait_duration": 20.0},
		{"start_hour": 19.0, "end_hour": 22.0, "activity": "leisure", "position": bac_tam.leisure_position, "dialogue_key": "evening", "wait_duration": 16.0},
		{"start_hour": 22.0, "end_hour": 24.0, "activity": "home", "position": bac_tam.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 6.0, "activity": "home", "position": bac_tam.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(bac_tam)

	# 12. Em Linh - Active University Student / Resident
	var em_linh := NPCData.new()
	em_linh.id = "em_linh"
	em_linh.name = "Em Linh"
	em_linh.role = "Sinh viên & cư dân xóm"
	em_linh.gender = "girl"
	em_linh.shirt_color = Color("e06d64") # Coral sportswear
	em_linh.pants_color = Color("232b38") # Dark running shorts
	em_linh.accessory = "headband"
	em_linh.home_position = Vector3(-58, 0.2, -100)
	em_linh.work_position = Vector3(42, 0.2, 53) # Park jogging path
	em_linh.lunch_position = Vector3(-94, 0.2, 22) # Sugarcane juice stand
	em_linh.leisure_position = Vector3(42, 0.2, 70) # Park pond
	em_linh.dialogues = {
		"morning": [
			"Em chào anh chị! Buổi sáng chạy bộ quanh đại lộ và công viên ngắm bình minh tuyệt vời lắm!",
			"Không khí xóm mình trong lành ghê, tập thể dục xong thấy tràn đầy năng lượng học tập!"
		],
		"noon": [
			"Chạy bộ xong ghé uống ly nước mía cốt tắc chua ngọt mát lạnh, sảng khoái không gì bằng!",
			"Anh chị có tập chạy bộ buổi sáng không? Hôm nào chạy chung cho vui nha!"
		],
		"evening": [
			"Chiều tà ra cầu đá ngắm đàn cá bơi lội dưới hồ, bao nhiêu căng thẳng tan biến hết luôn.",
			"Tối nay xóm mình mát mẻ quá, chúc anh chị có một buổi tối thật chill nhé!"
		]
	}
	em_linh.schedule = [
		{"start_hour": 5.5, "end_hour": 10.5, "activity": "leisure", "position": em_linh.work_position, "dialogue_key": "morning", "wait_duration": 16.0},
		{"start_hour": 10.5, "end_hour": 14.0, "activity": "lunch", "position": em_linh.lunch_position, "dialogue_key": "noon", "wait_duration": 15.0},
		{"start_hour": 14.0, "end_hour": 17.5, "activity": "home", "position": em_linh.home_position, "dialogue_key": "noon", "wait_duration": 20.0},
		{"start_hour": 17.5, "end_hour": 21.0, "activity": "leisure", "position": em_linh.leisure_position, "dialogue_key": "evening", "wait_duration": 18.0},
		{"start_hour": 21.0, "end_hour": 24.0, "activity": "home", "position": em_linh.home_position, "dialogue_key": "evening", "wait_duration": 30.0},
		{"start_hour": 0.0, "end_hour": 5.5, "activity": "home", "position": em_linh.home_position, "dialogue_key": "evening", "wait_duration": 30.0}
	]
	list.append(em_linh)

	return list

func get_schedule_for_hour(hour: float) -> Dictionary:
	var h := fposmod(hour, 24.0)
	for entry in schedule:
		var s: float = entry["start_hour"]
		var e: float = entry["end_hour"]
		if s <= e:
			if h >= s and h < e: return entry
		else:
			# Wraps midnight
			if h >= s or h < e: return entry
	if schedule.size() > 0:
		return schedule[0]
	return {
		"activity": "idle",
		"position": home_position,
		"dialogue_key": "morning",
		"wait_duration": 10.0
	}
