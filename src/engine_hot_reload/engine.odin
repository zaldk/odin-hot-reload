package engine_hot_reload

import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"
import "core:time"
import build "../.."
import os "core:os/os2"

APP_DLL_DIR :: build.BUILD_DIR+"dlls/"
APP_DLL_PATH :: APP_DLL_DIR + build.DLL_NAME + build.DLL_EXT

AppAPI :: struct {
    lib: dynlib.Library,

    open: proc(),
    init: proc(),
    update: proc(),
    should_run: proc() -> bool,
    shutdown: proc(),
    close: proc(),

    memory: proc() -> rawptr,
    memory_size: proc() -> int,

    hot_reloaded: proc(mem: rawptr),
    force_reload: proc() -> bool,
    force_restart: proc() -> bool,

    version: int,
}

AppModificationData :: struct {
    time_table: map[string]time.Time,
    has_updated: bool,
}

init_modification_data :: proc(md: ^AppModificationData) {
    md.time_table = make(map[string]time.Time)
}
free_modification_data :: proc(md: ^AppModificationData) {
    delete(md.time_table)
}
gather_modification_data :: proc(md: ^AppModificationData) {
    // {{{
    md.has_updated = false

    w := os.walker_create_path(build.SRC_DIR) // the src/ directory
    defer os.walker_destroy(&w)

    for fi in os.walker_walk(&w) {
        if path, err := os.walker_error(&w); err != nil {
            log.errorf("Failed walking {}: {}", path, err)
            continue
        }
        if fi.type == .Directory && strings.has_prefix(fi.name, "engine_") {
            os.walker_skip_dir(&w)
            continue
        }
        lmd, err := os.modification_time_by_path(fi.fullpath)
        if err != nil {
            log.errorf("Failed to get modification time of {}: {}", fi.fullpath, err)
            continue
        }
        if cached_lmd, ok := md.time_table[fi.fullpath]; !ok || cached_lmd != lmd {
            md.time_table[fmt.aprint(fi.fullpath)] = lmd
            if cached_lmd != {} {
                md.has_updated = true
                return
            }
        }
    }
    // }}}
}

get_app_dll_name :: proc(api_version: int) -> string {
    return fmt.tprintf("{}{}_{}{}", APP_DLL_DIR, build.DLL_NAME, api_version, build.DLL_EXT)
}

// We copy the DLL because using it directly would lock it, which would prevent the compiler from writing to it.
copy_dll :: proc(to: string) -> bool {
    copy_err := os.copy_file(to, APP_DLL_PATH)
    if copy_err != nil {
        log.errorf("Failed to copy {} to {}: {}", APP_DLL_PATH, to, copy_err)
        return false
    }
    return true
}

load_app_api :: proc(api_version: int) -> (api: AppAPI, ok: bool) {
    // {{{
    mod_time, mod_time_error := os.modification_time_by_path(APP_DLL_PATH)
    if mod_time_error != nil {
        log.errorf(
            "Failed getting last write time of {}, error code: {}",
            APP_DLL_PATH, mod_time_error,
        )
        return
    }

    app_dll_name := get_app_dll_name(api_version)
    copy_dll(app_dll_name) or_return

    // This proc matches the names of the fields in App_API to sols in the
    // game DLL. It actually looks for symbols starting with `app_`, which is
    // why the argument `"app_"` is there.
    _, ok = dynlib.initialize_symbols(&api, app_dll_name, "app_", "lib")
    if !ok {
        log.errorf("Failed initializing symbols: {}", dynlib.last_error())
    }

    api.version = api_version
    ok = true

    return
    // }}}
}

unload_app_api :: proc(api: ^AppAPI) {
    if api.lib != nil {
        if !dynlib.unload_library(api.lib) {
            log.errorf("Failed unloading lib: {}", dynlib.last_error())
        }
    }

    app_dll_name := get_app_dll_name(api.version)
    if os.remove(app_dll_name) != nil {
        log.errorf("Failed to remove {}", app_dll_name)
    }
}

main :: proc() {
    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    context.logger = log.create_console_logger(opt={.Level, .Time, .Short_File_Path, .Line, .Terminal_Color})

    reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
        for _, value in a.allocation_map {
            log.errorf("{}: Leaked {} bytes\n", value.location, value.size)
        }
        for value in a.bad_free_array {
            fmt.printf("[{}] {} double free detected\n", value.memory, value.location)
        }
        mem.tracking_allocator_clear(a)
        return len(a.allocation_map) > 0 || len(a.bad_free_array) > 0
    }

    md: AppModificationData
    init_modification_data(&md)
    defer free_modification_data(&md)

    app_api_version := 0
    app_api, app_api_ok := load_app_api(app_api_version)
    if !app_api_ok {
        log.errorf("Failed to load App API")
        return
    }

    app_api_version += 1
    app_api.open()
    app_api.init()

    old_app_apis := make([dynamic]AppAPI)

    for app_api.should_run() {
        defer free_all(context.temp_allocator)

        app_api.update()
        force_reload := app_api.force_reload()
        force_restart := app_api.force_restart()

        gather_modification_data(&md)
        if !(force_reload || force_restart || md.has_updated) {
            continue
        }
        md.has_updated = false

        build.compile_dll(#file, #line)
        new_app_api, new_app_api_ok := load_app_api(app_api_version)

        if !new_app_api_ok {
            log.error("Could not load new app api")
            continue
        }
        force_restart = force_restart || app_api.memory_size() != new_app_api.memory_size()

        if force_restart {
            // This does a full reset. That's basically like opening and
            // closing the game, without having to restart the executable.
            // You end up in here if the game requests a full reset OR
            // if the size of the game memory has changed. That would
            // probably lead to a crash anyways.

            app_api.shutdown()
            reset_tracking_allocator(&tracking_allocator)

            for &g in old_app_apis {
                unload_app_api(&g)
            }

            clear(&old_app_apis)
            unload_app_api(&app_api)

            app_api = new_app_api
            app_api.init()
        } else {
            // This does the normal hot reload.
            // Note that we don't unload the old game APIs because that
            // would unload the DLL. The DLL can contain stored info
            // such as string literals. The old DLLs are only unloaded
            // on a full reset or on shutdown.
            append(&old_app_apis, app_api)
            app_memory := app_api.memory()
            app_api = new_app_api
            app_api.hot_reloaded(app_memory)
        }

        app_api_version += 1
    }

    app_api.shutdown()

    for &g in old_app_apis {
        unload_app_api(&g)
    }

    delete(old_app_apis)

    app_api.close()
    unload_app_api(&app_api)
    mem.tracking_allocator_destroy(&tracking_allocator)
    free_all(context.temp_allocator)
}

// Make game use good GPU on laptops.

@(export)
NvOptimusEnablement: u32 = 1

@(export)
AmdPowerXpressRequestHighPerformance: i32 = 1
