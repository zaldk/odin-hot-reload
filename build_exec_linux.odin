package build

import "core:strings"
import "core:log"
import "core:c"
import "core:sys/posix"

exec_linux :: proc(command: ^Command, silent := false, async := false) -> bool {
    if len(command) == 0 {
        log.errorf("Empty command")
        return false
    }
    defer clear(command)

    cmd_cstr := make([]cstring, len(command)+1)
    defer delete(cmd_cstr)
    defer for i in 0..<len(cmd_cstr) {
        delete(cmd_cstr[i])
    }
    for c, i in command {
        cmd_cstr[i] = strings.clone_to_cstring(c)
    }
    cmd_cstr[len(cmd_cstr)-1] = nil

    if !silent do log.infof("Executing: %q", cmd)

    pid := posix.fork()
    if pid == -1 {
        log.errorf("Could not fork: {}", posix.strerror(posix.errno()))
        return false
    } else if pid == 0 {
        // child:
        ret := posix.execvp(cmd_cstr[0], raw_data(cmd_cstr))
        log.errorf("Could not execute: ret={}, err={}", ret, posix.strerror(posix.errno()))
        return false
    } else {
        // parent:
        if !async {
            status: c.int
            posix.waitpid(pid, &status, {})
        }
        return true
    }

    log.errorf("Unreachable")
    return false
}
