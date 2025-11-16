package build

import "core:c/libc"
import "core:fmt"
import "core:log"
import "core:os"
import "core:time"
import "core:strings"
import dt "core:time/datetime"

NAME :: "FLOAT"
BUILD_DIR :: "./.build"
IGNORE_PATH :: BUILD_DIR + "/.gitignore"

main :: proc() {
    context.allocator = context.temp_allocator; defer free_all(context.temp_allocator)
    context.logger = log.create_console_logger(.Info, {.Level, .Terminal_Color})
    defer log.destroy_console_logger(context.logger)

    assert(setup_build_dir() == nil)

    OS_SUFFIX :: ".exe" when ODIN_OS == .Windows else ""

    assert(exec("clear"))
    assert(exec("odin run ./src -debug -collection:src=src -o:minimal -out:"+BUILD_DIR+"/"+NAME+".dev"+OS_SUFFIX))
}

setup_build_dir :: proc() -> os.Error {
    switch info, builddir_err := os.stat(BUILD_DIR); builddir_err {
    case .Not_Exist, .ENOENT:
        log.info("Creating directory", "path", BUILD_DIR)
        if make_err := os.make_directory(BUILD_DIR, 0o755); make_err != nil {
            log.errorf("Failed to create directory '%v': %v", BUILD_DIR, make_err)
            return builddir_err
        }
    case nil:
        if !info.is_dir {
            log.errorf("Path '%v' exists but is not a directory.", BUILD_DIR)
            return builddir_err
        }
    case:
        log.errorf("Failed to check directory '%v': %v", BUILD_DIR, builddir_err)
        return builddir_err
    }

    switch _, ignore_err := os.stat(IGNORE_PATH); ignore_err {
    case .Not_Exist, .ENOENT:
        log.info("Creating file", "path", IGNORE_PATH)
        if !os.write_entire_file(IGNORE_PATH, {'*'}) {
            log.errorf("Failed to create and write to '%v'.", IGNORE_PATH)
            return ignore_err
        }
    case nil: // File already exists, do nothing.
    case:
        log.errorf("Failed to check file '%v': %v", IGNORE_PATH, ignore_err)
        return ignore_err
    }

    return nil
}

exec :: proc(command: ..string) -> bool {
    cmd1 := strings.join(command, " "); defer delete(cmd1)
    cstr := strings.clone_to_cstring(cmd1); defer delete(cstr)

    log.infof("Running `%v`", cstr)
    res := libc.system(cstr)

    when ODIN_OS == .Windows {
        switch {
        case res == -1:
            log.errorf("error spawning command %q", command)
            return false
        case res == 0:
            return true
        case:
            log.warnf("command %q exited with non-zero code", command)
            return false
        }
    } else {
        _WSTATUS    :: proc(x: i32) -> i32  { return x & 0177 }
        WIFEXITED   :: proc(x: i32) -> bool { return _WSTATUS(x) == 0 }
        WEXITSTATUS :: proc(x: i32) -> i32  { return (x >> 8) & 0x000000ff }

        switch {
        case res == -1:
            log.errorf("error spawning command %q", command)
            return false
        case WIFEXITED(res) && WEXITSTATUS(res) == 0:
            return true
        case WIFEXITED(res):
            log.warnf("command %q exited with non-zero code %v", command, WEXITSTATUS(res))
            return false
        case:
            log.errorf("command %q caused an unknown error: %v", command, res)
            return false
        }
    }
}
