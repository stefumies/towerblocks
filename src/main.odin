package main

import "core:fmt"
import m "core:math"
import rl "vendor:raylib"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 1000
BG_COLOR :: rl.Color{210, 200, 190, 255}
BLOCK_MOVE_THRESHOLD :: 12
SCORE_ANIMATION_DURATION :: 0.5
SCORE_ANIMATION_SCALE :: 1.5

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
	GAME_READY,
	GAME_PLAYING,
	GAME_OVER,
}

GameScoreAnimation :: struct {
	scale:    f32,
	duration: f32,
}

GameAnimations :: struct {
	score: GameScoreAnimation,
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
	rl.Color{},
	rl.GetRandomValue(0, 100),
	{0, .FORWARD, .X_AXIS},
}

InitGame :: proc(game: ^Game) {
	game.state = .GAME_READY
	block: Block = default_block
	block.color = rl.Color {
		CalculateBlockColor(block.color_offset, 0),
		CalculateBlockColor(block.color_offset, 2),
		CalculateBlockColor(block.color_offset, 4),
		255,
	}
	game.current_block = default_block
	game.animations = {
		score = {duration = 0, scale = 1},
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
	if game.state != GameState.GAME_PLAYING {
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
    game.animations.score.duration =  SCORE_ANIMATION_DURATION
    game.animations.score.scale = SCORE_ANIMATION_SCALE

	return true
}

UpdateGameState :: proc(game: ^Game) {
	input_pressed := rl.IsKeyPressed(.SPACE) || rl.IsMouseButtonPressed(.LEFT)

	switch game.state {
	case .GAME_READY:
		if input_pressed {
			game.state = .GAME_PLAYING
			game.current_block = CreateMovingBlock(game^)
		}
	case .GAME_PLAYING:
		if input_pressed {
			if PlaceCurrentBlock(game) {
				game.current_block = CreateMovingBlock(game^)
			} else {
				game.state = GameState.GAME_OVER
			}
		}
	case .GAME_OVER:
		if input_pressed {
			game.placed_blocks = {}
			InitGame(game)
			game.state = .GAME_PLAYING
			game.current_block = CreateMovingBlock(game^)
		}
	}
}

UpdateCameraPosition :: proc(game: Game, camera: ^rl.Camera3D) {
	blocks_len := f32(2 * len(game.placed_blocks))
	camera.position.y = 50.0 + blocks_len
	camera.target.y = blocks_len
}

UpdateCurrentBlock :: proc(game: ^Game, dt: f32) {
	if game.state != GameState.GAME_PLAYING {
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
        t :=  1 - animation.duration / SCORE_ANIMATION_DURATION
        animation.scale = rl.Lerp(SCORE_ANIMATION_SCALE, 1.0, t)
        if animation.duration <= 0 {
            animation.duration = 0
            animation.scale = 1
        }
    }
}

Update :: proc(game: ^Game, camera: ^rl.Camera3D, dt: f32) {
	UpdateGameState(game)
	UpdateCameraPosition(game^, camera)
	UpdateCurrentBlock(game, dt)
    UpdateScore(game, dt)
}

Draw3D :: proc(game: Game) {
	DrawPlacedBlocks(game)
	DrawCurrentBlock(game)
}

DrawOverlay :: proc(game: Game, title: cstring, pos_y: i32, fnts: i32, gstate: GameState) {
	if game.state != gstate {
		return
	}
	font_size := fnts
	screen_width := rl.GetScreenWidth()
	text_size := rl.MeasureText(title, font_size)
	pos_x := i32(screen_width - text_size) / 2
	rl.DrawText(title, pos_x, pos_y, font_size, rl.DARKGRAY)
}

DrawGameStartOverlay :: proc(game: Game) {
	DrawOverlay(game, "START GAME", 50, 60, GameState.GAME_READY)
}

DrawGameScore :: proc(game: Game) {
    font_size := 120 * game.animations.score.scale
	score := len(game.placed_blocks) - 1
	title := fmt.ctprintf("%z", score)
	DrawOverlay(game, title, 200, i32(font_size), GameState.GAME_PLAYING)
}

DrawGameOverOverlay :: proc(game: Game) {
	DrawOverlay(game, "GAME OVER", 50, 60, GameState.GAME_OVER)
}

Draw :: proc(game: Game) {
	DrawGameStartOverlay(game)
	DrawGameScore(game)
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

