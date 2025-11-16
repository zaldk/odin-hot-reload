package library

import rl "vendor:raylib"

@export get_background :: proc() -> rl.Color {
    return { 100, 10, 20, 255 }
}
