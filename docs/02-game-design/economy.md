# Economy Balance — VERY MVP

> **Note:** These values are experimental starter balancing for Couple Chaos 3D VERY MVP, not copied from Hay Day.

| Parameter | Value | Data Location | Notes |
| --- | --- | --- | --- |
| Starting Coins | `100 xu` (suggested) | `data/upgrades/` or starter config | Enough to plant initial carrots and experience the loop immediately |
| Carrot Seed Cost | `5 xu` | `data/crops/` | Deducted when planting on an `EMPTY` plot |
| Harvest Yield | `2 carrots` | `data/crops/` | Added to `Inventory` when harvesting a `READY` plot |
| Order Requirement | `4 carrots` | `data/orders/` | 2 harvests satisfy 1 order |
| Order Reward | `+60 xu` | `data/orders/` | Net profit per order cycle: `60 - (2 * 5) = +50 xu` |
| Unlock New Plot | `120 xu` | `data/upgrades/` | Achievable after ~2-3 completed orders |

All balance values must be loaded from `data/crops/`, `data/orders/`, and `data/upgrades/` rather than hard-coded in scripts.
