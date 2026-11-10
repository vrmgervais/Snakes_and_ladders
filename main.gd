extends Control
## Snakes & Ladders for Godot 4.7.x
## One human player vs 1-3 CPU players. Five themes, six board layouts.
## Everything is drawn in code, so there are no external assets to import.

enum State { MENU, PLAYING, GAME_OVER }

const VIEW := Vector2(1280, 720)
const TRAY_H := 44.0
const PANEL_X := 720.0
const PANEL_CX := 990.0
const DICE_CENTER := Vector2(990, 420)
const DICE_SIZE := 110.0
const PIPS := {
	1: [4],
	2: [0, 8],
	3: [0, 4, 8],
	4: [0, 2, 6, 8],
	5: [0, 2, 4, 6, 8],
	6: [0, 2, 3, 5, 6, 8],
}

class Conf:
	var pos: Vector2
	var vel: Vector2
	var col: Color
	var rot: float
	var spin: float
	var sz: float

var player_colors: Array = [Color.html("e74c3c"), Color.html("3498db"), Color.html("2ecc71"), Color.html("f1c40f")]

var state: int = State.MENU
var themes: Array = []
var layouts: Array = []
var th: Dictionary = {}
var th_idx := 0
var lay_idx := 0
var num_cpu := 1
var rule_exact := true
var rule_six := true

# Board
var cols := 10
var rows := 10
var total := 100
var cs := 60.0
var board_rect := Rect2()
var path: Array[Vector2i] = []
var jump_to: Dictionary = {}

# Players
var n_players := 2
var pos: Array[int] = []
var tok_pos: Array[Vector2] = []
var tok_hop: Array[float] = []
var tok_off: Array[Vector2] = []
var cur := 0
var busy := false
var game_id := 0
var winner := -1
var log_lines: Array[String] = []
var active_tween: Tween

# Dice
var dice_value := 1
var rolling := false
var dice_timer := 0.0
var dice_shake := Vector2.ZERO
var dice_rot := 0.0

# Visuals
var anim_time := 0.0
var deco: Array[Vector3] = []
var confetti: Array = []
var font: Font
var _sb := StyleBoxFlat.new()

# Audio
var music_on := true
var sfx_on := true
var music_vol := 0.5
var sfx_vol := 0.8
var sfx: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_idx := 0
var music_player: AudioStreamPlayer

# UI nodes
var menu_box: VBoxContainer
var theme_ob: OptionButton
var layout_ob: OptionButton
var cpu_ob: OptionButton
var roll_btn: Button
var again_btn: Button
var theme_btn: Button
var menu_btn: Button
var log_label: Label
var ui_labels: Array[Label] = []
var ui_checks: Array[CheckButton] = []


func _ready() -> void:
	font = ThemeDB.fallback_font
	randomize()
	themes = _make_themes()
	layouts = _make_layouts()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 70:
		deco.append(Vector3(rng.randf() * VIEW.x, rng.randf() * VIEW.y, rng.randf_range(0.3, 1.0)))
	_load_settings()
	_setup_audio()
	_build_ui()
	_apply_theme(0)
	_show_menu()
	_setup_layout(0)
	# Music is synthesised after the first frame so the window appears instantly.
	await get_tree().process_frame
	_start_music()


# --------------------------------------------------------------------------
# Data: themes and layouts
# --------------------------------------------------------------------------

func _t(nm: String, dec: String, bg: String, bg2: String, ca: String, cb: String, ln: String, tx: String,
		fin: String, pn: String, pn2: String, ptx: String, acc: String, rail: String, rung: String,
		dice: String, pip: String, snakes: Array) -> Dictionary:
	var sn: Array = []
	for s in snakes:
		sn.append([Color.html(s[0]), Color.html(s[1])])
	return {
		"name": nm, "deco": dec,
		"bg": Color.html(bg), "bg2": Color.html(bg2),
		"cell_a": Color.html(ca), "cell_b": Color.html(cb),
		"line": Color.html(ln), "text": Color.html(tx), "finish": Color.html(fin),
		"panel": Color.html(pn), "panel2": Color.html(pn2), "panel_text": Color.html(ptx),
		"accent": Color.html(acc), "rail": Color.html(rail), "rung": Color.html(rung),
		"dice": Color.html(dice), "pip": Color.html(pip), "snakes": sn,
	}


func _make_themes() -> Array:
	return [
		_t("Classic Board", "none", "4a3322", "2a1c12", "f4e6c3", "e3c98f", "a8844a", "6b4a1f", "ffd86b",
			"2e2118", "443224", "f6ead0", "ffcf5a", "8b5a2b", "d9a35c", "fffaf0", "2b2118",
			[["c0392b", "f7d56a"], ["2e8b57", "e9f2a0"], ["7d3c98", "ecd1f5"], ["d35400", "fbe3a8"]]),
		_t("Jungle", "leaves", "1b4d2a", "0b2314", "c5e8a5", "9ad37f", "4e8b3d", "2b5a22", "ffe27a",
			"10291a", "1b3d28", "e4f5d4", "ffd24a", "b08d3c", "e6cf7a", "f3f9e6", "1b3d28",
			[["e6b800", "3a2a00"], ["ff7a1a", "3a1500"], ["9be84a", "1f4a00"], ["3fb8a0", "0b3d33"]]),
		_t("Deep Space", "stars", "151a45", "03040f", "1a2050", "262e6b", "4f5fe0", "9fb2ff", "6a4cff",
			"0a0d26", "151a45", "d6defe", "6cf3ff", "7df9ff", "4fb7ff", "e8ecff", "151a45",
			[["00e5b0", "00352a"], ["ff3df0", "3a0036"], ["ffe14d", "3a3000"], ["ff6a3d", "3a1200"]]),
		_t("Candy Land", "dots", "ffb6d9", "ffe3f1", "fff1f8", "ffc9e3", "ff8cc0", "c2185b", "fff08a",
			"6b2d5c", "853a72", "fff0f7", "ffe27a", "ff5c9a", "ffffff", "fff8fc", "c2185b",
			[["54d6b4", "ffffff"], ["a98bff", "ffffff"], ["ffa94d", "ffffff"], ["ff6f91", "ffffff"]]),
		_t("Ocean", "bubbles", "0d5c80", "03192b", "c8eef7", "93d6ea", "2b86a8", "14546d", "ffe08a",
			"062c44", "0c4565", "d8f3fb", "ffd36a", "c79a5a", "f1d9a8", "f1fbff", "0c4565",
			[["ff8a3d", "fff1d0"], ["2dd4bf", "e6fffb"], ["a78bfa", "f3eeff"], ["fb7185", "ffe4e8"]]),
	]


