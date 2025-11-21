// package main
//
// import "core:fmt"
// import "core:os"
// import "core:strings"
// import "core:dynlib"
// import rl "vendor:raylib"
// import "../build"
// import api "common"
//
// when ODIN_OS == .Windows {
//     DLL_EXT :: ".dll"
// } else when ODIN_OS == .Darwin {
//     DLL_EXT :: ".dylib"
// } else {
//     DLL_EXT :: ".so"
// }
//
// Symbols :: struct {
//     get_background: proc() -> rl.Color,
//     __handle: dynlib.Library,
// }
//
// main :: proc() { RUNME() }
// RUNME :: proc() {
//     ctx: api.API
//     ctx.dll_path = "./.build/lib"+DLL_EXT
//
//     lib: Symbols
//     compile_lib()
//     _, ok := dynlib.initialize_symbols(&lib, ctx.dll_path)
//     assert(ok)
//     defer dynlib.unload_library(lib.__handle)
//
//     rl.InitWindow(800, 600, "FLOAT")
//     defer rl.CloseWindow()
//
//     for !rl.WindowShouldClose() {
//         rl.BeginDrawing()
//         rl.ClearBackground(lib.get_background())
//         rl.DrawText(strings.unsafe_string_to_cstring(fmt.tprintf("%v",ctx.last_dll_change_time)), 0,0, 60, rl.WHITE)
//         rl.EndDrawing()
//
//         if last_dll_change_time, err := os.last_write_time_by_name("./src/lib/lib.odin"); last_dll_change_time > ctx.last_dll_change_time {
//             ctx.last_dll_change_time = last_dll_change_time
//             compile_lib()
//             _, ok := dynlib.initialize_symbols(&lib, ctx.dll_path)
//             assert(ok)
//         }
//     }
// }
//
// compile_lib :: proc() {
//     assert(build.exec("odin build ./src/lib -debug -out:./.build/lib"+DLL_EXT+" -build-mode:shared"))
// }

package app

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
    rl.DrawText(fmt.ctprintf("some_number: %v", M.some_number), 80, 60, 60, {200,200,200,255})
    rl.EndDrawing()
}

@(export) app_open :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(800, 600, "FLOAT")
    rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
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
