class_name HouseholdWallet
extends RefCounted

## Shared household wallet for Couple Chaos.
## Manages persistent family funds, prevents negative balances,
## ensures transaction idempotency (no duplicate rewards/deductions),
## and maintains a transparent transaction history.

signal balance_changed(new_balance: int, delta: int)
signal transaction_logged(transaction: Dictionary)

const DEFAULT_STARTING_BALANCE: int = 100000 # 100,000 VND initial family savings

var balance: int = DEFAULT_STARTING_BALANCE
var total_earned: int = 0
var total_spent: int = 0

# Deduplication store: transaction_id -> true
var processed_transaction_ids: Dictionary = {}

# Transaction log: [{ "id": String, "type": "EARN"/"SPEND", "amount": int, "category": String, "desc": String, "balance": int, "time": float }]
var transaction_history: Array[Dictionary] = []
const MAX_HISTORY_ENTRIES: int = 100

func can_afford(amount: int) -> bool:
	if amount < 0: return false
	return balance >= amount

func deposit(amount: int, category: String, description: String, transaction_id := "") -> bool:
	if amount <= 0: return false
	
	if transaction_id != "":
		if processed_transaction_ids.has(transaction_id):
			return false # Duplicate reward blocked
		processed_transaction_ids[transaction_id] = true
	
	balance += amount
	total_earned += amount
	
	var tx := {
		"id": transaction_id if transaction_id != "" else "tx_dep_%d" % Time.get_ticks_msec(),
		"type": "EARN",
		"amount": amount,
		"category": category,
		"description": description,
		"balance": balance,
		"time": Time.get_unix_time_from_system()
	}
	_log_transaction(tx)
	balance_changed.emit(balance, amount)
	return true

func withdraw(amount: int, category: String, description: String, transaction_id := "") -> bool:
	if amount <= 0: return false
	if not can_afford(amount): return false # Prevent negative balance
	
	if transaction_id != "":
		if processed_transaction_ids.has(transaction_id):
			return false # Duplicate deduction blocked
		processed_transaction_ids[transaction_id] = true
	
	balance -= amount
	total_spent += amount
	
	var tx := {
		"id": transaction_id if transaction_id != "" else "tx_wdr_%d" % Time.get_ticks_msec(),
		"type": "SPEND",
		"amount": -amount,
		"category": category,
		"description": description,
		"balance": balance,
		"time": Time.get_unix_time_from_system()
	}
	_log_transaction(tx)
	balance_changed.emit(balance, -amount)
	return true

func _log_transaction(tx: Dictionary) -> void:
	transaction_history.append(tx)
	if transaction_history.size() > MAX_HISTORY_ENTRIES:
		transaction_history.pop_front()
	transaction_logged.emit(tx)

func get_history(limit := 20) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start_idx: int = maxi(0, transaction_history.size() - limit)
	for i in range(transaction_history.size() - 1, start_idx - 1, -1):
		result.append(transaction_history[i])
	return result

static func format_money(val: int) -> String:
	var s := str(absi(val))
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	if val < 0: res = "-" + res
	return res + " đ"
