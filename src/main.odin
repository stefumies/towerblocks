package main

import "core:fmt"
import m "core:math"
import rl "vendor:raylib"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 1000
BG_COLOR :: rl.Color{210, 200, 190, 255}
BLOCK_MOVE_THRESHOLD :: 12
SCORE_ANIMATION_DURATION :: 0.2
SCORE_ANIMATION_SCALE :: 1.5
OVERLAY_ANIMATION_OFFSET_Y :: -50
OVERLAY_AIMATION_FADE_SPEED :: 2.5
CAMERA_SPEED :: 0.1

BlockDirection :: enum {
	FORWARD,
	BACKWARD,
}

BlockAxis :: enum {
	X_AXIS,
	Z_AXIS,
}

BlockMovement :: struct {
	speed:     f32,
	direction: BlockDirection,
	axis:      BlockAxis,
}

Block :: struct {
	index:        i32,
	position:     rl.Vector3,
	size:         rl.Vector3,
	color:        rl.Color,
	color_offset: i32,
	movement:     BlockMovement,
}

GameState :: enum {
	GAME_READY_STATE,
	GAME_PLAYING_STATE,
	GAME_OVER_STATE,
	GAME_RESET_STATE,
}

GameScoreAnimation :: struct {
	scale:    f32,
	duration: f32,
}

GameOverlayFadeState :: enum {
	FADE_IN,
	FADE_OUT,
	NO_FADE,
}

GameOverlayType :: enum {
	OVERLAY_GAME_START,
	OVERLAY_GAME_OVER,
}

GameOverlayAnimation :: struct {
	overlay_type:       GameOverlayType,
	overlay_fade_state: GameOverlayFadeState,
	alpha:              f32,
	offset_y:           f32,
}

GameAnimations :: struct {
	score:   GameScoreAnimation,
	overlay: GameOverlayAnimation,
}


Game :: struct {
	state:          GameState,
	placed_blocks:  [dynamic]Block,
	previous_block: ^Block,
	current_block:  Block,
	animations:     GameAnimations,
}

default_block: Block = {
	0,
	{0, 0, 0},
	{10, 2, 10},
	rl.Color{100, 100, 100, 255},
	rl.GetRandomValue(0, 100),
	{0, .FORWARD, .X_AXIS},
}

InitGame :: proc(game: ^Game) {
	game.state = .GAME_READY_STATE
	block: Block = default_block
	game.current_block = default_block
	game.animations = {
		score = {duration = 0, scale = 1},
		overlay = {
			overlay_type = GameOverlayType.OVERLAY_GAME_START,
			overlay_fade_state = GameOverlayFadeState.FADE_IN,
			alpha = 0,
			offset_y = OVERLAY_ANIMATION_OFFSET_Y,
		},
	}
	append_elem(&game.placed_blocks, block)
	game.previous_block = &game.placed_blocks[0]
}

DrawBlock :: proc(block: Block) {
	rl.DrawCube(block.position, block.size.x, block.size.y, block.size.z, block.color)
	rl.DrawCubeWires(block.position, block.size.x, block.size.y, block.size.z, rl.BLACK)
}

DrawPlacedBlocks :: proc(game: Game) {
	for b in game.placed_blocks {
		DrawBlock(b)
	}
}

DrawCurrentBlock :: proc(game: Game) {
	if game.state != GameState.GAME_PLAYING_STATE {
		return
	}
	DrawBlock(game.current_block)
}

CalculateBlockColor :: proc(offset: i32, phase: f32) -> u8 {
	return u8(m.sin_f32(0.3 * f32(offset) + phase) * 55 + 200)
}

CreateMovingBlock :: proc(game: Game) -> Block {
	target: ^Block = game.previous_block
	block_axis := target.movement.axis == BlockAxis.X_AXIS ? BlockAxis.Z_AXIS : BlockAxis.X_AXIS
	block_direction :=
		rl.GetRandomValue(0, 1) == 0 ? BlockDirection.FORWARD : BlockDirection.BACKWARD
	block_position := target.position
	block_position.y += target.size.y

	if block_axis == BlockAxis.X_AXIS {
		block_position.x =
			(block_direction == BlockDirection.FORWARD ? -1 : 1) * BLOCK_MOVE_THRESHOLD
	} else {
		block_position.z =
			(block_direction == BlockDirection.FORWARD ? -1 : 1) * BLOCK_MOVE_THRESHOLD
	}
	block_index := target.index + 1
	block_speed := 12 + f32(block_index) * 0.5
	color_offset := target.color_offset + block_index
	block_color_r := CalculateBlockColor(color_offset, 0)
	block_color_g := CalculateBlockColor(color_offset, 2)
	block_color_b := CalculateBlockColor(color_offset, 4)
	return {
		block_index,
		block_position,
		target.size,
		rl.Color{u8(block_color_r), u8(block_color_g), u8(block_color_b), 255},
		target.color_offset,
		BlockMovement{block_speed, block_direction, block_axis},
	}
}