func _make_layouts() -> Array:
	return [
		{"name": "Classic 10x10", "cols": 10, "rows": 10, "mode": "snake", "seed": 1,
			"jumps": {1: 38, 4: 14, 9: 31, 21: 42, 28: 84, 36: 44, 51: 67, 71: 91, 80: 100,
				16: 6, 47: 26, 49: 11, 56: 53, 62: 19, 64: 60, 87: 24, 93: 73, 95: 75, 98: 78}},
		{"name": "Spiral 10x10", "cols": 10, "rows": 10, "mode": "spiral", "seed": 4242},
		{"name": "Quick 6x6", "cols": 6, "rows": 6, "mode": "snake", "seed": 77},
		{"name": "Grand 12x12", "cols": 12, "rows": 12, "mode": "snake", "seed": 1234},
		{"name": "Wide 15x6", "cols": 15, "rows": 6, "mode": "snake", "seed": 31337},
		{"name": "Random snakes & ladders 10x10", "cols": 10, "rows": 10, "mode": "snake", "seed": 0},
	]


func _build_path(c: int, r: int, mode: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if mode == "spiral":
		var left := 0
		var right := c - 1
		var bottom := 0
		var top := r - 1
		while left <= right and bottom <= top:
			for x in range(left, right + 1):
				out.append(Vector2i(x, bottom))
			bottom += 1
			for y in range(bottom, top + 1):
				out.append(Vector2i(right, y))
			right -= 1
			if bottom <= top:
				for x in range(right, left - 1, -1):
					out.append(Vector2i(x, top))
				top -= 1
			if left <= right:
				for y in range(top, bottom - 1, -1):
					out.append(Vector2i(left, y))
				left += 1
	else:
		for y in r:
			for x in c:
				var col := x if y % 2 == 0 else c - 1 - x
				out.append(Vector2i(col, y))
	return out


func _make_jumps(lay: Dictionary) -> Dictionary:
	if lay.has("jumps"):
		return (lay["jumps"] as Dictionary).duplicate()
	var rng := RandomNumberGenerator.new()
	var sd: int = lay["seed"]
	if sd == 0:
		rng.randomize()
	else:
		rng.seed = sd
	var n := cols * rows
	var min_len := maxi(3, mini(cols, rows))
	var result := {}
	var used := {1: true, n: true}
	var ladders := maxi(3, floori(n / 13.0))
	var snakes := maxi(3, floori(n / 11.0))
	for i in ladders:
		for attempt in 200:
			var a := rng.randi_range(2, n - min_len - 1)
			var b := rng.randi_range(a + min_len, n - 1)
			if not used.has(a) and not used.has(b):
				result[a] = b
				used[a] = true
				used[b] = true
				break
	for i in snakes:
		for attempt in 200:
			var head := rng.randi_range(min_len + 2, n - 1)
			var tail := rng.randi_range(2, head - min_len)
			if not used.has(head) and not used.has(tail):
				result[head] = tail
				used[head] = true
				used[tail] = true
				break
	return result


func _setup_layout(idx: int) -> void:
	lay_idx = idx
	var lay: Dictionary = layouts[idx]
	cols = lay["cols"]
	rows = lay["rows"]
	total = cols * rows
	path = _build_path(cols, rows, lay["mode"])
	cs = floorf(minf(680.0 / cols, 600.0 / rows))
	var bw := cs * cols
	var bh := cs * rows
	board_rect = Rect2(20.0 + (680.0 - bw) * 0.5, 24.0 + (600.0 - bh) * 0.5, bw, bh)
	jump_to = _make_jumps(lay)


# --------------------------------------------------------------------------
# UI construction
# --------------------------------------------------------------------------

func _make_row(label_text: String, ob: OptionButton) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	ui_labels.append(l)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.custom_minimum_size = Vector2(0, 40)
	row.add_child(ob)
	return row


func _make_check(text: String, on: bool) -> CheckButton:
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = on
	cb.add_theme_font_size_override("font_size", 18)
	ui_checks.append(cb)
	return cb


func _make_hud_button(text: String, r: Rect2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	add_child(b)
	return b


func _build_ui() -> void:
	# ---- menu ----
	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(744, 100)
	menu_box.size = Vector2(492, 560)
	menu_box.add_theme_constant_override("separation", 12)
	add_child(menu_box)

	var heading := Label.new()
	heading.text = "Game setup"
	heading.add_theme_font_size_override("font_size", 26)
	menu_box.add_child(heading)
	ui_labels.append(heading)

	theme_ob = OptionButton.new()
	for t in themes:
		theme_ob.add_item(String(t["name"]))
	theme_ob.item_selected.connect(_on_theme_selected)
	menu_box.add_child(_make_row("Theme", theme_ob))

	layout_ob = OptionButton.new()
	for l in layouts:
		layout_ob.add_item(String(l["name"]))
	layout_ob.item_selected.connect(_on_layout_selected)
	menu_box.add_child(_make_row("Board layout", layout_ob))

	cpu_ob = OptionButton.new()
	cpu_ob.add_item("1 CPU opponent")
	cpu_ob.add_item("2 CPU opponents")
	cpu_ob.add_item("3 CPU opponents")
	cpu_ob.item_selected.connect(func(i: int) -> void: num_cpu = i + 1)
	menu_box.add_child(_make_row("Opponents", cpu_ob))

	var exact := _make_check("Need an exact roll to finish", true)
	exact.toggled.connect(func(v: bool) -> void: rule_exact = v)
	menu_box.add_child(exact)

	var six := _make_check("Rolling a 6 gives an extra turn", true)
	six.toggled.connect(func(v: bool) -> void: rule_six = v)
	menu_box.add_child(six)

	menu_box.add_child(_make_audio_row("Music", music_on, music_vol, _set_music_on, _set_music_vol))
	menu_box.add_child(_make_audio_row("Sound effects", sfx_on, sfx_vol, _set_sfx_on, _set_sfx_vol))

	var start := Button.new()
	start.text = "Start Game"
	start.custom_minimum_size = Vector2(0, 56)
	start.add_theme_font_size_override("font_size", 26)
	start.pressed.connect(_on_start_pressed)
	menu_box.add_child(start)

	var tip := Label.new()
	tip.text = "Roll the dice, climb ladders, avoid snakes. You are the red token - first to reach the last square wins!"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(480, 0)
	tip.add_theme_font_size_override("font_size", 16)
	menu_box.add_child(tip)
	ui_labels.append(tip)

	# ---- in-game HUD ----
	roll_btn = _make_hud_button("Roll Dice", Rect2(890, 490, 200, 48))
	roll_btn.pressed.connect(_on_roll_pressed)
	again_btn = _make_hud_button("Play Again", Rect2(890, 490, 200, 48))
	again_btn.pressed.connect(_on_again_pressed)
	theme_btn = _make_hud_button("Next Theme", Rect2(740, 660, 150, 36))
	theme_btn.pressed.connect(_on_next_theme_pressed)
	menu_btn = _make_hud_button("Menu", Rect2(1090, 660, 150, 36))
	menu_btn.pressed.connect(_on_menu_pressed)

	log_label = Label.new()
	log_label.position = Vector2(740, 548)
	log_label.size = Vector2(500, 104)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.clip_text = true
	log_label.add_theme_font_size_override("font_size", 16)
	add_child(log_label)
	ui_labels.append(log_label)


func _set_hud_visible(v: bool) -> void:
	roll_btn.visible = v
	again_btn.visible = false
	log_label.visible = v
	theme_btn.visible = v
	menu_btn.visible = v


func _on_theme_selected(i: int) -> void:
	_play("click")
	_apply_theme(i)


func _on_layout_selected(i: int) -> void:
	_play("click")
	_setup_layout(i)


func _apply_theme(i: int) -> void:
	th_idx = i
	th = themes[i]
	var pt: Color = th["panel_text"]
	for l in ui_labels:
		l.add_theme_color_override("font_color", pt)
	for cb in ui_checks:
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			cb.add_theme_color_override(key, pt)
	if theme_ob:
		theme_ob.select(i)


# --------------------------------------------------------------------------
# Game flow
# --------------------------------------------------------------------------

func _pname(p: int) -> String:
	return "You" if p == 0 else "CPU %d" % p


func _log(s: String) -> void:
	log_lines.append(s)
	while log_lines.size() > 4:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)


func _kill_tween() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()


func _new_tween() -> Tween:
	_kill_tween()
	active_tween = create_tween()
	return active_tween


func _show_menu() -> void:
	game_id += 1
	_kill_tween()
	busy = false
	rolling = false
	confetti.clear()
	state = State.MENU
	menu_box.visible = true
	_set_hud_visible(false)


func _start_game(regen: bool) -> void:
	game_id += 1
	_kill_tween()
	if regen:
		_setup_layout(lay_idx)
	n_players = 1 + num_cpu
	pos.clear()
	tok_pos.clear()
	tok_hop.clear()
	tok_off.clear()
	for p in n_players:
		pos.append(0)
		tok_pos.append(_tray_pos(p))
		tok_hop.append(0.0)
		tok_off.append(Vector2.ZERO)
	cur = 0
	busy = false
	winner = -1
	rolling = false
	dice_value = 1
	dice_rot = 0.0
	dice_shake = Vector2.ZERO
	confetti.clear()
	log_lines.clear()
	state = State.PLAYING
	menu_box.visible = false
	_set_hud_visible(true)
	_log("Game on! Reach square %d first." % total)
	_begin_turn()


func _begin_turn() -> void:
	if state != State.PLAYING:
		return
	var gid := game_id
	if cur == 0:
		roll_btn.disabled = false
		_log("Your turn - roll the dice!")
	else:
		roll_btn.disabled = true
		await get_tree().create_timer(0.9).timeout
		if gid != game_id or state != State.PLAYING:
			return
		_take_turn()


func _on_roll_pressed() -> void:
	if state == State.PLAYING and cur == 0 and not busy:
		roll_btn.disabled = true
		_take_turn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if state == State.PLAYING and cur == 0 and not busy and not roll_btn.disabled:
			_on_roll_pressed()
		elif state == State.GAME_OVER:
			_start_game(true)


func _take_turn() -> void:
	if busy:
		return
	busy = true
	var gid := game_id
	var p := cur
	rolling = true
	dice_timer = 0.0
	_play("roll")
	await get_tree().create_timer(0.8).timeout
	if gid != game_id:
		return
	rolling = false
	dice_rot = 0.0
	dice_shake = Vector2.ZERO
	var v := randi_range(1, 6)
	dice_value = v
	_play("land")
	var target := pos[p] + v
	var moved := false
	if target > total:
		if rule_exact:
			_log("%s rolled %d - needs an exact roll to finish." % [_pname(p), v])
			_play("blocked")
			target = pos[p]
		else:
			target = total
	if target != pos[p]:
		moved = true
		_log("%s rolled a %d." % [_pname(p), v])
		await _move_to(gid, p, target)
		if gid != game_id:
			return
		if jump_to.has(pos[p]):
			var dest: int = jump_to[pos[p]]
			var is_snake := dest < pos[p]
			if is_snake:
				_log("Snake! %s slides from %d to %d." % [_pname(p), pos[p], dest])
			else:
				_log("Ladder! %s climbs from %d to %d." % [_pname(p), pos[p], dest])
			await get_tree().create_timer(0.25).timeout
			if gid != game_id:
				return
			_play("snake" if is_snake else "ladder")
			await _slide(gid, p, pos[p], dest, is_snake)
			if gid != game_id:
				return
	if pos[p] == total:
		_win(p)
		return
	busy = false
	if v == 6 and rule_six and moved:
		_log("%s rolled a 6 and goes again!" % _pname(p))
		_play("bonus")
	else:
		cur = (cur + 1) % n_players
	await get_tree().create_timer(0.45).timeout
	if gid != game_id:
		return
	_begin_turn()


func _move_to(gid: int, p: int, target: int) -> void:
	while pos[p] < target:
		var a := _cell_pos(p, pos[p])
		var b := _cell_pos(p, pos[p] + 1)
		_play("hop", 0.9 + 0.05 * float(pos[p] % 5))
		var tw := _new_tween()
		tw.tween_method(_hop_step.bind(p, a, b), 0.0, 1.0, 0.17)
		await tw.finished
		if gid != game_id:
			return
		pos[p] += 1
		tok_pos[p] = b
		tok_hop[p] = 0.0


func _hop_step(t: float, p: int, a: Vector2, b: Vector2) -> void:
	if p >= tok_pos.size():
		return
	tok_pos[p] = a.lerp(b, t)
	tok_hop[p] = sin(t * PI) * cs * 0.3


func _slide(gid: int, p: int, from_c: int, to_c: int, is_snake: bool) -> void:
	var tw := _new_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_slide_step.bind(p, from_c, to_c, is_snake), 0.0, 1.0, 0.95 if is_snake else 0.75)
	await tw.finished
	if gid != game_id:
		return
	pos[p] = to_c
	tok_pos[p] = _cell_pos(p, to_c)
	tok_hop[p] = 0.0


