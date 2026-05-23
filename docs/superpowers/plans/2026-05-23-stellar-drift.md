# Stellar Drift Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a polished, playable 2D top-down twin-stick space shooter in Godot 4.6 by 17:30 PST today.

**Architecture:** Single-scene-per-responsibility composition. `GameState` autoload owns cross-scene state (score, wave, high score) and broadcasts via signals. Actors (Player, Enemies, Bullets, Asteroids) are independent scenes communicating only through physics layers and signals. The `Game` scene wires player + spawner + HUD; no actor reaches up into Game or HUD directly.

**Tech Stack:** Godot 4.6.3 (GL Compatibility), GDScript, Kenney *Space Shooter Redux* CC0 sprites, Kenney *Sci-Fi Sounds* CC0 audio. Godot MCP for headless verification (`run_project`, `get_debug_output`, `stop_project`).

**Verification model:** Spec explicitly defers unit tests. Each task ends with a manual smoke test via Godot MCP `run_project`, observing debug output and confirming expected runtime behavior, then committing.

**Source of truth:** `docs/superpowers/specs/2026-05-23-stellar-drift-design.md`.

---

## File Map

| Path | Responsibility |
|------|----------------|
| `project.godot` | Engine config: autoload, input map, collision layer names, window size |
| `main.tscn` | Entry scene → loads MainMenu |
| `globals/GameState.gd` | Autoload: score, wave, high score, signals, persistence |
| `scripts/MainMenu.gd` + `scenes/menus/MainMenu.tscn` | Title, Start, Quit, high score display |
| `scripts/Game.gd` + `scenes/game/Game.tscn` | Arena root: spawner, HUD, player, asteroids |
| `scripts/Player.gd` + `scenes/actors/Player.tscn` | Player movement, aim, shoot, damage |
| `scripts/PlayerBullet.gd` + `scenes/actors/PlayerBullet.tscn` | Player projectile |
| `scripts/Asteroid.gd` + `scenes/actors/Asteroid.tscn` | Static destructible obstacle |
| `scripts/EnemyChaser.gd` + `scenes/actors/EnemyChaser.tscn` | Homing melee enemy |
| `scripts/EnemyShooter.gd` + `scenes/actors/EnemyShooter.tscn` | Ranged enemy |
| `scripts/EnemyBullet.gd` + `scenes/actors/EnemyBullet.tscn` | Enemy projectile |
| `scripts/Spawner.gd` | Wave spawning logic (child of Game) |
| `scripts/HUD.gd` + `scenes/ui/HUD.tscn` | Score / wave / hearts display |
| `scripts/GameOver.gd` + `scenes/menus/GameOver.tscn` | Final score + retry |
| `assets/sprites/`, `assets/audio/`, `assets/fonts/` | Downloaded Kenney CC0 |

---

## Task 1: Acquire Kenney CC0 assets

**Files:**
- Create: `assets/sprites/`
- Create: `assets/audio/`
- Create: `assets/fonts/`
- Create: `assets/CREDITS.md`

- [ ] **Step 1: Create asset directory structure**

```bash
mkdir -p assets/sprites assets/audio assets/fonts
```

- [ ] **Step 2: Download Kenney Space Shooter Redux pack**

Try primary URL first; if 404, fall back to scraping the kenney.nl asset page.

```bash
cd /tmp
curl -L --fail -o kenney_space.zip \
  "https://kenney.nl/media/pages/assets/space-shooter-redux/c7d4b04f00-1677570366/kenney_space-shooter-redux.zip" \
  || curl -L --fail -o kenney_space.zip \
     "$(curl -sL https://kenney.nl/assets/space-shooter-redux | grep -oE 'https://[^"]+kenney[^"]*space-shooter-redux\.zip' | head -1)"
unzip -o kenney_space.zip -d kenney_space
```

If both fail, fall back to OpenGameArt CC0:

```bash
# Fallback: use the SpaceShooterRedux GitHub mirror
curl -L --fail -o kenney_space.zip \
  "https://github.com/SpaceCadetDuck/SpaceShooterRedux/archive/refs/heads/master.zip"
unzip -o kenney_space.zip -d kenney_space
```

- [ ] **Step 3: Copy sprite subset into the project**

Copy only what we use; this keeps the repo small.

```bash
PROJ=/home/carlomigueldy/personal/godot-game-sample
SRC=$(find /tmp/kenney_space -type d -name 'PNG' -print -quit)
cp "$SRC/playerShip1_blue.png" "$PROJ/assets/sprites/player.png"
cp "$SRC/Enemies/enemyRed1.png" "$PROJ/assets/sprites/enemy_chaser.png"
cp "$SRC/Enemies/enemyGreen3.png" "$PROJ/assets/sprites/enemy_shooter.png"
cp "$SRC/Lasers/laserBlue01.png" "$PROJ/assets/sprites/player_bullet.png"
cp "$SRC/Lasers/laserRed01.png" "$PROJ/assets/sprites/enemy_bullet.png"
cp "$SRC/Meteors/meteorGrey_big1.png" "$PROJ/assets/sprites/asteroid.png"
cp "$SRC/Backgrounds/blue.png" "$PROJ/assets/sprites/bg.png"
cp "$SRC/UI/playerLife1_blue.png" "$PROJ/assets/sprites/heart.png"
```

If file paths differ slightly (Kenney repackages occasionally), use `find` to locate equivalents:

```bash
find /tmp/kenney_space -iname 'playerShip*blue*.png'
find /tmp/kenney_space -iname 'enemyRed*.png' | head -3
```

- [ ] **Step 4: Download Kenney Sci-Fi Sounds pack**

```bash
cd /tmp
curl -L --fail -o kenney_sfx.zip \
  "$(curl -sL https://kenney.nl/assets/sci-fi-sounds | grep -oE 'https://[^"]+kenney[^"]*sci-fi-sounds\.zip' | head -1)" \
  || curl -L --fail -o kenney_sfx.zip \
     "https://kenney.nl/media/pages/assets/sci-fi-sounds/d8d8e0d2c2-1677573636/kenney_sci-fi-sounds.zip"
unzip -o kenney_sfx.zip -d kenney_sfx
```

- [ ] **Step 5: Copy SFX subset**

```bash
PROJ=/home/carlomigueldy/personal/godot-game-sample
SRC=$(find /tmp/kenney_sfx -type d -name 'Audio' -print -quit)
[ -z "$SRC" ] && SRC=/tmp/kenney_sfx
cp "$(find "$SRC" -iname 'laser*.ogg' -o -iname 'laser*.wav' | head -1)" "$PROJ/assets/audio/laser.ogg" 2>/dev/null || \
  cp "$(find "$SRC" -iname 'laser*.ogg' -o -iname 'laser*.wav' | head -1)" "$PROJ/assets/audio/laser.wav"
cp "$(find "$SRC" -iname 'explosion*.ogg' -o -iname 'explosion*.wav' | head -1)" "$PROJ/assets/audio/explosion.ogg" 2>/dev/null || \
  cp "$(find "$SRC" -iname 'explosion*.ogg' -o -iname 'explosion*.wav' | head -1)" "$PROJ/assets/audio/explosion.wav"
cp "$(find "$SRC" -iname 'impact*.ogg' -o -iname 'impact*.wav' -o -iname 'hit*.ogg' | head -1)" "$PROJ/assets/audio/hit.ogg" 2>/dev/null || true
```

Note: file extension may be `.ogg` or `.wav` depending on pack version. The scripts below reference assets by directory glob (`assets/audio/laser.*`); adjust references after download if extensions surprise you.

- [ ] **Step 6: Write CREDITS.md**

Write `assets/CREDITS.md`:

```markdown
# Asset Credits

All assets used in *Stellar Drift* are CC0 (Public Domain).

- **Sprites:** Kenney — *Space Shooter Redux* — https://kenney.nl/assets/space-shooter-redux
- **Audio:** Kenney — *Sci-Fi Sounds* — https://kenney.nl/assets/sci-fi-sounds

Thanks to Kenney (https://kenney.nl/) for releasing these assets to the public domain.
```