PlaceCurrentBlock :: proc(game: ^Game) -> bool {

	current := game.current_block
	target := game.previous_block
	is_x_axis := current.movement.axis == BlockAxis.X_AXIS

	current_position := is_x_axis ? current.position.x : current.position.z
	target_position := is_x_axis ? target.position.x : target.position.z

	current_size := is_x_axis ? current.size.x : current.size.z
	target_size := is_x_axis ? target.size.x : target.size.z

	delta := current_position - target_position
	overlap := target_size - m.abs(delta)
	is_perfect_overlap := m.abs(delta) < 0.3

	if overlap < 0.1 {
		return false
	}

	if is_perfect_overlap {
		if is_x_axis {
			current.size.x = target.size.x
			current.position.x = target.position.x
		} else {
			current.size.z = target.size.z
			current.position.z = target.position.z
		}
	} else {
		if is_x_axis {
			current.size.x = overlap
			current.position.x = target_position + delta / 2
		} else {
			current.size.z = overlap
			current.position.z = target_position + delta / 2
		}
	}

	append(&game.placed_blocks, current)
	new_len := len(game.placed_blocks)
	game.previous_block = &game.placed_blocks[new_len - 1]
	game.animations.score.duration = SCORE_ANIMATION_DURATION
	game.animations.score.scale = SCORE_ANIMATION_SCALE

	return true
}

ResetGame :: proc(game: ^Game) {
	// TODO FALLING BLOCKS RESET
	game.state = .GAME_PLAYING_STATE
	game.current_block = default_block
	game.current_block.color_offset = rl.GetRandomValue(0, 100)
	game.previous_block = &game.placed_blocks[0]
}

UpdateGameState :: proc(game: ^Game) {
	input_pressed := rl.IsKeyPressed(.SPACE) || rl.IsMouseButtonPressed(.LEFT)

	switch game.state {
	case .GAME_READY_STATE:
		if input_pressed {
			game.state = .GAME_PLAYING_STATE
			game.current_block = CreateMovingBlock(game^)
			game.animations.overlay.overlay_fade_state = .FADE_OUT
		}
	case .GAME_PLAYING_STATE:
		if input_pressed {
			success := PlaceCurrentBlock(game)
			if success {
				game.current_block = CreateMovingBlock(game^)
			} else {
				game.state = .GAME_OVER_STATE
				game.animations.overlay.overlay_type = .OVERLAY_GAME_OVER
				game.animations.overlay.overlay_fade_state = .FADE_IN
			}
		}
	case .GAME_OVER_STATE:
		if input_pressed {
			game.placed_blocks = {}
			InitGame(game)
			game.state = .GAME_PLAYING_STATE
			game.current_block = CreateMovingBlock(game^)
			game.animations.overlay.overlay_type = .OVERLAY_GAME_OVER
			game.animations.overlay.overlay_fade_state = .FADE_OUT
			game.animations.overlay.alpha = 1
			game.animations.overlay.offset_y = 0
		}
	case .GAME_RESET_STATE:
		if len(game.placed_blocks) == 1 {
			// Reset Game
			// game.current_block = CreateMovingBlock(game^)
		}
	}

}

UpdateCameraPosition :: proc(game: Game, camera: ^rl.Camera3D) {
	blocks_len := len(game.placed_blocks)
	camera.position.y = rl.Lerp(camera.position.y, f32(50 + 2 * blocks_len), CAMERA_SPEED)
	camera.target.y = rl.Lerp(camera.target.y, f32(2 * blocks_len), CAMERA_SPEED)
}

UpdateCurrentBlock :: proc(game: ^Game, dt: f32) {
	if game.state != GameState.GAME_PLAYING_STATE {
		return
	}
	c_block: ^Block = &game.current_block
	direction := c_block.movement.direction == BlockDirection.FORWARD ? 1 : -1
	axis_pos: ^f32 =
		c_block.movement.axis == BlockAxis.X_AXIS ? &c_block.position.x : &c_block.position.z
	axis_pos^ += f32(direction) * c_block.movement.speed * dt
	if m.abs(axis_pos^) >= BLOCK_MOVE_THRESHOLD {
		c_block.movement.direction =
			c_block.movement.direction == BlockDirection.FORWARD ? BlockDirection.BACKWARD : BlockDirection.FORWARD
		axis_pos^ = clamp(axis_pos^, BLOCK_MOVE_THRESHOLD, axis_pos^)
	}
}

