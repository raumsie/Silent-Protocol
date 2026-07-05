# Silent Protocol

A 2D top-down stealth game built in Godot 4. Sneak past patrolling guards, stay out of their vision cones, and complete your objective before the whole facility is alerted to your presence.

## Description

Silent Protocol is a stealth-action prototype centered on guard AI that actually behaves like a coordinated team. Enemies patrol fixed routes, spot the player through raycast-based vision cones, and — crucially — talk to each other: when one guard sees you, the alert propagates to every other guard in the level after a short radio delay, and they'll converge on your last known position using pathfinding that routes around walls. Losing line of sight buys you a search phase, not an instant reset.

## Screenshots

<!-- TODO: add screenshot -->

## Features

- **Vision-cone detection** — each enemy casts a configurable raycast-based vision cone via the `vision_cone_2d` addon, layered with a direct line-of-sight raycast so walls reliably block detection.
- **PATROL / COMBAT / SEARCH state machine** — enemies patrol fixed paths or point sets, snap into COMBAT (vision cone turns red) the moment they see the player, and fall back to a timed SEARCH phase (vision cone turns orange) if they lose sight, before resuming patrol (vision cone green).
- **Global alert / radio-delay propagation** — when one enemy spots the player, it broadcasts to every other enemy in the level; each one engages after a short "radio call" delay. Enemies actively tracking the player also periodically re-broadcast the player's live position, so allies converging on a stale last-known position can pick up a fresher one from a teammate who still has you within LOS, rather than reverting to SEARCH the moment they arrive.
- **A\* pathfinding around walls** — a dedicated `PathfindingManager` autoload builds an `AStarGrid2D` from the level's wall geometry, so enemies pursuing without direct line of sight route intelligently around obstacles instead of getting stuck. Falls back to standard Godot navigation when a path can't be found.
- **Player mechanics** — Player can shoot enemies or do a stealth takedown (if out of enemy LOS) by pressing the F key. 

## Controls

| Action | Binding |
|---|---|
| Move | `W` `A` `S` `D` |
| Melee Attack | `F` |

## Getting Started

**Requirements:** [Godot 4.7](https://godotengine.org/download) (GL Compatibility renderer)

1. Clone the repository:
   ```
   git clone https://github.com/raumsie/Silent-Protocol.git
   ```
2. Open Godot 4.7+, choose **Import**, and select this project's `project.godot`.
3. Run the project (F5) — the main scene is `res://Scenes/Level.tscn`.

### Running Tests

This project uses [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) for automated testing. Test scripts live under `tests/unit/` — see the GUT documentation or the project's test tooling for invocation details.

## Third-Party Assets / Credits

- **[Vision Cone 2D](https://github.com/sirdorius)** by sirdorius — `res://addons/vision_cone_2d/`, dual-licensed MIT / Apache-2.0. Powers the enemy vision-cone detection system.
- **[GUT (Godot Unit Test)](https://github.com/bitwes/Gut)** by Tom "Butch" Wesley — `res://addons/gut/`, MIT-licensed. Used as the project's test framework (development dependency, not a runtime gameplay asset).

## Author

Developed by **Raumsie Gaballa**.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