- [ ] **Step 7: Verify**

```bash
ls assets/sprites/ assets/audio/
```

Expected: `player.png`, `enemy_chaser.png`, `enemy_shooter.png`, `player_bullet.png`, `enemy_bullet.png`, `asteroid.png`, `bg.png`, `heart.png` and at least `laser.*`, `explosion.*` audio files.

- [ ] **Step 8: Commit**

```bash
git add assets/
git commit -m "feat: add Kenney CC0 sprites and SFX"
```

---

## Task 2: Project bootstrap

**Files:**
- Modify: `project.godot` (entire file rewrite)
- Modify: `main.tscn` (rewrite to load MainMenu)
- Create: `globals/` (empty dir)

- [ ] **Step 1: Rewrite `project.godot`**

Replace the entire file with:

```ini
; Engine configuration file.
config_version=5

[application]

config/name="Stellar Drift"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")
config/icon="res://icon.svg"

[autoload]

GameState="*res://globals/GameState.gd"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[input]

move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
shoot={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}

[layer_names]

2d_physics/layer_1="world"
2d_physics/layer_2="player"
2d_physics/layer_3="player_bullet"
2d_physics/layer_4="enemy"
2d_physics/layer_5="enemy_bullet"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

Note: keycode `65` is `A`, `68` is `D`, `87` is `W`, `83` is `S`. The `physical_keycode 4194319/20/21/22` values are arrow keys (left/up/right/down).

- [ ] **Step 2: Create globals directory placeholder**

```bash
mkdir -p globals scripts scenes/menus scenes/game scenes/actors scenes/ui
```

- [ ] **Step 3: Write a minimal `globals/GameState.gd` placeholder so the autoload resolves**

```gdscript
extends Node
```

Full content lands in Task 3; this is a stub so the editor doesn't error on import.

- [ ] **Step 4: Replace `main.tscn` with a loader that swaps to MainMenu on `_ready`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1_main"]

[node name="Main" type="Node"]
script = ExtResource("1_main")
```

- [ ] **Step 5: Write `scripts/Main.gd`**

```gdscript
extends Node

func _ready() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
```

