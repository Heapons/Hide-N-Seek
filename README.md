# Hide'N'Seek
Commissioned by [ArJay<br>![](https://yt3.googleusercontent.com/eNw5kvPjHEngIYS0RuVJgI-UOpRSqGt93QClui3BQ7axJPLIWl_wNXdtiJx3tLjt7qV89EZtlio=s160-c-k-c0x00ffffff-no-rj)](https://www.youtube.com/@ArJayTF2)

This requires no dependencies (and also works on **64-bit** servers‼)

# Game Rules
## General
- The game pits 1 BLU player against the entirety of RED team. And there are two ways to end a round:
    - If BLU dies → RED wins.
    - If the time's out → BLU wins.
- Removes every gamemode logic from the map and imposes its own custom hide'n'seek logic.
    - All doors remain open.
    - Players may not respawn (akin to Arena Mode and Sudden Death).
    - Game objectives are removed.
    - Resupply Lockers are disabled.

## Rounds
There's a Setup Time which is meant to give time for The Hider to, well, *hide* as RED teams patiently waits for the round to begin.

## The Hider (BLU Team)
- Only 1 player is on that team. That's The Hider (internally referenced as Juggernaut).
    - To be able to play as The Hider, you must use your SteamID64 in the `sm_juggernaut` convar.
- Restricted to Spy class.
- Emits a signal every `X` minutes (default: `2`).
- May skip Setup Time with `sm_ready`.
### Perks
- Unlimited cloak.
- Increased max. health.

## The Seekers (RED Team)
- Restricted to Heavy class and melee weapons only.
- Upon death, goes to [Team Unassigned](https://www.youtube.com/watch?v=s7GTiBs3hRw).
    - Vision also goes black so players can't locate The Hider.
# ConVars
|Name|Description|
|-------------------------------|--------------------------------------------------------------------|
| `sm_juggernaut` | SteamID64 of the only player allowed to be Juggernaut. |
| `sm_juggernaut_maxhealth` | Max health for Juggernaut. |
| `sm_juggernaut_signal_interval` | Interval (in minutes) to signal Juggernaut's position (0 = disabled). |
| `sm_juggernaut_setup_time`| Setup time length (in seconds).|
| `sm_juggernaut_round_time`| Round time length (in seconds).|