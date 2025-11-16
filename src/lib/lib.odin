package library

import rl "vendor:raylib"

@export draw_background :: proc() {
    rl.ClearBackground({100,0,0,255})
}
