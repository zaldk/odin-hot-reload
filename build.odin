package build

import "core:c/libc"
import "core:log"
import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:strings"

Command :: [dynamic]string
cmd: Command

NAME :: "FLOAT"
SRC_DIR :: "src/"
BUILD_DIR :: ".build/"
IGNORE_PATH :: BUILD_DIR + "/.gitignore"
when ODIN_OS == .Windows {
    DLL_EXT :: ".dll"
    EXE_EXT :: ".exe"
} else {
    DLL_EXT :: ".so"
    EXE_EXT :: ""
}

main :: proc() {
    context.allocator = context.temp_allocator;
    defer free_all(context.temp_allocator)
    context.logger = log.create_console_logger(.Info, {.Level, .Terminal_Color})
    defer log.destroy_console_logger(context.logger)
    cmd = make([dynamic]string)

    append(&cmd, "clear")
    assert(exec(&cmd))

    assert(setup_build_dir())
    exe_name : string

    if len(os.args) > 1 {
        switch os.args[1] {
        case "release":
            exe_name = "app_release"
            append(&cmd, "odin build "+SRC_DIR+"main_release", "-o:speed")
            append(&cmd, fmt.tprintf("-out:"+BUILD_DIR+"%v"+EXE_EXT, exe_name))
            assert(exec(&cmd))
        case "dev":
            append(&cmd, "echo TODO")
            assert(exec(&cmd))
        case:
            log.errorf("Unsupported build type: %v", os.args[1])
            return
        }
    } else {
        print_usage()
        return
    }

    if len(os.args) > 2 {
        switch os.args[2] {
        case "", "run":
            append(&cmd, fmt.tprintf(BUILD_DIR+"%v", exe_name))
            assert(exec(&cmd))
        case:
            log.errorf("Expected `` or `run`, got: %v", os.args[2])
            return
        }
    }
}

print_usage :: proc() {
    log.infof("Usage:\n    odin run . -- $type [?run]\n        $type in: `release`, `dev`\n        [run] - optional `run` to auto run the exe")
}

setup_build_dir :: proc() -> bool {
    if !os2.exists(BUILD_DIR) {
        log.infof("Creating build directory: %v", BUILD_DIR)
        if err := os2.make_directory(BUILD_DIR, 0o755); err != nil {
            log.errorf("Failed to create %v: %v", BUILD_DIR, err)
            return false
        }
    } else {
        if !os2.is_directory(BUILD_DIR) {
            log.errorf("%v is not a directory.", BUILD_DIR)
            return false
        }
    }

    if !os2.exists(IGNORE_PATH) {
        log.info("Creating .gitignore: %v", IGNORE_PATH)
        if err := os2.write_entire_file_from_string(IGNORE_PATH, "*"); err != nil {
            log.errorf("Failed to create %v: %v", IGNORE_PATH, err)
            return false
        }
    } else {
        if !os2.is_file(IGNORE_PATH) {
            log.errorf("%v is not a regular file.", IGNORE_PATH)
            return false
        }
    }

    return true
}

exec :: proc(command: ^Command) -> bool {
    defer clear(command)
    cmd := strings.join(command[:], " "); defer delete(cmd)
    cstr := strings.clone_to_cstring(cmd); defer delete(cstr)

    log.infof("Executing: %s", cmd)
    res := libc.system(cstr)

    when ODIN_OS == .Windows {
        switch {
        case res == -1:
            log.errorf("error spawning command %q", cmd)
            return false
        case res == 0:
            return true
        case:
            log.warnf("command %q exited with non-zero code", cmd)
            return false
        }
    } else {
        _WSTATUS    :: proc(x: i32) -> i32  { return x & 0177 }
        WIFEXITED   :: proc(x: i32) -> bool { return _WSTATUS(x) == 0 }
        WEXITSTATUS :: proc(x: i32) -> i32  { return (x >> 8) & 0x000000ff }

        switch {
        case res == -1:
            log.errorf("error spawning command %q", cmd)
            return false
        case WIFEXITED(res) && WEXITSTATUS(res) == 0:
            return true
        case WIFEXITED(res):
            log.warnf("command %q exited with non-zero code %v", cmd, WEXITSTATUS(res))
            return false
        case:
            log.errorf("command %q caused an unknown error: %v", cmd, res)
            return false
        }
    }
}
