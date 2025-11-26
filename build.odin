package build

import "core:c/libc"
import "core:log"
import os "core:os/os2"
import "core:fmt"
import "core:strings"

Command :: [dynamic]string
cmd: Command

SRC_DIR     :: "src/"
BUILD_DIR   :: ".build/"
IGNORE_PATH :: BUILD_DIR + ".gitignore"
EXE_NAME    :: "app"
DLL_NAME    :: "app_dll"

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
    context.logger = log.create_console_logger(opt={.Level, .Time, .Short_File_Path, .Line, .Terminal_Color})
    defer log.destroy_console_logger(context.logger)
    cmd = make([dynamic]string)

    when ODIN_OS == .Windows {
        append(&cmd, "cls")
    } else {
        append(&cmd, "clear")
    }
    assert(exec(&cmd))

    assert(setup_build_dir())
    exe_suffix: string
    if len(os.args) > 1 {
        switch os.args[1] {
        case "release":
            exe_suffix = "_release"
            append(&cmd, "odin", "build", SRC_DIR+"engine_release", "-o:speed", "-show-timings")
            append(&cmd, fmt.tprintf("-out:{}{}{}{}", BUILD_DIR, EXE_NAME, exe_suffix, EXE_EXT))
            assert(exec(&cmd))
        case "dev":
            compile_dll(#file, #line, false)

            exe_suffix = "_dev"
            append(&cmd, "odin", "build", SRC_DIR+"engine_hot_reload", "-debug")
            append(&cmd, fmt.tprintf("-out:{}{}{}{}", BUILD_DIR, EXE_NAME, exe_suffix, EXE_EXT))
            assert(exec(&cmd))
        case:
            log.errorf("Unsupported build type: {}", os.args[1])
            print_usage()
            return
        }
    } else {
        print_usage()
        return
    }

    if len(os.args) > 2 {
        switch os.args[2] {
        case "-r":
            append(&cmd, fmt.tprintf("start /B /WAIT {}{}{}{}", BUILD_DIR, EXE_NAME, exe_suffix, EXE_EXT))
            assert(exec(&cmd))
        case:
            log.errorf("Unexpected option: {}", os.args[2])
            print_usage()
            return
        }
    }
}

print_usage :: proc() {
    fmt.printf(
`Usage: odin run . -- [TYPE] [OPTIONS]
Arguments:
    [TYPE]      the type of executable: [required] (release/dev)
Options:
    -r          run the executable upon build. [optional]`)
}

compile_dll :: proc(file: string, line: int, silent := true) {
    log.debugf("called compile_dll from {}:{}", file, line)

    append(&cmd, "odin", "build", SRC_DIR, "-debug")
    append(&cmd, "-define:RAYLIB_SHARED=true", "-build-mode:dll")
    when ODIN_OS == .Linux {
        append(&cmd, "-extra-linker-flags:'-Wl,-rpath="+ODIN_ROOT+"vendor/raylib/linux'")
    } else {
        rl_dst_path :: BUILD_DIR+"raylib.dll"
        if !os.exists(rl_dst_path) {
            rl_src_path :: ODIN_ROOT+"vendor/raylib/windows/raylib.dll"
            if os.exists(rl_src_path) {
                os.copy_file(rl_dst_path, rl_src_path)
            } else {
                log.errorf("Could not find odin's raylib.dll, please copy raylib.dll into the {} folder.", BUILD_DIR)
            }
        }
    }
    append(&cmd, "-out:"+BUILD_DIR+DLL_NAME+DLL_EXT)
    when ODIN_OS == .Windows {
        append(&cmd, ">", "NUL", "2>&1")
    }
    assert(exec(&cmd, silent))
}

setup_build_dir :: proc() -> bool {
    if !os.exists(BUILD_DIR) {
        log.infof("Creating build directory: {}", BUILD_DIR)
        if err := os.make_directory(BUILD_DIR, 0o755); err != nil {
            log.errorf("Failed to create {}: {}", BUILD_DIR, err)
            return false
        }
    } else {
        if !os.is_directory(BUILD_DIR) {
            log.errorf("{} is not a directory.", BUILD_DIR)
            return false
        }
    }

    if !os.exists(IGNORE_PATH) {
        log.info("Creating .gitignore: {}", IGNORE_PATH)
        if err := os.write_entire_file_from_string(IGNORE_PATH, "*"); err != nil {
            log.errorf("Failed to create {}: {}", IGNORE_PATH, err)
            return false
        }
    } else {
        if !os.is_file(IGNORE_PATH) {
            log.errorf("{} is not a regular file.", IGNORE_PATH)
            return false
        }
    }

    return true
}

exec :: proc(command: ^Command, silent := false) -> bool {
    defer clear(command)
    cmd := strings.join(command[:], " "); defer delete(cmd)
    cstr := strings.clone_to_cstring(cmd); defer delete(cstr)

    if !silent do log.debugf("Executing: %s", cmd)
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
