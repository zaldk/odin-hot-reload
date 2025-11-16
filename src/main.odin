package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:dynlib"
import rl "vendor:raylib"
import "../build"
import api "common"

when ODIN_OS == .Windows {
    DLL_EXT :: ".dll"
} else when ODIN_OS == .Darwin {
    DLL_EXT :: ".dylib"
} else {
    DLL_EXT :: ".so"
}

Symbols :: struct {
    get_background: proc() -> rl.Color,
    __handle: dynlib.Library,
}

main :: proc() { RUNME() }
RUNME :: proc() {
    ctx: api.API
    ctx.dll_path = "./.build/lib"+DLL_EXT

    lib: Symbols
    compile_lib()
    _, ok := dynlib.initialize_symbols(&lib, ctx.dll_path)
    assert(ok)
    defer dynlib.unload_library(lib.__handle)

    rl.InitWindow(800, 600, "FLOAT")
    defer rl.CloseWindow()

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(lib.get_background())
        rl.DrawText(strings.unsafe_string_to_cstring(fmt.tprintf("%v",ctx.last_dll_change_time)), 0,0, 60, rl.WHITE)
        rl.EndDrawing()

        if last_dll_change_time, err := os.last_write_time_by_name("./src/lib/lib.odin"); last_dll_change_time > ctx.last_dll_change_time {
            ctx.last_dll_change_time = last_dll_change_time
            compile_lib()
            _, ok := dynlib.initialize_symbols(&lib, ctx.dll_path)
            assert(ok)
        }
    }
}

compile_lib :: proc() {
    assert(build.exec("odin build ./src/lib -debug -out:./.build/lib"+DLL_EXT+" -build-mode:shared"))
}