func _slide_step(t: float, p: int, from_c: int, to_c: int, is_snake: bool) -> void:
	if p >= tok_pos.size():
		return
	var a := _cell_center(from_c)
	var b := _cell_center(to_c)
	tok_pos[p] = _snake_pt(a, b, t, from_c) if is_snake else a.lerp(b, t)


func _win(p: int) -> void:
	winner = p
	busy = false
	state = State.GAME_OVER
	roll_btn.visible = false
	again_btn.visible = true
	if p == 0:
		_log("You reached square %d - you win!" % total)
		_spawn_confetti()
		_play("win")
	else:
		_log("%s reached square %d and wins. Better luck next time!" % [_pname(p), total])
		_play("lose")


func _spawn_confetti() -> void:
	for i in 220:
		var c := Conf.new()
		c.pos = Vector2(randf_range(0.0, VIEW.x), randf_range(-300.0, -10.0))
		c.vel = Vector2(randf_range(-60.0, 60.0), randf_range(60.0, 260.0))
		c.col = Color.from_hsv(randf(), 0.7, 1.0)
		c.rot = randf() * TAU
		c.spin = randf_range(-6.0, 6.0)
		c.sz = randf_range(6.0, 12.0)
		confetti.append(c)


# --------------------------------------------------------------------------
# Geometry helpers
# --------------------------------------------------------------------------

