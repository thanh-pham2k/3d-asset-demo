# Game Benchmarks — Nghiên Cứu 25 Game Tham Khảo

## Định hướng nghiên cứu
- **4 tiêu chí ưu tiên:** click/tap đơn giản, mỗi phiên 5–10 phút, có tiến trình offline, có lý do quay lại hằng ngày.
- **Nguyên tắc bản quyền:** Chỉ học và kết hợp cơ chế gameplay phổ biến bằng code, asset, và UI tự thiết kế; không sao chép bản đồ, hình ảnh, nhân vật, âm thanh hay nội dung đặc trưng của game khác.
- **Lưu ý nguồn:** Danh sách được đối chiếu từ trang cửa hàng và mô tả game, chưa phải kết quả tự chơi kiểm chứng từng game.

---

## 1. Danh sách 25 game tham khảo (5 nhóm)

### Nhóm A — Farming & Production (Ưu tiên cao nhất)
| # | Game | Cơ chế đáng học | Áp dụng vào Couple Chaos 3D |
| --- | --- | --- | --- |
| 1 | **Hay Day** | Trồng → sản xuất → giao đơn | Rau cung cấp cho đơn hàng & quán ăn |
| 2 | **Township** | Nông trại + phát triển thị trấn | Nâng cấp khu phố |
| 3 | **FarmVille 3** | Nông nghiệp + vật nuôi | Mở khóa chuồng nuôi |
| 4 | **Family Farm Seaside** | Chuỗi sản xuất nhiều công đoạn | Rau → món ăn → bán |
| 5 | **Klondike Adventures** | Khám phá + nhiệm vụ | Mở khu phố mới |

### Nhóm B — Idle & Automation
| # | Game | Cơ chế đáng học | Áp dụng vào Couple Chaos 3D |
| --- | --- | --- | --- |
| 6 | **Cats & Soup** | Nhân vật tự sản xuất, nâng cấp | NPC quán hủ tiếu |
| 7 | **Animal Restaurant** | Khách, món ăn, nhân viên | Quản lý quán ăn |
| 8 | **Cat Snack Bar** | Tăng công suất và tự động hóa | Nâng cấp garage |
| 9 | **Resortopia** | Mở phòng, nâng cấp, khách ghé | Mở rộng nhà, khu phố |
| 10 | **Idle Farming Empire** | Tích lũy thu nhập, tái đầu tư | Thu nhập offline |

### Nhóm C — Home, Pets & Collection
| # | Game | Cơ chế đáng học | Áp dụng vào Couple Chaos 3D |
| --- | --- | --- | --- |
| 11 | **Pocket Love** | Cặp đôi, nội thất, nhà nhỏ | Boy + Girl + trang trí |
| 12 | **Tsuki's Odyssey** | Sinh hoạt nhẹ nhàng, đồ trang trí | Nhà và NPC tự sinh hoạt |
| 13 | **Adorable Home** | Nhà cửa, thú cưng, hoạt động hằng ngày | Miu Miu và gia đình |
| 14 | **My Dear Farm** | Trồng cây + tùy biến nông trại | Vườn rau thẩm mỹ |
| 15 | **Usagi Shima** | Thu hút động vật, sưu tập | Mở khóa thú cưng |

### Nhóm D — Restaurant & Shop Management
| # | Game | Cơ chế đáng học | Áp dụng vào Couple Chaos 3D |
| --- | --- | --- | --- |
| 16 | **Good Pizza, Great Pizza** | Đơn hàng, nâng cấp, khách đặc biệt | Đơn hủ tiếu |
| 17 | **Good Coffee, Great Coffee** | Công thức, phục vụ, mở rộng menu | Món ăn mới |
| 18 | **Hungry Hearts Diner** | Món ăn gắn với câu chuyện NPC | Câu chuyện Cô Bảy |
| 19 | **Boba Story** | Sáng tạo công thức, trang trí | Công thức đặc biệt |
| 20 | **Cat Mart: Mini Market Tycoon** | Quản lý quầy hàng, nhân viên | Chợ và cửa hàng |

