# 🧼 Suds & Sequence
### A pixel-art dish-washing puzzle game in Godot 4

---

## Setup Instructions

1. **Install Godot 4.2+** from https://godotengine.org/download
2. **Open the project**: Launch Godot → Import → select the `dishpuzzle/` folder → `project.godot`
3. **Add the GameData autoload**:
   - Go to **Project → Project Settings → Autoload**
   - Click the folder icon, select `res://scripts/GameData.gd`
   - Set Name to `GameData`, click **Add**
4. Hit **F5** (or the Play button) to run!

---

## How to Play

Each dish has a **required sequence** of washing steps. Do them out of order and you'll lose a star!

### Controls

| Action | Keyboard | Mouse |
|--------|----------|-------|
| Toggle Water | `W` | 💧 Water button |
| Apply Soap | `S` | 🧼 Soap button |
| Dry dish | `E` | 🧻 Dry button |
| Scrub | — | Click + drag over dish |
| Scrape debris | — | Click the brown spots |
| Next dish | `Enter` | Next Dish button |

### Step Rules

- **Scrape first** if there are food bits (brown spots on the dish)
- **Soak first** for dishes marked "soak required" (pot, bowl) — soap won't work without it!
- **Soap → Scrub** in that order, then **Rinse** (turn water on again after scrubbing)
- **Dry last** — only works after rinsing

### Scoring

- ⭐ 1 star — completed but made mistakes
- ⭐⭐ 2 stars — max 1 wrong step attempt  
- ⭐⭐⭐ 3 stars — perfect run + all optional steps (like voluntary soaking)
- Time bonus if you finish before the par time

---

## Project Structure

```
dishpuzzle/
├── project.godot          # Godot project config + input map
├── scripts/
│   ├── GameData.gd        # Autoload: dish definitions, level data, game state
│   ├── DishState.gd       # Per-dish puzzle state machine (signals-based)
│   ├── KitchenLevel.gd    # Main gameplay scene controller
│   └── MainMenu.gd        # Menu + level select
├── scenes/
│   ├── MainMenu.tscn      # Title screen
│   └── KitchenLevel.tscn  # The sink / gameplay scene
└── assets/
    ├── sprites/           # (add your pixel art here)
    └── fonts/             # (add a pixel font here, e.g. Pixelify Sans)
```

---

## Extending the Game

### Add a new dish type
1. Add an entry to `GameData.DishType` enum
2. Add its data dict to `GameData.DISH_DATA`
3. Add it to a level in `GameData.LEVELS`

### Add a new level
Add a dict to `GameData.LEVELS`:
```gdscript
{
    "id": 4,
    "name": "My New Level",
    "dishes": [GameData.DishType.POT, GameData.DishType.GLASS],
    "par_time": 150,
    "hint": "Start the pot soaking first!"
}
```

### Add pixel art
- Replace `DishSprite` ColorRect with a `Sprite2D` using your pixel art texture
- Set texture filter to **Nearest** (Project Settings → Rendering → Textures → Default Texture Filter = Nearest)
- Recommended resolution: 320×180 viewport (already configured)

### Add a pixel font
- Download a free pixel font (e.g. **Pixelify Sans**, **Press Start 2P** from Google Fonts)
- Import into `assets/fonts/`
- Create a `Theme` resource and apply it to the root Control nodes

---

## Pixel Art Style Guide
- **Palette**: Dark navy bg `#141220`, cream dishes, muted blues for water, warm amber for UI accents
- **Resolution**: 320×180 (NES-ish), upscaled 3–4× at runtime
- **Texture filter**: Always Nearest (no blurring)
- **Tile size**: 8px grid recommended for UI elements