func _cell_rect(n: int) -> Rect2:
	var g := path[n - 1]
	return Rect2(board_rect.position.x + g.x * cs, board_rect.end.y - (g.y + 1) * cs, cs, cs)


func _cell_center(n: int) -> Vector2:
	return _cell_rect(n).get_center()


func _tray_pos(p: int) -> Vector2:
	return Vector2(board_rect.position.x + 34.0 + p * 40.0, board_rect.end.y + 12.0 + TRAY_H * 0.5)


func _cell_pos(p: int, c: int) -> Vector2:
	if c <= 0:
		return _tray_pos(p)
	return _cell_center(c)


func _snake_pt(a: Vector2, b: Vector2, t: float, seed_i: int) -> Vector2:
	var d := b - a
	var length := d.length()
	if length < 1.0:
		return a
	var perp := d.orthogonal() / length
	var waves := maxf(1.0, roundf(length / (cs * 2.0)))
	var env := pow(absf(sin(t * PI)), 0.75)
	var off := sin(t * waves * TAU - anim_time * 3.0 + seed_i) * cs * 0.24 * env
	return a.lerp(b, t) + perp * off


# --------------------------------------------------------------------------
# Audio (generated in code - no sound files needed)
# --------------------------------------------------------------------------

func _on_start_pressed() -> void:
	_play("click")
	_start_game(false)


func _on_again_pressed() -> void:
	_play("click")
	_start_game(true)


