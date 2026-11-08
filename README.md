# Couple Chaos 3D prototype

Prototype một người chơi, Godot 4.7.2, renderer Compatibility. Mở `project.godot` trong Godot và nhấn F5. Hoặc chạy `/Applications/Godot.app/Contents/MacOS/Godot --path .` trên máy hiện tại.

| Hành động | Phím |
|---|---|
| Di chuyển | WASD |
| Chạy | Shift trái |
| Tương tác / nhặt gối | E |
| Ném gối | F |
| Lướt theo hướng di chuyển hoặc hướng đang nhìn | Space |

Game mở trong cửa sổ; nhấn F11 để bật/tắt toàn màn hình và Esc để về cửa sổ. Camera theo nhân vật khi đi đến hai đầu phòng.

Đến gần vật dụng để xem gợi ý. Sofa và giường dùng cùng phím để ngồi/nằm và đứng dậy; đèn và cửa bật/tắt. Nhặt gối, quay về hướng muốn ném; sau khi gối rơi có thể nhặt lại. Restart đặt lại scene.

## Thay model

`scenes/player.tscn` dùng `PlayerConfig` (`scripts/player_config.gd`) để chọn `visual_scene`, `visual_scale`, `visual_offset`, `hold_offset`, tốc độ và gia tốc. Gán một PackedScene khác vào `visual_scene` trước khi player vào scene tree (hoặc cấu hình resource trên instance). Scene có root Node3D và pivot tại chân; GLB có thể được bọc trong một scene Node3D để điều chỉnh pivot. Visual nằm dưới `VisualRoot`; collision và HoldPoint thuộc player, không phụ thuộc mesh. Điều chỉnh scale/offset/hold offset cho từng model; nếu cần gắn tay theo xương, cung cấp adapter/attachment cho model đó.

`scripts/animation_controller.gd` nhận trạng thái gameplay chung. Scene visual có thể triển khai `update_pose(move, running, holding, throwing, resting, lying, reacting, time)` để chuyển các trạng thái sang AnimationPlayer/AnimationTree và ánh xạ tên animation của GLB. Placeholder được animate qua adapter riêng. Một visual không có adapter vẫn hiển thị và gameplay vẫn chạy, nhưng sẽ không có animation. Test `tests/swap_visual.tscn` minh họa interface; chưa thử với GLB thực tế.

## Kiểm tra

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke.gd
```

Smoke test mô phỏng InputMap cho di chuyển, ném và bật đèn; các tương tác khác được gọi trực tiếp. Nó kiểm tra va tường, nhặt gối, ném, gối rơi và nhặt lại, sofa/giường/cửa, và một visual thay thế. Đây không phải kiểm thử bàn phím thật.

## Giới hạn prototype

Phòng và nhân vật được dựng bằng primitive, bố cục là bản giản lược so với ảnh. Cửa chỉ xoay phần hiển thị, biên phòng vẫn đóng. Chưa có audio, gamepad, animation GLB thực tế hoặc bone attachment; có thể cần chỉnh camera/bố cục và collision khi phát triển tiếp. Các asset cũ trong `assets/furniture` không được scene sử dụng. Chưa kiểm tra thủ công các tổ hợp phím vật lý hoặc trải nghiệm chơi thực tế.