### Nhóm E — Indie, Scope nhỏ & Click-to-Play (itch.io)
*Phù hợp để học cách giảm độ phức tạp triển khai:*

| # | Game | Cơ chế đáng học | Áp dụng vào Couple Chaos 3D |
| --- | --- | --- | --- |
| 21 | **Farm Town** | Farming 3D, đơn hàng | Click vào luống |
| 22 | **Tiller Town** | Trồng, chế biến, bảng đơn | Chuỗi nông sản |
| 23 | **Clay Valley Farm Tycoon** | Tap, thuê nhân viên, nâng cấp | Idle garage |
| 24 | **Idle Goat Farmer** | Sản xuất offline, công thức | Vật nuôi và chế biến |
| 25 | **Farm Town Simulator** | Phát triển làng, thuê NPC | Khu phố sống động |

---

## 2. Chắt lọc 7 cơ chế cốt lõi (lộ trình dài hạn)

| Cơ chế | Học từ game | Ưu tiên |
| --- | --- | --- |
| Trồng → thu hoạch → giao đơn | Hay Day | **P0** (VERY MVP) |
| NPC tự sản xuất, thu tiền | Cats & Soup | **P0** (Post-VERY MVP) |
| Nhà và nội thất | Pocket Love | **P0** (Post-VERY MVP) |
| Tiến trình offline | Idle Farming Empire | **P0** (VERY MVP) |
| Mở khóa công trình | Township | **P1** |
| Khách đặc biệt, đơn hàng | Good Pizza, Great Pizza | **P1** |
| Sưu tập thú cưng, NPC | Tsuki's Odyssey, Usagi Shima | **P2** |

---

## 3. Vòng lặp kết hợp mục tiêu (Full Indie Loop — Post-VERY MVP)

```text
MỞ GAME
   │
   ▼
Nhận tiền offline + Quà hằng ngày
   │
   ▼
Thu hoạch nông sản
   ├──► Giao đơn tại chợ
   └──► Cấp nguyên liệu cho quán ăn
   │
   ▼
Kiếm tiền (Quán ăn + Garage)
   ├──► Nâng cấp kinh doanh
   └──► Trang trí nhà, nuôi mèo Miu Miu
   │
   ▼
Mở khóa nội dung & đơn hàng mới ──► Quay lại sau vài giờ
```

### Quy tắc tránh nặng nề khi mở rộng
- Tránh quá nhiều loại tiền, nhiều màn hình quản lý, thời gian chờ kéo dài hoặc bắt click hàng trăm lần.
- **Mục tiêu bản đầu tiên hoàn chỉnh (sau VERY MVP):**
  - 6–12 luống rau, 5–8 loại cây.
  - 2 cơ sở kinh doanh tự động: garage và quán hủ tiếu.
  - 1 bảng đơn hàng NPC.
  - 1 ngôi nhà có thể trang trí.
  - 1 thú cưng Miu Miu.
  - 15–20 nâng cấp có tác dụng rõ ràng.
  - Tiến trình offline và nhiệm vụ hằng ngày.

---

## 4. Đánh giá mức độ phù hợp (thang 10) & Bước tiếp theo
- **Hay Day:** 10/10
- **Cats & Soup:** 10/10
- **Pocket Love:** 9/10
- **Township:** 8/10
- **Animal Restaurant:** 8/10
- **Tsuki's Odyssey:** 8/10
- **Good Pizza, Great Pizza:** 7/10

**Công thức định hướng thiết kế dài hạn:** ~40% Hay Day + ~25% Cats & Soup + ~20% Pocket Love + ~15% Township (tính theo mức độ ảnh hưởng lên thiết kế).

**Bước nghiên cứu tiếp theo (khi xong VERY MVP):** Phân tích sâu 5–7 game đứng đầu về trải nghiệm 10 phút đầu, vòng lặp ngày đầu, mốc mở khóa, cơ chế offline, phần thưởng và liên kết hệ thống.