func _on_next_theme_pressed() -> void:
	_play("click")
	_apply_theme((th_idx + 1) % themes.size())


func _on_menu_pressed() -> void:
	_play("click")
	_show_menu()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		music_on = cfg.get_value("audio", "music_on", true)
		sfx_on = cfg.get_value("audio", "sfx_on", true)
		music_vol = cfg.get_value("audio", "music_vol", 0.5)
		sfx_vol = cfg.get_value("audio", "sfx_vol", 0.8)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.set_value("audio", "music_vol", music_vol)
	cfg.set_value("audio", "sfx_vol", sfx_vol)
	cfg.save("user://settings.cfg")


func _setup_audio() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var bi := AudioServer.bus_count - 1
			AudioServer.set_bus_name(bi, bus_name)
			AudioServer.set_bus_send(bi, "Master")
	for i in 6:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		sfx_players.append(pl)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	_build_sfx()
	_apply_audio()


func _apply_audio() -> void:
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(mi, (not music_on) or music_vol <= 0.001)
	AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(music_vol, 0.001)))
	AudioServer.set_bus_mute(si, (not sfx_on) or sfx_vol <= 0.001)
	AudioServer.set_bus_volume_db(si, linear_to_db(maxf(sfx_vol, 0.001)))
	if music_player:
		music_player.stream_paused = not music_on


func _set_music_on(v: bool) -> void:
	music_on = v
	_apply_audio()
	_save_settings()


func _set_music_vol(v: float) -> void:
	music_vol = v
	_apply_audio()
	_save_settings()


func _set_sfx_on(v: bool) -> void:
	sfx_on = v
	_apply_audio()
	_save_settings()
	_play("click")


func _set_sfx_vol(v: float) -> void:
	sfx_vol = v
	_apply_audio()
	_save_settings()


func _audio_slider_changed(v: float, pl: Label, vol_fn: Callable) -> void:
	pl.text = "%d%%" % int(v)
	vol_fn.call(v / 100.0)


