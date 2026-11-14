# Economy Balance — VERY MVP

> **Note:** These values are experimental starter balancing for Couple Chaos 3D VERY MVP, not copied from Hay Day.

| Parameter | Value | Notes |
| --- | --- | --- |
| Starting Coins | `100 xu` (suggested) | Enough to plant initial carrots and experience the loop immediately |
| Carrot Seed Cost | `5 xu` | Deducted when planting on an `EMPTY` plot |
| Harvest Yield | `2 carrots` | Added to `Inventory` when harvesting a `READY` plot |
| Order Requirement | `4 carrots` | 2 harvests satisfy 1 order |
| Order Reward | `+60 xu` | Net profit per order cycle: `60 - (2 * 5) = +50 xu` |
| Unlock New Plot | `120 xu` | Achievable after ~2-3 completed orders |

All balance values should live in `data/balance/` or `data/crops/` / `data/orders/` / `data/upgrades/` so they can be tuned without modifying scripts.
