# Couple Chaos 3D prototype

Prototype một người chơi, Godot 4.7.2, renderer Compatibility. Mở `project.godot` trong Godot và nhấn F5. Hoặc chạy `/Applications/Godot.app/Contents/MacOS/Godot --path .` trên máy hiện tại.

| Hành động | Phím |
|---|---|
| Di chuyển | WASD |
| Chạy | Shift trái |
| Tương tác / nhặt / thả | E |
| Ném vật đang cầm | F |
| Đập khi cầm búa đồ chơi | Q |
| Lướt theo hướng di chuyển hoặc hướng đang nhìn | Space |

Game mở trong cửa sổ; nhấn F11 để bật/tắt toàn màn hình và Esc để tạm dừng hoặc tiếp tục. Camera theo nhân vật khi đi đến hai đầu phòng. Chọn Boy hoặc Girl, rồi chọn Bắt đầu ở menu để chơi; vẫn chỉ có một người chơi.

Đến gần vật dụng để xem gợi ý. Sofa và giường dùng cùng phím để ngồi/nằm và đứng dậy; đèn và cửa bật/tắt. Nhặt gối, búa đồ chơi, gấu, hộp, sách hoặc bóng bằng E và ném bằng F; sau khi vật rơi có thể nhặt lại. Restart đặt lại scene.

## Khu phố

Chọn **KHÁM PHÁ KHU PHỐ** tại menu chính để khám phá bản đồ. Tab đổi giữa camera theo nhân vật và toàn cảnh; Esc trở về menu. Xem [hướng dẫn khu phố](docs/neighborhood.md) để biết bố cục, giới hạn và lệnh kiểm tra.

## Thay model

`scenes/player.tscn` dùng `PlayerConfig` (`scripts/player_config.gd`) để chọn `visual_scene`, `visual_scale`, `visual_offset`, `hold_offset`, tốc độ và gia tốc. Gán một PackedScene khác vào `visual_scene` trước khi player vào scene tree (hoặc cấu hình resource trên instance). Scene có root Node3D và pivot tại chân; GLB có thể được bọc trong một scene Node3D để điều chỉnh pivot. Visual nằm dưới `VisualRoot`; collision và HoldPoint thuộc player, không phụ thuộc mesh. Điều chỉnh scale/offset/hold offset cho từng model; nếu cần gắn tay theo xương, cung cấp adapter/attachment cho model đó.

Nhân vật procedural dùng Skeleton3D và marker tay. Có thể thử model GLB Kenney bằng `COUPLE_VISUAL=kenney /Applications/Godot.app/Contents/MacOS/Godot --path .`; model này cần tiếp tục kiểm tra phong cách và animation. `scripts/animation_controller.gd` nhận trạng thái gameplay chung. Scene visual có thể triển khai `update_pose(move, running, holding, throwing, resting, lying, reacting, time)` để chuyển các trạng thái sang AnimationPlayer/AnimationTree và ánh xạ tên animation của GLB. Placeholder được animate qua adapter riêng. Một visual không có adapter vẫn hiển thị và gameplay vẫn chạy, nhưng sẽ không có animation. Test `tests/swap_visual.tscn` minh họa interface; chưa thử với GLB thực tế.

## Kiểm tra

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke.gd
```

Smoke test mô phỏng InputMap cho di chuyển, ném và bật đèn; các tương tác khác được gọi trực tiếp. Nó kiểm tra va tường, nhặt gối, ném, gối rơi và nhặt lại, sofa/giường/cửa, và một visual thay thế. Đây không phải kiểm thử bàn phím thật.

## Giới hạn prototype

Phòng và nhân vật được dựng bằng primitive, bố cục là bản giản lược so với ảnh. Cửa chỉ xoay phần hiển thị, biên phòng vẫn đóng. Âm thanh và VFX tổng hợp còn cần kiểm tra thực tế; chưa có gamepad; có thể cần chỉnh camera/bố cục và collision khi phát triển tiếp. Laptop, ghế, cây, sách và gấu dùng model Kenney Furniture Pack CC0 trong `assets/furniture/License.txt`; các vật còn lại vẫn là placeholder. Chưa kiểm tra thủ công các tổ hợp phím vật lý hoặc trải nghiệm chơi thực tế.

## Kiểm kê asset

Xem [docs/asset-inventory.md](docs/asset-inventory.md) để biết các placeholder, hạng mục còn thiếu, thứ tự thực hiện và phạm vi kiểm thử.