func _make_audio_row(text: String, on: bool, vol: float, on_fn: Callable, vol_fn: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = on
	cb.custom_minimum_size = Vector2(190, 0)
	cb.add_theme_font_size_override("font_size", 18)
	cb.toggled.connect(on_fn)
	ui_checks.append(cb)
	row.add_child(cb)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 100.0
	sl.step = 1.0
	sl.value = vol * 100.0
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.custom_minimum_size = Vector2(0, 28)
	row.add_child(sl)
	var pl := Label.new()
	pl.text = "%d%%" % int(vol * 100.0)
	pl.custom_minimum_size = Vector2(48, 0)
	pl.add_theme_font_size_override("font_size", 16)
	ui_labels.append(pl)
	row.add_child(pl)
	sl.value_changed.connect(_audio_slider_changed.bind(pl, vol_fn))
	return row


func _play(nm: String, pitch: float = 1.0) -> void:
	if not sfx_on or not sfx.has(nm) or sfx_players.is_empty():
		return
	var pl := sfx_players[sfx_idx]
	sfx_idx = (sfx_idx + 1) % sfx_players.size()
	pl.stream = sfx[nm]
	pl.pitch_scale = pitch
	pl.play()


func _note(m: int) -> float:
	return 440.0 * pow(2.0, (m - 69) / 12.0)


func _ev(t: float, d: float, f0: float, f1: float, w: String, v: float, dec: float = 2.0) -> Dictionary:
	return {"t": t, "d": d, "f0": f0, "f1": f1, "w": w, "v": v, "dec": dec}


## Mixes a list of note events into a mono 16-bit AudioStreamWAV.
func _synth(events: Array, length: float, rate: int, loop: bool) -> AudioStreamWAV:
	var n := int(length * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for e in events:
		var ev: Dictionary = e
		var start := int(float(ev["t"]) * rate)
		var cnt := int(float(ev["d"]) * rate)
		var f0: float = ev["f0"]
		var f1: float = ev["f1"]
		var wave: String = ev["w"]
		var vol: float = ev["v"]
		var dec: float = ev["dec"]
		var phase := 0.0
		for i in cnt:
			var idx := start + i
			if idx >= n:
				if loop:
					idx = idx % n
				else:
					break
			var x := float(i) / cnt
			phase += TAU * lerpf(f0, f1, x) / rate
			var s := 0.0
			match wave:
				"sine":
					s = sin(phase)
				"square":
					s = signf(sin(phase)) * 0.6
				"saw":
					s = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
				"tri":
					s = absf(fposmod(phase / TAU, 1.0) * 2.0 - 1.0) * 2.0 - 1.0
				"noise":
					s = randf() * 2.0 - 1.0
			var att := minf(1.0, float(i) / (rate * 0.005))
			buf[idx] += s * vol * att * pow(1.0 - x, dec)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav


func _build_sfx() -> void:
	var rate := 22050
	sfx["click"] = _synth([_ev(0.0, 0.06, 900.0, 650.0, "sine", 0.35)], 0.08, rate, false)

	# Dice rattle: a burst of clicks
	var roll: Array = []
	for i in 14:
		roll.append(_ev(i * 0.057, 0.04, 0.0, 0.0, "noise", 0.32, 3.0))
		roll.append(_ev(i * 0.057, 0.035, 260.0 + (i * 53) % 220, 200.0, "sine", 0.18, 3.0))
	sfx["roll"] = _synth(roll, 0.9, rate, false)

	# Dice lands: low thump
	sfx["land"] = _synth([
		_ev(0.0, 0.2, 170.0, 55.0, "sine", 0.7),
		_ev(0.0, 0.06, 0.0, 0.0, "noise", 0.25, 3.0)], 0.25, rate, false)

	# Token hop
	sfx["hop"] = _synth([_ev(0.0, 0.1, 520.0, 780.0, "sine", 0.35, 1.5)], 0.12, rate, false)

	# Ladder: rising arpeggio
	var lad: Array = []
	var lad_notes := [72, 76, 79, 84, 88]
	for i in lad_notes.size():
		var f := _note(lad_notes[i])
		lad.append(_ev(i * 0.07, 0.2, f, f, "tri", 0.35))
	sfx["ladder"] = _synth(lad, 0.6, rate, false)

	# Snake: falling slide with a hiss
	sfx["snake"] = _synth([
		_ev(0.0, 0.85, 650.0, 80.0, "saw", 0.22, 1.2),
		_ev(0.0, 0.85, 670.0, 85.0, "saw", 0.15, 1.2),
		_ev(0.0, 0.6, 0.0, 0.0, "noise", 0.07, 1.0)], 0.9, rate, false)

	# Bonus (rolled a six)
	sfx["bonus"] = _synth([
		_ev(0.0, 0.18, _note(81), _note(81), "sine", 0.35),
		_ev(0.09, 0.28, _note(88), _note(88), "sine", 0.35)], 0.45, rate, false)

	# Needs an exact roll
	sfx["blocked"] = _synth([_ev(0.0, 0.22, 210.0, 150.0, "square", 0.22, 1.5)], 0.25, rate, false)

	# Win fanfare
	var win_evs: Array = []
	var wn := [72, 76, 79, 84]
	for i in wn.size():
		win_evs.append(_ev(i * 0.13, 0.28, _note(wn[i]), _note(wn[i]), "tri", 0.35))
	for m in wn:
		win_evs.append(_ev(0.55, 0.95, _note(m), _note(m), "tri", 0.2, 1.5))
		win_evs.append(_ev(0.55, 0.95, _note(m - 12), _note(m - 12), "square", 0.06, 1.5))
	sfx["win"] = _synth(win_evs, 1.6, rate, false)

	# Lose: descending notes
	var lose_evs: Array = []
	var ln := [67, 64, 60, 55]
	for i in ln.size():
		lose_evs.append(_ev(i * 0.28, 0.4, _note(ln[i]), _note(ln[i]), "tri", 0.4, 1.5))
	sfx["lose"] = _synth(lose_evs, 1.5, rate, false)


## A cheerful 16-second loop: bass, plucky arpeggio, soft kick and hats.
func _build_music() -> AudioStreamWAV:
	var rate := 11025
	var beat := 0.5
	var chords := [[48, [60, 64, 67]], [45, [57, 60, 64]], [41, [53, 57, 60]], [43, [55, 59, 62]]]
	var pats := [[0, 1, 2, 1, 2, 1, 0, 1], [2, 1, 0, 1, 2, 2, 1, 0]]
	var evs: Array = []
	for bar in 8:
		var ch: Array = chords[floori(bar / 2.0)]
		var root: int = ch[0]
		var tones: Array = ch[1]
		var pat: Array = pats[bar % 2]
		var t0 := bar * 4.0 * beat
		evs.append(_ev(t0, 0.9, _note(root), _note(root), "tri", 0.3, 1.2))
		evs.append(_ev(t0 + 2.0 * beat, 0.9, _note(root + 7), _note(root + 7), "tri", 0.3, 1.2))
		evs.append(_ev(t0, 0.15, 120.0, 45.0, "sine", 0.35))
		evs.append(_ev(t0 + 2.0 * beat, 0.15, 120.0, 45.0, "sine", 0.35))
		for e in 8:
			var m: int = int(tones[pat[e]]) + 12
			var f := _note(m)
			evs.append(_ev(t0 + e * 0.25, 0.22, f, f, "tri", 0.2))
			if e % 2 == 1:
				evs.append(_ev(t0 + e * 0.25, 0.04, 0.0, 0.0, "noise", 0.06, 3.0))
		if bar % 2 == 0:
			var lead := _note(int(tones[1]) + 24)
			evs.append(_ev(t0, 1.6, lead, lead, "sine", 0.1, 1.0))
	return _synth(evs, 8.0 * 4.0 * beat, rate, true)


func _start_music() -> void:
	music_player.stream = _build_music()
	music_player.play()
	music_player.stream_paused = not music_on


# --------------------------------------------------------------------------
# Per-frame update
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	anim_time += delta
	if rolling:
		dice_timer -= delta
		if dice_timer <= 0.0:
			dice_timer = 0.06
			dice_value = randi_range(1, 6)
			dice_shake = Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
			dice_rot = randf_range(-0.6, 0.6)
	if state != State.MENU:
		_update_offsets(delta)
	for i in range(confetti.size() - 1, -1, -1):
		var c: Conf = confetti[i]
		c.vel.y += 220.0 * delta
		c.pos += c.vel * delta
		c.rot += c.spin * delta
		if c.pos.y > 780.0:
			confetti.remove_at(i)
	queue_redraw()


func _update_offsets(delta: float) -> void:
	for p in n_players:
		var target := Vector2.ZERO
		if pos[p] > 0:
			var group: Array[int] = []
			for q in n_players:
				if pos[q] == pos[p]:
					group.append(q)
			if group.size() > 1:
				var k := group.find(p)
				target = Vector2.from_angle(TAU * k / group.size() + 0.6) * cs * 0.17
		tok_off[p] = tok_off[p].lerp(target, minf(1.0, delta * 10.0))


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _rrect(r: Rect2, col: Color, radius: int, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	_sb.bg_color = col
	_sb.set_corner_radius_all(radius)
	_sb.set_border_width_all(bw)
	_sb.border_color = border
	draw_style_box(_sb, r)


func _text(s: String, center: Vector2, fs: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2(center.x - w.x * 0.5, center.y + fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw() -> void:
	_draw_background()
	_draw_board()
	_draw_jumps()
	if state != State.MENU:
		_draw_tokens()
	_draw_panel()
	if state != State.MENU:
		_draw_dice()
	if state == State.GAME_OVER:
		_draw_banner()
	_draw_confetti()


func _draw_background() -> void:
	var c1: Color = th["bg"]
	var c2: Color = th["bg2"]
	var strips := 24
	for i in strips:
		draw_rect(Rect2(0, i * VIEW.y / strips, VIEW.x, VIEW.y / strips + 1.0), c1.lerp(c2, float(i) / (strips - 1)))
	var dk: String = th["deco"]
	var line_col: Color = th["line"]
	for d in deco:
		var c := Vector2(d.x, d.y)
		match dk:
			"stars":
				var a := 0.35 + 0.65 * absf(sin(anim_time * 1.5 + d.x))
				draw_circle(c, 0.8 + d.z * 1.6, Color(1, 1, 1, a))
			"bubbles":
				var y := fposmod(d.y - anim_time * (14.0 + d.z * 30.0), VIEW.y + 40.0) - 20.0
				draw_arc(Vector2(d.x + sin(anim_time + d.y) * 8.0, y), 4.0 + d.z * 12.0, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.5)
			"leaves":
				var ang := d.x * 0.05 + d.y * 0.03 + sin(anim_time * 0.6 + d.x) * 0.1
				var r := 12.0 + d.z * 22.0
				var pts := PackedVector2Array([
					c + Vector2(0, -r * 1.6).rotated(ang), c + Vector2(r * 0.7, 0).rotated(ang),
					c + Vector2(0, r * 1.6).rotated(ang), c + Vector2(-r * 0.7, 0).rotated(ang)])
				draw_colored_polygon(pts, Color(line_col.r, line_col.g, line_col.b, 0.35))
			"dots":
				draw_circle(c, 6.0 + d.z * 26.0, Color(1, 1, 1, 0.28))


func _star_points(c: Vector2, ro: float, ri: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		var r := ro if i % 2 == 0 else ri
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	return pts


func _draw_board() -> void:
	var panel_col: Color = th["panel"]
	var line_col: Color = th["line"]
	var text_col: Color = th["text"]
	var ca: Color = th["cell_a"]
	var cb: Color = th["cell_b"]
	_rrect(board_rect.grow(10.0), panel_col, 14)
	var fs := int(cs * 0.24)
	for n in range(1, total + 1):
		var g := path[n - 1]
		var r := _cell_rect(n)
		var col: Color = ca if (g.x + g.y) % 2 == 0 else cb
		if n == total:
			col = th["finish"]
		draw_rect(r, col)
		if jump_to.has(n):
			var dest: int = jump_to[n]
			if dest > n:
				draw_rect(r, Color(0.2, 0.9, 0.3, 0.22))
			else:
				draw_rect(r, Color(0.95, 0.2, 0.2, 0.22))
		draw_rect(r, line_col, false, 1.0)
		if n == total:
			draw_colored_polygon(_star_points(r.get_center(), cs * 0.3, cs * 0.13), Color(1.0, 0.6, 0.1, 0.8))
		draw_string(font, r.position + Vector2(4, fs + 2), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_col)
	# Start tray
	var tr := Rect2(board_rect.position.x, board_rect.end.y + 12.0, board_rect.size.x, TRAY_H)
	_rrect(tr, panel_col, 10)
	var ptx: Color = th["panel_text"]
	_text("START", Vector2(tr.end.x - 50.0, tr.get_center().y), 16, ptx)


func _draw_jumps() -> void:
	for k in jump_to.keys():
		var from_c: int = k
		var to_c: int = jump_to[k]
		if to_c > from_c:
			_draw_ladder(from_c, to_c)
	for k in jump_to.keys():
		var from_c: int = k
		var to_c: int = jump_to[k]
		if to_c < from_c:
			_draw_snake(from_c, to_c)


func _draw_ladder(from_c: int, to_c: int) -> void:
	var a := _cell_center(from_c)
	var b := _cell_center(to_c)
	var d := b - a
	var length := d.length()
	var dir := d / length
	var off := dir.orthogonal() * cs * 0.13
	var rail: Color = th["rail"]
	var rung: Color = th["rung"]
	var dark := rail.darkened(0.55)
	var rw := maxf(3.0, cs * 0.07)
	var count := maxi(2, int(length / (cs * 0.3)))
	# outlines
	draw_line(a + off, b + off, dark, rw + 3.0, true)
	draw_line(a - off, b - off, dark, rw + 3.0, true)
	for i in range(1, count):
		var c := a.lerp(b, float(i) / count)
		draw_line(c - off, c + off, dark, rw * 0.8 + 3.0, true)
	# fills
	for i in range(1, count):
		var c := a.lerp(b, float(i) / count)
		draw_line(c - off, c + off, rung, rw * 0.8, true)
	draw_line(a + off, b + off, rail, rw, true)
	draw_line(a - off, b - off, rail, rw, true)


func _draw_snake(from_c: int, to_c: int) -> void:
	var a := _cell_center(from_c)
	var b := _cell_center(to_c)
	var snakes: Array = th["snakes"]
	var pair: Array = snakes[from_c % snakes.size()]
	var body: Color = pair[0]
	var stripe: Color = pair[1]
	var outline := body.darkened(0.6)
	var length := a.distance_to(b)
	var n := clampi(int(length / (cs * 0.11)), 16, 90)
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(_snake_pt(a, b, float(i) / n, from_c))
	for i in n:
		var w := lerpf(cs * 0.30, cs * 0.07, float(i) / n)
		draw_line(pts[i], pts[i + 1], outline, w + 3.0, true)
		draw_circle(pts[i], (w + 3.0) * 0.5, outline)
	for i in n:
		var w := lerpf(cs * 0.30, cs * 0.07, float(i) / n)
		var col := body if floori(i / 4.0) % 2 == 0 else stripe
		draw_line(pts[i], pts[i + 1], col, w, true)
		draw_circle(pts[i], w * 0.5, col)
	# Head
	var hd := (pts[0] - pts[4]).normalized()
	var perp := hd.orthogonal()
	var hc := pts[0] + hd * cs * 0.04
	draw_circle(hc, cs * 0.2 + 2.0, outline)
	draw_circle(hc, cs * 0.2, body)
	for s in [-1.0, 1.0]:
		var e: Vector2 = hc + hd * cs * 0.06 + perp * cs * 0.08 * s
		draw_circle(e, cs * 0.06, Color.WHITE)
		draw_circle(e + hd * cs * 0.015, cs * 0.03, Color.BLACK)
	if fmod(anim_time * 2.0, 1.0) < 0.5:
		var tip := hc + hd * cs * 0.32
		var red := Color(0.9, 0.1, 0.15)
		draw_line(hc + hd * cs * 0.18, tip, red, 2.0, true)
		draw_line(tip, tip + (hd + perp * 0.6).normalized() * cs * 0.07, red, 2.0, true)
		draw_line(tip, tip + (hd - perp * 0.6).normalized() * cs * 0.07, red, 2.0, true)


func _draw_tokens() -> void:
	for p in n_players:
		if p != cur or state != State.PLAYING:
			_draw_token(p)
	if state == State.PLAYING:
		_draw_token(cur)


func _draw_token(p: int) -> void:
	var r := maxf(cs * 0.2, 10.0)
	var ground := tok_pos[p] + tok_off[p]
	var base := ground + Vector2(0, -tok_hop[p])
	draw_circle(ground + Vector2(2, 4), r, Color(0, 0, 0, 0.3))
	draw_circle(base, r + 2.0, Color(1, 1, 1, 0.95))
	draw_circle(base, r, player_colors[p])
	draw_circle(base + Vector2(-r * 0.3, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.45))
	if p == cur and state == State.PLAYING:
		draw_arc(base, r + 5.0 + sin(anim_time * 6.0) * 2.0, 0.0, TAU, 32, Color(1, 1, 0.6, 0.9), 2.5, true)


func _draw_panel() -> void:
	var accent: Color = th["accent"]
	var ptx: Color = th["panel_text"]
	var p2: Color = th["panel2"]
	_rrect(Rect2(PANEL_X, 16, 540, 688), th["panel"], 18, th["line"], 2)
	_text("SNAKES & LADDERS", Vector2(PANEL_CX, 56), 34, accent)
	if state == State.MENU:
		return
	for p in n_players:
		var r := Rect2(740, 100 + p * 60, 500, 52)
		var active := p == cur and state == State.PLAYING
		var bc := accent if active else Color(0, 0, 0, 0)
		_rrect(r, p2, 12, bc, 3 if active else 0)
		draw_circle(Vector2(r.position.x + 28, r.position.y + 22), 14.0, Color(1, 1, 1, 0.95))
		draw_circle(Vector2(r.position.x + 28, r.position.y + 22), 12.0, player_colors[p])
		draw_string(font, Vector2(r.position.x + 56, r.position.y + 29), _pname(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ptx)
		var where := "Start" if pos[p] == 0 else "Square %d" % pos[p]
		draw_string(font, Vector2(r.position.x, r.position.y + 29), where, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18.0, 20, ptx)
		var bar := Rect2(r.position.x + 56, r.position.y + 38, 420, 6)
		draw_rect(bar, Color(0, 0, 0, 0.4))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(pos[p]) / total, bar.size.y)), player_colors[p])
	_text("Space / Enter = roll", Vector2(PANEL_CX, 678), 14, Color(ptx.r, ptx.g, ptx.b, 0.6))


func _draw_dice() -> void:
	var s := DICE_SIZE
	draw_set_transform(DICE_CENTER + dice_shake, dice_rot, Vector2.ONE)
	_rrect(Rect2(-s / 2.0 + 4.0, -s / 2.0 + 6.0, s, s), Color(0, 0, 0, 0.35), 18)
	_rrect(Rect2(-s / 2.0, -s / 2.0, s, s), th["dice"], 18, Color(0, 0, 0, 0.5), 3)
	var pip_col: Color = th["pip"]
	var idx_list: Array = PIPS[dice_value]
	for k in idx_list:
		var i: int = k
		var cx := i % 3
		var cy := floori(i / 3.0)
		draw_circle(Vector2((cx - 1) * s * 0.28, (cy - 1) * s * 0.28), s * 0.085, pip_col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_banner() -> void:
	var c := board_rect.get_center()
	_rrect(Rect2(c - Vector2(220, 70), Vector2(440, 140)), Color(0, 0, 0, 0.78), 20, th["accent"], 4)
	var msg := "YOU WIN!" if winner == 0 else "%s wins!" % _pname(winner)
	_text(msg, c + Vector2(0, -14), 52, th["accent"])
	_text("Press Play Again or open the menu", c + Vector2(0, 38), 18, Color(1, 1, 1, 0.9))


func _draw_confetti() -> void:
	for i in confetti.size():
		var c: Conf = confetti[i]
		draw_set_transform(c.pos, c.rot, Vector2.ONE)
		draw_rect(Rect2(-c.sz * 0.5, -c.sz * 0.3, c.sz, c.sz * 0.6), c.col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
