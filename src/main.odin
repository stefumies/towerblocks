package main

import rl "vendor:raylib"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 1000
BG_COLOR :: rl.Color{210, 200, 190, 255}

Block :: struct {
	position: rl.Vector3,
	size:     rl.Vector3,
	color:    rl.Color,
}

Game :: struct {
	placed_blocks: [dynamic]Block,
}

default_block: Block = {{0, 0, 0}, {10, 2, 10}, rl.Color{150, 150, 150, 255}}

InitGame :: proc(game: ^Game) {
	block: Block = default_block
	append_elem(&game.placed_blocks, block)
}

DrawBlock :: proc(block: Block) {
	rl.DrawCube(block.position, block.size.x, block.size.y, block.size.z, block.color)
	rl.DrawCubeWires(block.position, block.size.x, block.size.y, block.size.z, rl.BLACK)
}

DrawPlacedBlocks :: proc(game: ^Game) {
	for b in game.placed_blocks {
		DrawBlock(b)
	}
}

UpdateGameState :: proc(game: ^Game) {
	input_pressed := rl.IsKeyPressed(.SPACE) || rl.IsMouseButtonPressed(.LEFT)
	if input_pressed {
		block: Block = default_block
		i := len(game.placed_blocks)
		block.position.y = f32(i) * 2
		block.color.r += u8(i) * 5
		block.color.g += u8(i) * 5
		block.color.b += u8(i) * 5
		append_elem(&game.placed_blocks, block)
	}
}

UpdateCameraPosition :: proc(game: Game, camera: ^rl.Camera3D) {
    blocks_len := f32(2 * len(game.placed_blocks))
    camera.position.y = 50.0 + blocks_len
    camera.target.y =  blocks_len
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tower - Blocks")

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
		UpdateGameState(&game)
		UpdateCameraPosition(game, &camera)

		rl.BeginDrawing()
		rl.ClearBackground(BG_COLOR)
		rl.BeginMode3D(camera)
		DrawPlacedBlocks(&game)
		rl.EndMode3D()
		rl.EndDrawing()
	}

	rl.CloseWindow()
}

