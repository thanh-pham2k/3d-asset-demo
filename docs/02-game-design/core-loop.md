# Core Loop — VERY MVP (Hay Day Reference)

```text
[HAY DAY CORE LOOP]
       OPEN GAME
           |
           v
  +-----------------+
  | Click Farm Plot |
  +--------+--------+
           |
           v
  +-----------------+
  |  Plant Carrot   |
  |    Pay 5 xu     |
  +--------+--------+
           |
           v
  +-----------------+
  |   Crop Grows    |
  |    Real-time    |
  +--------+--------+
           |
           v
  +-----------------+
  |     Harvest     |
  |   +2 carrots    |
  +--------+--------+
           |
           v
  +-----------------+
  |   Order Board   |
  |    4 carrots    |
  +--------+--------+
           |
           v
  +-----------------+
  |  Deliver Order  |
  |     +60 xu      |
  +--------+--------+
           |
           v
  +-----------------+
  |  Unlock Plot    |
  |    -120 xu      |
  +--------+--------+
           |
           +---------> PLANT MORE
```

## Plot State Machine
Each `FarmPlot` transitions through:
- `EMPTY` -> (click + spend 5 xu) -> `GROWING`
- `GROWING` -> (elapsed real-time >= maturity duration) -> `READY`
- `READY` -> (click to harvest: `+2 carrots`, plot resets) -> `EMPTY`
- `LOCKED` -> (unlock via `FarmUpgrade`: `-120 xu`) -> `EMPTY`
