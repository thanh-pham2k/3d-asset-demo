class_name Wallet
extends RefCounted
## Tracks player coin (xu) balance with validation and change signals.

signal coins_changed(new_balance: int)

var balance: int = 0

func _init(initial_balance: int = 100) -> void:
	balance = maxi(0, initial_balance)

func can_afford(amount: int) -> bool:
	return amount >= 0 and balance >= amount

func spend(amount: int) -> bool:
	if amount < 0 or balance < amount:
		return false
	balance -= amount
	coins_changed.emit(balance)
	return true

func earn(amount: int) -> void:
	if amount <= 0:
		return
	balance += amount
	coins_changed.emit(balance)

func set_balance(new_balance: int) -> void:
	balance = maxi(0, new_balance)
	coins_changed.emit(balance)
