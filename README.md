# Snakes & Ladders (Godot 4.7.2)

# AI DISCLOSURE: EVERYTHING INCLUDING THIS README, EXCLUDING THIS LINE WAS CREATED BY CLAUDE CODE. GAME WAS BUILT FOR PLAYING AND FUN AS WELL AS POTENTIAL LEARNING ON MY PART.

You (red) against 1-3 CPU players. All graphics are drawn in code, so there are no assets to import.

## Run
1. Open Godot 4.7.2, click **Import**, pick `project.godot`.
2. Press **F5**.

## Play
- Pick a theme, board layout and number of opponents, then **Start Game**.
- Click **Roll Dice** or press **Space / Enter** on your turn. CPU players roll automatically.
- Green-tinted squares start a ladder, red-tinted squares are snake heads.
- **Next Theme** switches the look mid-game. **Menu** returns to setup.

## Themes
Classic Board, Jungle, Deep Space, Candy Land, Ocean.

## Layouts
Classic 10x10 (the traditional board), Spiral 10x10, Quick 6x6, Grand 12x12, Wide 15x6,
and Random 10x10 (new snakes and ladders each time).

## Sound
Everything is synthesised in code, so there are no audio files. In the menu you can switch
**Music** and **Sound effects** on or off and set each volume with its slider. The settings are
saved between sessions (`user://settings.cfg`). Sound effects cover the dice rattle and landing,
token hops, ladders, snakes, rolling a 6, needing an exact roll, win and lose. Background music is
a looping tune. It is generated just after the window opens, so music starts about a second in.

## Options
- Need an exact roll to finish (on by default).
- Rolling a 6 gives an extra turn (on by default).

## Files
- `project.godot` - project settings (1280x720, scaled to the window)
- `main.tscn` - a single Control node with the script attached
- `main.gd` - the whole game: board, dice, themes, layouts, CPU turns

## Tweaking
- Add themes in `_make_themes()` and layouts in `_make_layouts()`.
- A layout can include a fixed `"jumps"` dictionary (`start: end`), otherwise jumps are generated from its `"seed"` (0 = random).
