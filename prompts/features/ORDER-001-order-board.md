# ORDER-001 — OrderBoard

**Docs:** `docs/02-game-design/core-loop.md`, `docs/02-game-design/economy.md`

## Scope
- Implement `OrderBoard` (`scripts/orders/order_board.gd` + UI) for the VERY MVP order: deliver `4` carrots from `Inventory` -> receive `+60 xu` into `Wallet`.
- Emit `order_completed` and trigger `SaveManager` persistence.