UpdateScore :: proc(game: ^Game, dt: f32) {
	animation := &game.animations.score
	if animation.duration > 0 {
		animation.duration -= dt
		t := 1 - animation.duration / SCORE_ANIMATION_DURATION
		animation.scale = rl.Lerp(SCORE_ANIMATION_SCALE, 1.0, t)
		if animation.duration <= 0 {
			animation.duration = 0
			animation.scale = 1
		}
	}
}

UpdateOverlay :: proc(game: ^Game, dt: f32) {
	animation := &game.animations.overlay
	if animation.overlay_fade_state == .FADE_IN {
		animation.alpha += dt * OVERLAY_AIMATION_FADE_SPEED
		animation.offset_y = rl.Lerp(OVERLAY_ANIMATION_OFFSET_Y, 0, animation.alpha)
		if animation.alpha >= 1 {
			animation.alpha = 1
			animation.offset_y = 0
			animation.overlay_fade_state = .NO_FADE
		}
	} else if animation.overlay_fade_state == .FADE_OUT {
		animation.alpha -= dt * OVERLAY_AIMATION_FADE_SPEED
		animation.offset_y = rl.Lerp(OVERLAY_ANIMATION_OFFSET_Y, 0, animation.alpha)
		if animation.alpha <= 0 {
			animation.alpha = 0
			animation.offset_y = OVERLAY_ANIMATION_OFFSET_Y
			animation.overlay_fade_state = .NO_FADE
		}
	}
}

Update :: proc(game: ^Game, camera: ^rl.Camera3D, dt: f32) {
	UpdateGameState(game)
	UpdateCameraPosition(game^, camera)
	UpdateCurrentBlock(game, dt)
	UpdateScore(game, dt)
	UpdateOverlay(game, dt)
}

Draw3D :: proc(game: Game) {
	DrawPlacedBlocks(game)
	DrawCurrentBlock(game)
}

DrawOverlay :: proc(
	game: Game,
	title: cstring,
	subtitle: cstring,
	title_size: i32,
	subtitle_size: i32,
	title_y: i32,
	subtitle_y: i32,
) {
	dark_color := rl.Fade(rl.DARKGRAY, game.animations.overlay.alpha)
	light_color := rl.Fade(rl.GRAY, game.animations.overlay.alpha)
	screen_width := rl.GetScreenWidth()
	title_width := rl.MeasureText(title, title_size)
	subtitle_width := rl.MeasureText(subtitle, subtitle_size)
	rl.DrawText(
		title,
		(screen_width - title_width) / 2,
		title_y + i32(game.animations.overlay.offset_y),
		title_size,
		dark_color,
	)
	rl.DrawText(
		subtitle,
		(screen_width - subtitle_width) / 2,
		subtitle_y + i32(game.animations.overlay.offset_y),
		subtitle_size,
		light_color,
	)
}

DrawGameStartOverlay :: proc(game: Game) {
	if game.animations.overlay.overlay_type != .OVERLAY_GAME_START {
		return
	}
	DrawOverlay(game, "START GAME", "Click or Press <space> to start", 60, 30, 100, 170)
}

DrawGameOverOverlay :: proc(game: Game) {
	if game.animations.overlay.overlay_type != .OVERLAY_GAME_OVER {
		return
	}
	DrawOverlay(game, "GAME OVER", "Click or Press <space> to play again", 60, 30, 100, 170)
}

DrawGameScoreOverlay :: proc(game: Game) {
	if game.state == GameState.GAME_READY_STATE {
		return
	}
	font_size_f := 120.0 * game.animations.score.scale
	font_size := i32(font_size_f)
	score := len(game.placed_blocks) - 1
	title := fmt.ctprintf("%z", score)
	text_size := rl.MeasureText(title, font_size)
	position := (WINDOW_WIDTH - text_size) / 2
	rl.DrawText(title, position, 220, font_size, rl.DARKGRAY)
}

Draw :: proc(game: Game) {
	DrawGameStartOverlay(game)
	DrawGameScoreOverlay(game)
	DrawGameOverOverlay(game)
	rl.DrawFPS(10, 10)
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tower - Blocks")
	rl.SetTargetFPS(60)

	camera: rl.Camera3D = {
		rl.Vector3{50, 50, 50},
		rl.Vector3{0, 0, 0},
		rl.Vector3{0, 1, 0},
		60.0,
		.ORTHOGRAPHIC,
	}

	game := Game{}
	InitGame(&game)

	for (!rl.WindowShouldClose()) {
		dt := rl.GetFrameTime()
		Update(&game, &camera, dt)
		rl.BeginDrawing()
		rl.ClearBackground(BG_COLOR)
		rl.BeginMode3D(camera)
		Draw3D(game)
		rl.EndMode3D()
		Draw(game)
		rl.EndDrawing()
	}

	rl.CloseWindow()
}

