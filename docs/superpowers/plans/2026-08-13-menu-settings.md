# SkyBallRun Menu Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent Windows PC menu/settings shell without changing the existing four-level runner simulation.

**Architecture:** A small Autoload owns ConfigFile-backed settings. A menu controller builds and owns CanvasLayer controls, while `main.gd` exposes game lifecycle methods and gates simulation on `game_started`/`paused`.

**Tech Stack:** Godot 4.7.1, GDScript, `ConfigFile`, `DisplayServer`, programmatic Control nodes.

## Global Constraints

- Preserve existing runner, four level thresholds, free-fall camera, game-over music and restart behavior.
- Target Windows PC at 960x600; support mouse and keyboard focus.
- Do not copy third-party repository source; use the referenced open-source menu patterns only as architectural guidance.

---

### Task 1: Persistent settings service

**Files:**
- Create: `scripts/settings.gd`
- Modify: `project.godot`

**Interfaces:**
- Produces Autoload `Settings` with `master_volume: float`, `music_enabled: bool`, `fullscreen: bool`, `load_settings()`, `save_settings()`, `apply_settings()`, `set_master_volume(value)`, `set_music_enabled(value)`, `set_fullscreen(value)`.

- [ ] Add ConfigFile load/save with defaults.
- [ ] Add audio bus lookup and DisplayServer fullscreen application.
- [ ] Register the script under `[autoload]` as `Settings`.
- [ ] Run Godot headless startup.

### Task 2: Menu controller UI

**Files:**
- Create: `scripts/menu_controller.gd`
- Modify: `scripts/main.gd`

**Interfaces:**
- Menu controller calls `game.start_new_game()`, `game.resume_game()`, `game.open_main_menu()`, `game.restart_from_menu()`, and `game.quit_game()`.
- Main exposes `is_game_active()`, `is_game_paused()`, `start_new_game()`, `pause_game()`, `resume_game()`, `open_main_menu()`, `restart_from_menu()`, `quit_game()`.

- [ ] Build main, pause and settings panels with styled buttons and keyboard focus.
- [ ] Add volume slider, music checkbox, fullscreen checkbox and back button.
- [ ] Connect ESC/P and button actions without allowing simulation input through menus.

### Task 3: Integrate lifecycle and verification

**Files:**
- Modify: `scripts/main.gd`
- Modify: `README.md`

- [ ] Gate `_process` until gameplay starts and while paused.
- [ ] Route generated music through Settings and restore menu state on reset.
- [ ] Run headless Godot check and `git diff --check`.
- [ ] Launch the Windows game and record the checkpoint commit.
