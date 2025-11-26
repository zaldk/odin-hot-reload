package app

main :: proc() {}

import "core:fmt"
import rl "vendor:raylib"

M: ^AppMemory
AppMemory :: struct {
    some_number: int,
    run: bool,
}

update :: proc() {
    M.some_number += 1
    if rl.IsKeyPressed(.ESCAPE) {
        M.run = false
    }
}

draw :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground({20,20,20,255})
    rl.DrawFPS(0,0)
    rl.DrawText(fmt.ctprintf("some_number: {}\nAND TEXT", M.some_number), 80, 120, 60, {200,200,200,255})
    rl.EndDrawing()
}

@(export) app_open :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(800, 600, "FLOAT")
    rl.SetTargetFPS(min(60, rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())))
    rl.SetExitKey(nil)
}

@(export) app_init :: proc() {
    M = new(AppMemory)
    M.run = true
    M.some_number = 100
    app_hot_reloaded(M)
}

@(export) app_update :: proc() {
    update()
    draw()
    free_all(context.temp_allocator)
}

@(export) app_should_run    :: proc() -> bool    { return !rl.WindowShouldClose() && M.run }
@(export) app_shutdown      :: proc()            { free(M)                                 }
@(export) app_close         :: proc()            { rl.CloseWindow()                        }

@(export) app_memory        :: proc() -> rawptr  { return M                                }
@(export) app_memory_size   :: proc() -> int     { return size_of(AppMemory)               }

@(export) app_hot_reloaded  :: proc(mem: rawptr) { M = (^AppMemory)(mem)                   }
@(export) app_force_reload  :: proc() -> bool    { return rl.IsKeyPressed(.F5)             }
@(export) app_force_restart :: proc() -> bool    { return rl.IsKeyPressed(.F6)             }