(MainMenu.tscn will exist after Task 4; the editor will warn but won't crash when running this scene later. We verify after Task 4.)

- [ ] **Step 6: Headless import**

Force Godot to import resources without opening the editor UI:

```bash
godot --headless --quit-after 5 2>&1 | tail -20
```

Expected: no error lines about missing autoload script.

- [ ] **Step 7: Commit**

```bash
git add project.godot main.tscn globals/ scripts/Main.gd
git commit -m "feat: bootstrap project config, autoload, input map, collision layers"
```

---

## Task 3: GameState autoload

**Files:**
- Modify: `globals/GameState.gd`

- [ ] **Step 1: Replace `globals/GameState.gd` with full implementation**

```gdscript
extends Node

signal score_changed(new_score: int)
signal wave_changed(new_wave: int)
signal player_hp_changed(new_hp: int)
signal game_over_requested

const SAVE_PATH := "user://highscore.cfg"

var score: int = 0
var wave: int = 0
var high_score: int = 0

func _ready() -> void:
	_load_high_score()

func reset_run() -> void:
	score = 0
	wave = 0
	score_changed.emit(score)
	wave_changed.emit(wave)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func set_wave(new_wave: int) -> void:
	wave = new_wave
	wave_changed.emit(wave)

func report_player_hp(hp: int) -> void:
	player_hp_changed.emit(hp)

func report_game_over() -> void:
	if score > high_score:
		high_score = score
		_save_high_score()
	game_over_requested.emit()

func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "high", high_score)
	cfg.save(SAVE_PATH)

func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("score", "high", 0))
```

- [ ] **Step 2: Verify autoload loads cleanly**

```bash
godot --headless --quit-after 5 2>&1 | grep -iE 'error|script' | head
```

Expected: no errors. (Warnings about missing scenes are OK.)

- [ ] **Step 3: Commit**

```bash
git add globals/GameState.gd
git commit -m "feat: GameState autoload with score, wave, high-score persistence"
```

---

## Task 4: Main menu

**Files:**
- Create: `scripts/MainMenu.gd`
- Create: `scenes/menus/MainMenu.tscn`

- [ ] **Step 1: Write `scripts/MainMenu.gd`**

```gdscript
extends Control

@onready var high_score_label: Label = $VBox/HighScore
@onready var start_button: Button = $VBox/StartButton
@onready var quit_button: Button = $VBox/QuitButton

func _ready() -> void:
	high_score_label.text = "High Score: %d" % GameState.high_score
	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(_on_quit)
	start_button.grab_focus()

func _on_start() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_quit() -> void:
	get_tree().quit()
```

- [ ] **Step 2: Write `scenes/menus/MainMenu.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/MainMenu.gd" id="1_menu"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_menu")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.04, 0.05, 0.12, 1)

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -160.0
offset_top = -140.0
offset_right = 160.0
offset_bottom = 140.0
theme_override_constants/separation = 24

[node name="Title" type="Label" parent="VBox"]
layout_mode = 2
text = "STELLAR DRIFT"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 56

[node name="HighScore" type="Label" parent="VBox"]
layout_mode = 2
text = "High Score: 0"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 22

[node name="StartButton" type="Button" parent="VBox"]
layout_mode = 2
text = "Start"
theme_override_font_sizes/font_size = 28

[node name="QuitButton" type="Button" parent="VBox"]
layout_mode = 2
text = "Quit"
theme_override_font_sizes/font_size = 28
```

- [ ] **Step 3: Verify via Godot MCP**

Use `mcp__godot__run_project` with the project path `/home/carlomigueldy/personal/godot-game-sample`. After ~3 seconds, call `mcp__godot__get_debug_output`, then `mcp__godot__stop_project`.

Expected debug output: no errors. Manually: the menu scene appears with title and two buttons. (Headless will not render a window — just confirm no script/parse errors.)

If MCP unavailable:

```bash
godot --quit-after 3 2>&1 | tail -20
```

- [ ] **Step 4: Commit**

```bash
git add scripts/MainMenu.gd scenes/menus/MainMenu.tscn
git commit -m "feat: main menu scene with start/quit"
```

---

## Task 5: Game scene shell + menu→game transition

**Files:**
- Create: `scripts/Game.gd`
- Create: `scenes/game/Game.tscn`

This task creates the Game scene as an empty arena with a camera and background. Player, HUD, enemies are wired in later tasks.

- [ ] **Step 1: Write `scripts/Game.gd`**

```gdscript
extends Node2D

const ARENA_RECT := Rect2(0, 0, 1280, 720)

func _ready() -> void:
	GameState.reset_run()
```

- [ ] **Step 2: Write `scenes/game/Game.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/Game.gd" id="1_game"]
[ext_resource type="Texture2D" path="res://assets/sprites/bg.png" id="2_bg"]

[node name="Game" type="Node2D"]
script = ExtResource("1_game")

[node name="Background" type="Sprite2D" parent="."]
position = Vector2(640, 360)
texture = ExtResource("2_bg")
centered = true

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(640, 360)

[node name="Arena" type="Node2D" parent="."]

[node name="Walls" type="StaticBody2D" parent="Arena"]
collision_layer = 1
collision_mask = 0

[node name="WallTop" type="CollisionShape2D" parent="Arena/Walls"]
position = Vector2(640, -10)
shape = SubResource("RectShapeTop")

[node name="WallBottom" type="CollisionShape2D" parent="Arena/Walls"]
position = Vector2(640, 730)
shape = SubResource("RectShapeBottom")

[node name="WallLeft" type="CollisionShape2D" parent="Arena/Walls"]
position = Vector2(-10, 360)
shape = SubResource("RectShapeLeft")

[node name="WallRight" type="CollisionShape2D" parent="Arena/Walls"]
position = Vector2(1290, 360)
shape = SubResource("RectShapeRight")

[sub_resource type="RectangleShape2D" id="RectShapeTop"]
size = Vector2(1300, 20)

[sub_resource type="RectangleShape2D" id="RectShapeBottom"]
size = Vector2(1300, 20)

[sub_resource type="RectangleShape2D" id="RectShapeLeft"]
size = Vector2(20, 740)

[sub_resource type="RectangleShape2D" id="RectShapeRight"]
size = Vector2(20, 740)
```

Note: the `[sub_resource]` blocks must precede the `[node]` blocks that reference them. If Godot warns about ordering, move them to before the first `[node]` block:

```
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/Game.gd" id="1_game"]
[ext_resource type="Texture2D" path="res://assets/sprites/bg.png" id="2_bg"]

[sub_resource type="RectangleShape2D" id="RectShapeTop"]
size = Vector2(1300, 20)

[sub_resource type="RectangleShape2D" id="RectShapeBottom"]
size = Vector2(1300, 20)

[sub_resource type="RectangleShape2D" id="RectShapeLeft"]
size = Vector2(20, 740)

[sub_resource type="RectangleShape2D" id="RectShapeRight"]
size = Vector2(20, 740)

[node name="Game" type="Node2D"]
script = ExtResource("1_game")

[node name="Background" type="Sprite2D" parent="."]
position = Vector2(640, 360)
texture = ExtResource("2_bg")
centered = true

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(640, 360)

[node name="Arena" type="Node2D" parent="."]

[node name="Walls" type="StaticBody2D" parent="Arena"]
collision_layer = 1
collision_mask = 0

[node name="WallTop" type="CollisionShape2D" parent="Arena/Walls"]
position = Vector2(640, -10)
shape = SubResource("RectShapeTop")

[node name="WallBottom" type="CollisionShape2D" parent="Arena/Walls"]
position = Vector2(640, 730)
shape = SubResource("RectShapeBottom")

[node name="WallLeft" type="CollisionShape2D" parent="Arena/Walls"]
position = Vector2(-10, 360)
shape = SubResource("RectShapeLeft")

[node name="WallRight" type="CollisionShape2D" parent="Arena/Walls"]
position = Vector2(1290, 360)
shape = SubResource("RectShapeRight")
```

Use this second form (sub_resources first).

- [ ] **Step 3: Verify with Godot MCP**

`mcp__godot__run_project` → wait 3s → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`.

Expected: no errors. The Main scene autoloads, MainMenu renders, no scripts have parse errors. Clicking Start (in a manual run) would transition to Game — but the headless verification is parse-correctness only.

- [ ] **Step 4: Commit**

```bash
git add scripts/Game.gd scenes/game/Game.tscn
git commit -m "feat: empty game scene with arena walls and background"
```

---

## Task 6: Player movement + aiming

**Files:**
- Create: `scripts/Player.gd`
- Create: `scenes/actors/Player.tscn`
- Modify: `scenes/game/Game.tscn` (instance Player)

- [ ] **Step 1: Write `scripts/Player.gd`** (movement only — shooting comes in Task 7)

```gdscript
extends CharacterBody2D

signal died

@export var speed: float = 320.0
@export var accel: float = 1800.0
@export var friction: float = 1500.0
@export var max_hp: int = 3
@export var invuln_time: float = 0.6

@onready var sprite: Sprite2D = $Sprite

var hp: int = 3
var _invuln: float = 0.0

func _ready() -> void:
	hp = max_hp
	GameState.report_player_hp(hp)

func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.0:
		velocity = velocity.move_toward(input_dir * speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	look_at(get_global_mouse_position())

func take_damage(amount: int = 1) -> void:
	if _invuln > 0.0:
		return
	hp = max(0, hp - amount)
	GameState.report_player_hp(hp)
	_invuln = invuln_time
	if hp <= 0:
		died.emit()
		queue_free()

func is_invulnerable() -> bool:
	return _invuln > 0.0
```

- [ ] **Step 2: Write `scenes/actors/Player.tscn`**

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/Player.gd" id="1_player"]
[ext_resource type="Texture2D" path="res://assets/sprites/player.png" id="2_tex"]

[sub_resource type="CircleShape2D" id="PlayerShape"]
radius = 28.0

[node name="Player" type="CharacterBody2D"]
collision_layer = 2
collision_mask = 1
script = ExtResource("1_player")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
rotation = 1.5707963
scale = Vector2(0.6, 0.6)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("PlayerShape")

[node name="Muzzle" type="Marker2D" parent="."]
position = Vector2(48, 0)
```

Note: `rotation = 1.5707963` rotates the sprite 90° because Kenney ships face up by default; we want them facing right (Godot's "forward" for `look_at`).

- [ ] **Step 3: Add Player instance to `Game.tscn`**

Append to `scenes/game/Game.tscn` (after the last node block):

```
[ext_resource type="PackedScene" path="res://scenes/actors/Player.tscn" id="3_player"]

[node name="Player" parent="." instance=ExtResource("3_player")]
position = Vector2(640, 360)
```

Also increment `load_steps` in the header by 1 (e.g., from `7` to `8`).

Concretely: open `scenes/game/Game.tscn`, change `load_steps=7` to `load_steps=8`, add the `[ext_resource]` for Player.tscn after the other ext_resources, and add the Player `[node]` block at the bottom.

- [ ] **Step 4: Verify with Godot MCP**

Run the project. Manually (if able): click Start from main menu, see player ship in arena, WASD moves it, mouse rotates it. If MCP-headless only, confirm no parse errors and no missing-resource warnings.

```bash
godot --headless --quit-after 5 2>&1 | grep -iE 'error|warn' | head
```

- [ ] **Step 5: Commit**

```bash
git add scripts/Player.gd scenes/actors/Player.tscn scenes/game/Game.tscn
git commit -m "feat: player movement and mouse aim"
```

---

## Task 7: Player bullet + shooting

**Files:**
- Create: `scripts/PlayerBullet.gd`
- Create: `scenes/actors/PlayerBullet.tscn`
- Modify: `scripts/Player.gd` (add shooting)
- Modify: `scenes/actors/Player.tscn` (preload bullet)

- [ ] **Step 1: Write `scripts/PlayerBullet.gd`**

```gdscript
extends Area2D

@export var speed: float = 900.0
@export var lifetime: float = 1.2
@export var damage: int = 1

var _time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	_try_hit(body)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)
	queue_free()

func _try_hit(node: Node) -> void:
	if node.has_method("take_damage"):
		node.take_damage(damage)
```

- [ ] **Step 2: Write `scenes/actors/PlayerBullet.tscn`**

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/PlayerBullet.gd" id="1_pb"]
[ext_resource type="Texture2D" path="res://assets/sprites/player_bullet.png" id="2_tex"]

[sub_resource type="CircleShape2D" id="PBShape"]
radius = 6.0

[node name="PlayerBullet" type="Area2D"]
collision_layer = 4
collision_mask = 9
script = ExtResource("1_pb")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
rotation = 1.5707963
scale = Vector2(0.7, 0.7)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("PBShape")
```

Layer/mask explanation: player bullet is on layer 3 (value `4`). Mask `9` = layer 1 (`1`) + layer 4 (`8`) = world + enemies.

- [ ] **Step 3: Update `scripts/Player.gd` to add shooting**

Replace the file with:

```gdscript
extends CharacterBody2D

signal died

@export var speed: float = 320.0
@export var accel: float = 1800.0
@export var friction: float = 1500.0
@export var fire_rate: float = 0.18
@export var bullet_scene: PackedScene
@export var max_hp: int = 3
@export var invuln_time: float = 0.6

@onready var sprite: Sprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle

var hp: int = 3
var _invuln: float = 0.0
var _shoot_cooldown: float = 0.0

func _ready() -> void:
	hp = max_hp
	GameState.report_player_hp(hp)

func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.0:
		velocity = velocity.move_toward(input_dir * speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	look_at(get_global_mouse_position())

	if Input.is_action_pressed("shoot") and _shoot_cooldown <= 0.0:
		_shoot()
		_shoot_cooldown = fire_rate

func _shoot() -> void:
	if bullet_scene == null:
		return
	var b: Node2D = bullet_scene.instantiate()
	b.global_position = muzzle.global_position
	b.rotation = rotation
	get_parent().add_child(b)

func take_damage(amount: int = 1) -> void:
	if _invuln > 0.0:
		return
	hp = max(0, hp - amount)
	GameState.report_player_hp(hp)
	_invuln = invuln_time
	if hp <= 0:
		died.emit()
		queue_free()

func is_invulnerable() -> bool:
	return _invuln > 0.0
```

- [ ] **Step 4: Wire `bullet_scene` in `scenes/actors/Player.tscn`**

Replace the Player.tscn file with:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/Player.gd" id="1_player"]
[ext_resource type="Texture2D" path="res://assets/sprites/player.png" id="2_tex"]
[ext_resource type="PackedScene" path="res://scenes/actors/PlayerBullet.tscn" id="3_bullet"]

[sub_resource type="CircleShape2D" id="PlayerShape"]
radius = 28.0

[node name="Player" type="CharacterBody2D"]
collision_layer = 2
collision_mask = 1
script = ExtResource("1_player")
bullet_scene = ExtResource("3_bullet")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
rotation = 1.5707963
scale = Vector2(0.6, 0.6)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("PlayerShape")

[node name="Muzzle" type="Marker2D" parent="."]
position = Vector2(48, 0)
```

- [ ] **Step 5: Verify**

Run via Godot MCP. Headless check: no parse errors, no missing resources. (Manual play would show bullets spawning at muzzle.)

- [ ] **Step 6: Commit**

```bash
git add scripts/PlayerBullet.gd scenes/actors/PlayerBullet.tscn scripts/Player.gd scenes/actors/Player.tscn
git commit -m "feat: player shooting with rate-limited bullets"
```

---

## Task 8: Asteroids

**Files:**
- Create: `scripts/Asteroid.gd`
- Create: `scenes/actors/Asteroid.tscn`
- Modify: `scripts/Game.gd` (scatter asteroids on ready)
- Modify: `scenes/game/Game.tscn` (preload asteroid scene)

- [ ] **Step 1: Write `scripts/Asteroid.gd`**

```gdscript
extends StaticBody2D

@export var max_hp: int = 2
@export var score_value: int = 5

var hp: int

func _ready() -> void:
	hp = max_hp

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		GameState.add_score(score_value)
		queue_free()
```

- [ ] **Step 2: Write `scenes/actors/Asteroid.tscn`**

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/Asteroid.gd" id="1_ast"]
[ext_resource type="Texture2D" path="res://assets/sprites/asteroid.png" id="2_tex"]

[sub_resource type="CircleShape2D" id="AstShape"]
radius = 40.0

[node name="Asteroid" type="StaticBody2D"]
collision_layer = 1
collision_mask = 0
script = ExtResource("1_ast")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
scale = Vector2(0.8, 0.8)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("AstShape")
```

- [ ] **Step 3: Update `scripts/Game.gd` to scatter asteroids**

```gdscript
extends Node2D

const ARENA_RECT := Rect2(80, 80, 1120, 560)
const ASTEROID_COUNT := 10

@export var asteroid_scene: PackedScene

@onready var arena: Node2D = $Arena

func _ready() -> void:
	GameState.reset_run()
	_scatter_asteroids()

func _scatter_asteroids() -> void:
	if asteroid_scene == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < ASTEROID_COUNT and attempts < 200:
		attempts += 1
		var p := Vector2(
			rng.randf_range(ARENA_RECT.position.x, ARENA_RECT.end.x),
			rng.randf_range(ARENA_RECT.position.y, ARENA_RECT.end.y)
		)
		# Stay away from player spawn
		if p.distance_to(Vector2(640, 360)) < 140.0:
			continue
		# Stay away from other asteroids
		var ok := true
		for q in placed:
			if p.distance_to(q) < 90.0:
				ok = false
				break
		if not ok:
			continue
		var a: Node2D = asteroid_scene.instantiate()
		a.position = p
		arena.add_child(a)
		placed.append(p)
```

- [ ] **Step 4: Wire `asteroid_scene` and remove old script load_steps in `scenes/game/Game.tscn`**

Update header `load_steps` to `9` and add the asteroid ext_resource. Also set the export on the Game node. The diff is conceptually:

```
load_steps=8   →   load_steps=9
add: [ext_resource type="PackedScene" path="res://scenes/actors/Asteroid.tscn" id="4_ast"]
on [node name="Game" ...]: add line  asteroid_scene = ExtResource("4_ast")
```

Concretely, the relevant top of file becomes:

```
[gd_scene load_steps=9 format=3]

[ext_resource type="Script" path="res://scripts/Game.gd" id="1_game"]
[ext_resource type="Texture2D" path="res://assets/sprites/bg.png" id="2_bg"]
[ext_resource type="PackedScene" path="res://scenes/actors/Player.tscn" id="3_player"]
[ext_resource type="PackedScene" path="res://scenes/actors/Asteroid.tscn" id="4_ast"]
```

And the Game node:

```
[node name="Game" type="Node2D"]
script = ExtResource("1_game")
asteroid_scene = ExtResource("4_ast")
```

- [ ] **Step 5: Verify**

```bash
godot --headless --quit-after 5 2>&1 | grep -iE 'error|warn' | head
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add scripts/Asteroid.gd scenes/actors/Asteroid.tscn scripts/Game.gd scenes/game/Game.tscn
git commit -m "feat: destructible asteroids scattered at run start"
```

---

## Task 9: Enemy Chaser

**Files:**
- Create: `scripts/EnemyChaser.gd`
- Create: `scenes/actors/EnemyChaser.tscn`

(Spawning comes in Task 11 — here we just build the actor.)

- [ ] **Step 1: Write `scripts/EnemyChaser.gd`**

```gdscript
extends CharacterBody2D

@export var speed: float = 130.0
@export var max_hp: int = 1
@export var contact_damage: int = 1
@export var score_value: int = 10

var hp: int

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	look_at(player.global_position)
	var col := move_and_collide(velocity * delta)
	if col:
		var other := col.get_collider()
		if other and other.is_in_group("player") and other.has_method("take_damage"):
			other.take_damage(contact_damage)
			_die_silently()

func _find_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes.size() > 0 else null

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		GameState.add_score(score_value)
		queue_free()

func _die_silently() -> void:
	queue_free()
```

- [ ] **Step 2: Write `scenes/actors/EnemyChaser.tscn`**

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/EnemyChaser.gd" id="1_chaser"]
[ext_resource type="Texture2D" path="res://assets/sprites/enemy_chaser.png" id="2_tex"]

[sub_resource type="CircleShape2D" id="ChaserShape"]
radius = 26.0

[node name="EnemyChaser" type="CharacterBody2D"]
collision_layer = 8
collision_mask = 3
script = ExtResource("1_chaser")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
rotation = 1.5707963
scale = Vector2(0.55, 0.55)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("ChaserShape")
```

Layer `8` = enemy (layer 4). Mask `3` = world (1) + player (2).

- [ ] **Step 3: Add Player to `player` group**

Edit `scripts/Player.gd` `_ready()`:

```gdscript
func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	GameState.report_player_hp(hp)
```

- [ ] **Step 4: Verify**

```bash
godot --headless --quit-after 5 2>&1 | grep -iE 'error|warn' | head
```

- [ ] **Step 5: Commit**

```bash
git add scripts/EnemyChaser.gd scenes/actors/EnemyChaser.tscn scripts/Player.gd
git commit -m "feat: chaser enemy with homing movement and contact damage"
```

---

## Task 10: HUD

**Files:**
- Create: `scripts/HUD.gd`
- Create: `scenes/ui/HUD.tscn`
- Modify: `scenes/game/Game.tscn` (instance HUD)

- [ ] **Step 1: Write `scripts/HUD.gd`**

```gdscript
extends CanvasLayer

@onready var score_label: Label = $Margin/Top/Score
@onready var wave_label: Label = $Margin/Top/Wave
@onready var hearts: HBoxContainer = $Margin/TopRight/Hearts

@export var heart_texture: Texture2D

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.wave_changed.connect(_on_wave_changed)
	GameState.player_hp_changed.connect(_on_hp_changed)
	_on_score_changed(GameState.score)
	_on_wave_changed(GameState.wave)
	_on_hp_changed(3)

func _on_score_changed(s: int) -> void:
	score_label.text = "Score: %d" % s

func _on_wave_changed(w: int) -> void:
	wave_label.text = "Wave: %d" % w

func _on_hp_changed(hp: int) -> void:
	for c in hearts.get_children():
		c.queue_free()
	for i in hp:
		var tr := TextureRect.new()
		tr.texture = heart_texture
		tr.custom_minimum_size = Vector2(32, 32)
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts.add_child(tr)
```

- [ ] **Step 2: Write `scenes/ui/HUD.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/HUD.gd" id="1_hud"]
[ext_resource type="Texture2D" path="res://assets/sprites/heart.png" id="2_heart"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1_hud")
heart_texture = ExtResource("2_heart")

[node name="Margin" type="MarginContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_right = 0.0
offset_bottom = 0.0
theme_override_constants/margin_left = 16
theme_override_constants/margin_right = 16
theme_override_constants/margin_top = 12
theme_override_constants/margin_bottom = 12

[node name="Top" type="HBoxContainer" parent="Margin"]
layout_mode = 2
size_flags_horizontal = 0
theme_override_constants/separation = 32

[node name="Score" type="Label" parent="Margin/Top"]
layout_mode = 2
text = "Score: 0"
theme_override_font_sizes/font_size = 24

[node name="Wave" type="Label" parent="Margin/Top"]
layout_mode = 2
text = "Wave: 0"
theme_override_font_sizes/font_size = 24

[node name="TopRight" type="HBoxContainer" parent="Margin"]
layout_mode = 2
alignment = 2
size_flags_horizontal = 3

[node name="Hearts" type="HBoxContainer" parent="Margin/TopRight"]
layout_mode = 2
theme_override_constants/separation = 6
```

Note: the layout above places Score+Wave top-left and Hearts top-right. Because `Margin` is a single MarginContainer, the two HBox children stack — we accept this for the deadline. If aesthetics demand, wrap in an HBoxContainer at the Margin level instead. **Functional adequacy over polish for HUD layout.**

- [ ] **Step 3: Instance HUD in `Game.tscn`**

Bump `load_steps` to 10, add ext_resource, add HUD node child:

```
[ext_resource type="PackedScene" path="res://scenes/ui/HUD.tscn" id="5_hud"]
```

And at the bottom of `Game.tscn`:

```
[node name="HUD" parent="." instance=ExtResource("5_hud")]
```

- [ ] **Step 4: Verify**

```bash
godot --headless --quit-after 5 2>&1 | grep -iE 'error|warn' | head
```

- [ ] **Step 5: Commit**

```bash
git add scripts/HUD.gd scenes/ui/HUD.tscn scenes/game/Game.tscn
git commit -m "feat: HUD with score, wave, and heart-based health display"
```

---

## Task 11: Wave spawner

**Files:**
- Create: `scripts/Spawner.gd`
- Modify: `scenes/game/Game.tscn` (add Spawner child, expose chaser scene)

- [ ] **Step 1: Write `scripts/Spawner.gd`**

```gdscript
extends Node

signal wave_cleared

@export var chaser_scene: PackedScene
@export var shooter_scene: PackedScene  # wired in Task 12
@export var arena_rect: Rect2 = Rect2(80, 80, 1120, 560)
@export var wave_break_seconds: float = 2.0
@export var spawn_stagger_seconds: float = 0.35

var _current_wave: int = 0
var _alive_enemies: int = 0
var _spawning: bool = false

func _ready() -> void:
	# Wait one frame so Game._ready (which calls GameState.reset_run) has run.
	await get_tree().process_frame
	_start_next_wave()

func _start_next_wave() -> void:
	_current_wave += 1
	GameState.set_wave(_current_wave)
	var count := _current_wave + 2
	var shooter_chance: float = clampf(float(_current_wave - 1) * 0.10, 0.0, 0.60)
	_spawning = true
	for i in count:
		_spawn_one(shooter_chance)
		await get_tree().create_timer(spawn_stagger_seconds).timeout
	_spawning = false
	_check_wave_clear()

func _spawn_one(shooter_chance: float) -> void:
	var use_shooter := shooter_scene != null and randf() < shooter_chance
	var scene := shooter_scene if use_shooter else chaser_scene
	if scene == null:
		return
	var e: Node2D = scene.instantiate()
	e.position = _random_edge_position()
	e.tree_exited.connect(_on_enemy_freed)
	get_parent().get_node("Arena").add_child(e)
	_alive_enemies += 1

func _random_edge_position() -> Vector2:
	var edge := randi() % 4
	match edge:
		0: return Vector2(arena_rect.position.x + randf() * arena_rect.size.x, arena_rect.position.y - 20)
		1: return Vector2(arena_rect.position.x + randf() * arena_rect.size.x, arena_rect.end.y + 20)
		2: return Vector2(arena_rect.position.x - 20, arena_rect.position.y + randf() * arena_rect.size.y)
		_: return Vector2(arena_rect.end.x + 20, arena_rect.position.y + randf() * arena_rect.size.y)

func _on_enemy_freed() -> void:
	_alive_enemies -= 1
	_check_wave_clear()

func _check_wave_clear() -> void:
	if _spawning or _alive_enemies > 0:
		return
	wave_cleared.emit()
	await get_tree().create_timer(wave_break_seconds).timeout
	_start_next_wave()
```

- [ ] **Step 2: Modify `Game.tscn` to add Spawner child and wire chaser scene**

Increment `load_steps` to 11. Add ext_resource for EnemyChaser:

```
[ext_resource type="Script" path="res://scripts/Spawner.gd" id="6_spawner"]
[ext_resource type="PackedScene" path="res://scenes/actors/EnemyChaser.tscn" id="7_chaser"]
```

Add at the bottom (after HUD):

```
[node name="Spawner" type="Node" parent="."]
script = ExtResource("6_spawner")
chaser_scene = ExtResource("7_chaser")
```

(Shooter scene wiring lands in Task 12.)

- [ ] **Step 3: Verify**

Run via Godot MCP and observe debug output for ~5 seconds:

```bash
godot --headless --quit-after 6 2>&1 | grep -iE 'error|warn' | head
```

Expected: no errors. In a manual run, chasers spawn at edges and home toward player.

- [ ] **Step 4: Commit**

```bash
git add scripts/Spawner.gd scenes/game/Game.tscn
git commit -m "feat: wave spawner with escalating count and shooter ratio"
```

---

## Task 12: Enemy Bullet + Enemy Shooter

**Files:**
- Create: `scripts/EnemyBullet.gd`
- Create: `scenes/actors/EnemyBullet.tscn`
- Create: `scripts/EnemyShooter.gd`
- Create: `scenes/actors/EnemyShooter.tscn`
- Modify: `scenes/game/Game.tscn` (wire shooter scene into Spawner)

- [ ] **Step 1: Write `scripts/EnemyBullet.gd`**

```gdscript
extends Area2D

@export var speed: float = 380.0
@export var lifetime: float = 2.2
@export var damage: int = 1

var _time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	queue_free()
```

- [ ] **Step 2: Write `scenes/actors/EnemyBullet.tscn`**

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/EnemyBullet.gd" id="1_eb"]
[ext_resource type="Texture2D" path="res://assets/sprites/enemy_bullet.png" id="2_tex"]

[sub_resource type="CircleShape2D" id="EBShape"]
radius = 6.0

[node name="EnemyBullet" type="Area2D"]
collision_layer = 16
collision_mask = 3
script = ExtResource("1_eb")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
rotation = 1.5707963
scale = Vector2(0.7, 0.7)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("EBShape")
```

Layer `16` = enemy_bullet (layer 5). Mask `3` = world + player.

- [ ] **Step 3: Write `scripts/EnemyShooter.gd`**

```gdscript
extends CharacterBody2D

@export var speed: float = 110.0
@export var preferred_distance: float = 320.0
@export var distance_tolerance: float = 40.0
@export var max_hp: int = 2
@export var contact_damage: int = 1
@export var score_value: int = 25
@export var fire_interval: float = 1.5
@export var bullet_scene: PackedScene

var hp: int
var _fire_cooldown: float = 0.0

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_fire_cooldown = randf_range(0.4, fire_interval)

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var player := _find_player()
	if player == null:
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	look_at(player.global_position)

	if dist > preferred_distance + distance_tolerance:
		velocity = dir * speed
	elif dist < preferred_distance - distance_tolerance:
		velocity = -dir * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 2.0 * delta)
	move_and_slide()

	if _fire_cooldown <= 0.0 and bullet_scene != null:
		_fire(dir)
		_fire_cooldown = fire_interval

func _fire(dir: Vector2) -> void:
	var b: Node2D = bullet_scene.instantiate()
	b.global_position = global_position + dir * 32.0
	b.rotation = dir.angle()
	get_parent().add_child(b)

func _find_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes.size() > 0 else null

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		GameState.add_score(score_value)
		queue_free()
```

- [ ] **Step 4: Write `scenes/actors/EnemyShooter.tscn`**

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/EnemyShooter.gd" id="1_sh"]
[ext_resource type="Texture2D" path="res://assets/sprites/enemy_shooter.png" id="2_tex"]
[ext_resource type="PackedScene" path="res://scenes/actors/EnemyBullet.tscn" id="3_eb"]

[sub_resource type="CircleShape2D" id="SHShape"]
radius = 28.0

[node name="EnemyShooter" type="CharacterBody2D"]
collision_layer = 8
collision_mask = 3
script = ExtResource("1_sh")
bullet_scene = ExtResource("3_eb")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
rotation = 1.5707963
scale = Vector2(0.6, 0.6)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("SHShape")
```

- [ ] **Step 5: Wire shooter into Spawner in `Game.tscn`**

Increment `load_steps` to 12. Add:

```
[ext_resource type="PackedScene" path="res://scenes/actors/EnemyShooter.tscn" id="8_shooter"]
```

Update the Spawner node:

```
[node name="Spawner" type="Node" parent="."]
script = ExtResource("6_spawner")
chaser_scene = ExtResource("7_chaser")
shooter_scene = ExtResource("8_shooter")
```

- [ ] **Step 6: Verify**

```bash
godot --headless --quit-after 6 2>&1 | grep -iE 'error|warn' | head
```

- [ ] **Step 7: Commit**

```bash
git add scripts/EnemyBullet.gd scenes/actors/EnemyBullet.tscn scripts/EnemyShooter.gd scenes/actors/EnemyShooter.tscn scenes/game/Game.tscn
git commit -m "feat: enemy shooter and enemy bullets"
```

---

## Task 13: Player damage flow + game over signal

**Files:**
- Modify: `scripts/Player.gd` (already emits `died` — verify)
- Modify: `scripts/Game.gd` (handle player death → game over)

- [ ] **Step 1: Update `scripts/Game.gd`**

```gdscript
extends Node2D

const ARENA_RECT := Rect2(80, 80, 1120, 560)
const ASTEROID_COUNT := 10

@export var asteroid_scene: PackedScene

@onready var arena: Node2D = $Arena
@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	GameState.reset_run()
	_scatter_asteroids()
	if player and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

func _scatter_asteroids() -> void:
	if asteroid_scene == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < ASTEROID_COUNT and attempts < 200:
		attempts += 1
		var p := Vector2(
			rng.randf_range(ARENA_RECT.position.x, ARENA_RECT.end.x),
			rng.randf_range(ARENA_RECT.position.y, ARENA_RECT.end.y)
		)
		if p.distance_to(Vector2(640, 360)) < 140.0:
			continue
		var ok := true
		for q in placed:
			if p.distance_to(q) < 90.0:
				ok = false
				break
		if not ok:
			continue
		var a: Node2D = asteroid_scene.instantiate()
		a.position = p
		arena.add_child(a)
		placed.append(p)

func _on_player_died() -> void:
	GameState.report_game_over()
	# Brief delay so the death feels real, then transition.
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/menus/GameOver.tscn")
```

- [ ] **Step 2: Verify**

```bash
godot --headless --quit-after 6 2>&1 | grep -iE 'error|warn' | head
```

(GameOver.tscn doesn't exist yet — Godot will warn at runtime if the scene file is missing; we accept this since the next task creates it.)

- [ ] **Step 3: Commit**

```bash
git add scripts/Game.gd
git commit -m "feat: wire player death to game-over transition"
```

---

## Task 14: Game Over scene

**Files:**
- Create: `scripts/GameOver.gd`
- Create: `scenes/menus/GameOver.tscn`

- [ ] **Step 1: Write `scripts/GameOver.gd`**

```gdscript
extends Control

@onready var final_score_label: Label = $VBox/FinalScore
@onready var high_score_label: Label = $VBox/HighScore
@onready var retry_button: Button = $VBox/RetryButton
@onready var menu_button: Button = $VBox/MenuButton

func _ready() -> void:
	final_score_label.text = "Final Score: %d" % GameState.score
	high_score_label.text = "High Score: %d" % GameState.high_score
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)
	retry_button.grab_focus()

func _on_retry() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
```

- [ ] **Step 2: Write `scenes/menus/GameOver.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/GameOver.gd" id="1_go"]

[node name="GameOver" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_go")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.08, 0.02, 0.04, 1)

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -180.0
offset_top = -160.0
offset_right = 180.0
offset_bottom = 160.0
theme_override_constants/separation = 20

[node name="Title" type="Label" parent="VBox"]
layout_mode = 2
text = "GAME OVER"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 48

[node name="FinalScore" type="Label" parent="VBox"]
layout_mode = 2
text = "Final Score: 0"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 24

[node name="HighScore" type="Label" parent="VBox"]
layout_mode = 2
text = "High Score: 0"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 20

[node name="RetryButton" type="Button" parent="VBox"]
layout_mode = 2
text = "Retry"
theme_override_font_sizes/font_size = 26

[node name="MenuButton" type="Button" parent="VBox"]
layout_mode = 2
text = "Main Menu"
theme_override_font_sizes/font_size = 26
```

- [ ] **Step 3: Verify full loop**

```bash
godot --headless --quit-after 6 2>&1 | grep -iE 'error|warn' | head
```

Expected: clean. (Manual play would now go Menu → Game → death → GameOver → Retry → Game.)

- [ ] **Step 4: Commit**

```bash
git add scripts/GameOver.gd scenes/menus/GameOver.tscn
git commit -m "feat: game over screen with retry and menu options"
```

---

## Task 15: Polish — hit flash, muzzle flash, camera shake

**Files:**
- Modify: `scripts/Player.gd` (hit flash + muzzle flash + emit shake signal)
- Modify: `scenes/actors/Player.tscn` (add MuzzleFlash sprite)
- Modify: `scripts/Game.gd` (camera shake on player damage)
- Modify: `scenes/game/Game.tscn` (camera node already exists — wire to shake)

- [ ] **Step 1: Add MuzzleFlash node and update `Player.gd`**

Replace `scripts/Player.gd`:

```gdscript
extends CharacterBody2D

signal died
signal damaged

@export var speed: float = 320.0
@export var accel: float = 1800.0
@export var friction: float = 1500.0
@export var fire_rate: float = 0.18
@export var bullet_scene: PackedScene
@export var max_hp: int = 3
@export var invuln_time: float = 0.6

@onready var sprite: Sprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var muzzle_flash: Sprite2D = $Muzzle/Flash

var hp: int = 3
var _invuln: float = 0.0
var _shoot_cooldown: float = 0.0

func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	GameState.report_player_hp(hp)
	muzzle_flash.visible = false

func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.0:
		velocity = velocity.move_toward(input_dir * speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	look_at(get_global_mouse_position())

	if Input.is_action_pressed("shoot") and _shoot_cooldown <= 0.0:
		_shoot()
		_shoot_cooldown = fire_rate

func _shoot() -> void:
	if bullet_scene == null:
		return
	var b: Node2D = bullet_scene.instantiate()
	b.global_position = muzzle.global_position
	b.rotation = rotation
	get_parent().add_child(b)
	_flash_muzzle()

func _flash_muzzle() -> void:
	muzzle_flash.visible = true
	muzzle_flash.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.08)
	tween.tween_callback(func(): muzzle_flash.visible = false)

func take_damage(amount: int = 1) -> void:
	if _invuln > 0.0:
		return
	hp = max(0, hp - amount)
	GameState.report_player_hp(hp)
	_invuln = invuln_time
	damaged.emit()
	_flash_hit()
	if hp <= 0:
		died.emit()
		queue_free()

func _flash_hit() -> void:
	var tween := create_tween()
	sprite.modulate = Color(2.5, 0.5, 0.5, 1.0)
	tween.tween_property(sprite, "modulate", Color.WHITE, invuln_time)

func is_invulnerable() -> bool:
	return _invuln > 0.0
```

- [ ] **Step 2: Update `scenes/actors/Player.tscn` to add Muzzle/Flash sprite**

Replace the file with:

```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/Player.gd" id="1_player"]
[ext_resource type="Texture2D" path="res://assets/sprites/player.png" id="2_tex"]
[ext_resource type="PackedScene" path="res://scenes/actors/PlayerBullet.tscn" id="3_bullet"]
[ext_resource type="Texture2D" path="res://assets/sprites/player_bullet.png" id="4_flash"]

[sub_resource type="CircleShape2D" id="PlayerShape"]
radius = 28.0

[node name="Player" type="CharacterBody2D"]
collision_layer = 2
collision_mask = 1
script = ExtResource("1_player")
bullet_scene = ExtResource("3_bullet")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
rotation = 1.5707963
scale = Vector2(0.6, 0.6)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("PlayerShape")

[node name="Muzzle" type="Marker2D" parent="."]
position = Vector2(48, 0)

[node name="Flash" type="Sprite2D" parent="Muzzle"]
texture = ExtResource("4_flash")
scale = Vector2(1.5, 1.5)
modulate = Color(1, 0.9, 0.4, 1)
visible = false
```

- [ ] **Step 3: Update `scripts/Game.gd` for camera shake**

```gdscript
extends Node2D

const ARENA_RECT := Rect2(80, 80, 1120, 560)
const ASTEROID_COUNT := 10

@export var asteroid_scene: PackedScene

@onready var arena: Node2D = $Arena
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D

var _shake_time: float = 0.0
var _shake_strength: float = 0.0
var _camera_home: Vector2

func _ready() -> void:
	GameState.reset_run()
	_camera_home = camera.position
	_scatter_asteroids()
	if player:
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		if not player.damaged.is_connected(_on_player_damaged):
			player.damaged.connect(_on_player_damaged)

func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		camera.position = _camera_home + offset
		if _shake_time <= 0.0:
			camera.position = _camera_home

func _on_player_damaged() -> void:
	_shake_time = 0.28
	_shake_strength = 10.0

func _scatter_asteroids() -> void:
	if asteroid_scene == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < ASTEROID_COUNT and attempts < 200:
		attempts += 1
		var p := Vector2(
			rng.randf_range(ARENA_RECT.position.x, ARENA_RECT.end.x),
			rng.randf_range(ARENA_RECT.position.y, ARENA_RECT.end.y)
		)
		if p.distance_to(Vector2(640, 360)) < 140.0:
			continue
		var ok := true
		for q in placed:
			if p.distance_to(q) < 90.0:
				ok = false
				break
		if not ok:
			continue
		var a: Node2D = asteroid_scene.instantiate()
		a.position = p
		arena.add_child(a)
		placed.append(p)

func _on_player_died() -> void:
	GameState.report_game_over()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/menus/GameOver.tscn")
```

- [ ] **Step 4: Verify**

```bash
godot --headless --quit-after 6 2>&1 | grep -iE 'error|warn' | head
```

- [ ] **Step 5: Commit**

```bash
git add scripts/Player.gd scenes/actors/Player.tscn scripts/Game.gd
git commit -m "feat: hit flash, muzzle flash, and camera shake on damage"
```

---

## Task 16: Polish — explosion particles + SFX

**Files:**
- Create: `scripts/Explosion.gd`
- Create: `scenes/actors/Explosion.tscn`
- Modify: enemy + asteroid scripts to spawn an explosion on death
- Modify: Player to play SFX on shoot + damage
- Modify: scripts to play SFX on death

We add a small reusable Explosion scene that contains CPUParticles2D + an AudioStreamPlayer2D and free-self after.

- [ ] **Step 1: Write `scripts/Explosion.gd`**

```gdscript
extends Node2D

@export var lifetime: float = 0.9

@onready var particles: CPUParticles2D = $Particles
@onready var sfx: AudioStreamPlayer2D = $SFX

func _ready() -> void:
	particles.emitting = true
	if sfx.stream:
		sfx.play()
	await get_tree().create_timer(lifetime).timeout
	queue_free()
```

- [ ] **Step 2: Write `scenes/actors/Explosion.tscn`**

We embed the particle parameters inline so the scene is self-contained. Audio stream is loaded if available; if not, the sound is skipped silently.

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/Explosion.gd" id="1_exp"]

[node name="Explosion" type="Node2D"]
script = ExtResource("1_exp")

[node name="Particles" type="CPUParticles2D" parent="."]
emitting = false
amount = 32
lifetime = 0.6
one_shot = true
explosiveness = 0.9
direction = Vector2(0, 0)
spread = 180.0
initial_velocity_min = 80.0
initial_velocity_max = 240.0
gravity = Vector2(0, 0)
scale_amount_min = 2.0
scale_amount_max = 4.0
color = Color(1, 0.7, 0.3, 1)

[node name="SFX" type="AudioStreamPlayer2D" parent="."]
volume_db = -6.0
```

- [ ] **Step 3: Add audio stream wiring in a deferred setup script (so missing files don't fail import)**

Add `_set_stream` helper at the top of `Explosion.gd`:

```gdscript
extends Node2D

@export var lifetime: float = 0.9
@export var sound_path: String = "res://assets/audio/explosion.ogg"

@onready var particles: CPUParticles2D = $Particles
@onready var sfx: AudioStreamPlayer2D = $SFX

func _ready() -> void:
	particles.emitting = true
	_load_and_play_sfx()
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _load_and_play_sfx() -> void:
	var candidates := [sound_path, "res://assets/audio/explosion.wav"]
	for p in candidates:
		if ResourceLoader.exists(p):
			sfx.stream = load(p)
			sfx.play()
			return
```

- [ ] **Step 4: Spawn explosion from enemies and asteroids on death**

Update `scripts/EnemyChaser.gd`:

```gdscript
extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://scenes/actors/Explosion.tscn")

@export var speed: float = 130.0
@export var max_hp: int = 1
@export var contact_damage: int = 1
@export var score_value: int = 10

var hp: int

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	look_at(player.global_position)
	var col := move_and_collide(velocity * delta)
	if col:
		var other := col.get_collider()
		if other and other.is_in_group("player") and other.has_method("take_damage"):
			other.take_damage(contact_damage)
			_spawn_explosion()
			queue_free()

func _find_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes.size() > 0 else null

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		GameState.add_score(score_value)
		_spawn_explosion()
		queue_free()

func _spawn_explosion() -> void:
	var e: Node2D = EXPLOSION_SCENE.instantiate()
	e.global_position = global_position
	get_parent().add_child(e)
```

Apply the same `EXPLOSION_SCENE` const + `_spawn_explosion()` pattern to `EnemyShooter.gd` and `Asteroid.gd` (call `_spawn_explosion()` right before `queue_free()` in their death paths).

Concretely for `scripts/EnemyShooter.gd`, replace `take_damage`:

```gdscript
const EXPLOSION_SCENE := preload("res://scenes/actors/Explosion.tscn")

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		GameState.add_score(score_value)
		_spawn_explosion()
		queue_free()

func _spawn_explosion() -> void:
	var e: Node2D = EXPLOSION_SCENE.instantiate()
	e.global_position = global_position
	get_parent().add_child(e)
```

And in `scripts/Asteroid.gd`:

```gdscript
extends StaticBody2D

const EXPLOSION_SCENE := preload("res://scenes/actors/Explosion.tscn")

@export var max_hp: int = 2
@export var score_value: int = 5

var hp: int

func _ready() -> void:
	hp = max_hp

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		GameState.add_score(score_value)
		_spawn_explosion()
		queue_free()

func _spawn_explosion() -> void:
	var e: Node2D = EXPLOSION_SCENE.instantiate()
	e.global_position = global_position
	get_parent().add_child(e)
```

- [ ] **Step 5: Add SFX to Player shooting + damage**

Update `scripts/Player.gd` to play sounds. Add two `AudioStreamPlayer2D` children and load on `_ready`:

Append to `_ready()` in Player.gd:

```gdscript
	_load_sound($LaserSFX, ["res://assets/audio/laser.ogg", "res://assets/audio/laser.wav"])
	_load_sound($HitSFX, ["res://assets/audio/hit.ogg", "res://assets/audio/hit.wav", "res://assets/audio/impact.ogg", "res://assets/audio/impact.wav"])
```

Add helper:

```gdscript
func _load_sound(player_node: AudioStreamPlayer2D, candidates: Array) -> void:
	for p in candidates:
		if ResourceLoader.exists(p):
			player_node.stream = load(p)
			return
```

In `_shoot()` after `_flash_muzzle()`:

```gdscript
	if $LaserSFX.stream:
		$LaserSFX.pitch_scale = randf_range(0.95, 1.08)
		$LaserSFX.play()
```

In `take_damage()` after `damaged.emit()`:

```gdscript
	if $HitSFX.stream:
		$HitSFX.play()
```

Add the two sound nodes to `Player.tscn` (append at the end):

```
[node name="LaserSFX" type="AudioStreamPlayer2D" parent="."]
volume_db = -10.0

[node name="HitSFX" type="AudioStreamPlayer2D" parent="."]
volume_db = -4.0
```

- [ ] **Step 6: Verify**

```bash
godot --headless --quit-after 6 2>&1 | grep -iE 'error|warn' | head
```

- [ ] **Step 7: Commit**

```bash
git add scripts/Explosion.gd scenes/actors/Explosion.tscn scripts/EnemyChaser.gd scripts/EnemyShooter.gd scripts/Asteroid.gd scripts/Player.gd scenes/actors/Player.tscn
git commit -m "feat: explosion particles and SFX for shoot/hit/destruction"
```

---

## Task 17: Final smoke test + manual playthrough

**Files:** none

This task is verification-only.

- [ ] **Step 1: Headless parse check**

```bash
godot --headless --quit-after 8 2>&1 | tee /tmp/godot-final.log | grep -iE 'error|warn' | head -30
```

Expected: zero `ERROR` lines. Warnings about empty MIDI / GPU compat fallbacks are fine.

- [ ] **Step 2: Run a real windowed session (if display available) via Godot MCP**

Use `mcp__godot__run_project` to launch. Watch for:
- Main menu appears with title, high-score, Start, Quit.
- Start → Game scene with player, asteroids scattered.
- WASD moves the ship, mouse aims, click fires bullets with muzzle flash.
- Chasers spawn from arena edges in wave 1.
- Bullets destroy chasers, score increments by 10 each.
- Asteroids destruct on 2 hits, score +5.
- Wave 2 includes a shooter that fires red bullets back at the player.
- Player takes damage → red flash + camera shake; HUD heart disappears.
- After 3 hits → death, brief pause, Game Over scene appears with final + high score.
- Retry → fresh run with score reset; high score persists across runs.

Then `mcp__godot__stop_project`.

- [ ] **Step 3: Update README briefly**

If a `README.md` exists, leave it alone. If not, the project already has the spec and plan for context. Skip unless time permits.

- [ ] **Step 4: Final commit / tag**

```bash
git log --oneline
git tag -a v0.1.0 -m "Stellar Drift v0.1 - playable build"
```

(Skip `git push` unless user explicitly asks for it.)

---

## Polish backlog (drop if running short on time)

These were listed in the spec but are not gated tasks above. Pick up only if everything above is done with time to spare.

- **Starfield parallax background** — replace single bg sprite with a `ParallaxBackground` + 2 scrolling layers of star sprites.
- **Pause menu (Escape)** — overlay Control that pauses `get_tree()` via `paused = true`.
- **Game-over SFX** — already covered by the death explosion of the player. Optional separate "game_over.wav" plays on the GameOver scene `_ready`.
- **Subtle player ship engine trail** — small CPUParticles2D child of Player, emits while `input_dir.length() > 0`.

---

## Self-review notes

**Spec coverage check:**

| Spec requirement | Covered by |
|---|---|
| WASD/arrows move, mouse aim, LMB shoot, rate-limited | Tasks 6, 7 |
| Bounded arena, no wrap | Task 5 (arena walls) |
| Player 3 HP, invuln + flash on hit | Tasks 6, 13, 15 |
| Chaser: 1 HP, homing, contact damage | Tasks 9, 16 |
| Shooter: 2 HP, distance-keeping, ranged | Task 12 |
| Asteroids: 2 HP, scattered 8–12, +5 | Task 8 |
| Bullets as Area2D, despawn on hit / off-arena | Tasks 7, 12 |
| Wave N spawns N+2; shooter chance +10%/wave cap 60% | Task 11 |
| 2-second wave break | Task 11 |
| Score values 10/25/5 | Tasks 8, 9, 12 |
| High score persisted to `user://highscore.cfg` | Task 3 |
| HUD: score, wave, hearts | Task 10 |
| Game over → Retry / Menu | Task 14 |
| Collision layers per spec | Task 2, verified in actor scenes |
| Polish: muzzle flash, hit flash, camera shake | Task 15 |
| Polish: explosion particles, SFX | Task 16 |
| Polish: starfield, pause | Polish backlog (drop if needed) |
| CC0 asset sourcing + credits | Task 1 |
| Manual smoke verification via Godot MCP | Every task + Task 17 |

**Placeholder scan:** no TBD / TODO. Every script and scene is shown in full or with explicit replacement diffs.

**Type consistency:** `take_damage(amount: int = 1)` signature consistent across Player, EnemyChaser, EnemyShooter, Asteroid. `score_value` consistent. `GameState.add_score` / `report_player_hp` / `report_game_over` / `set_wave` consistent. Signal names `died`, `damaged`, `score_changed`, `wave_changed`, `player_hp_changed`, `game_over_requested` consistent.

**Scope check:** single project, single deliverable, fits a 17-task plan.
