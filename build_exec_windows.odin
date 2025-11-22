package build

import "core:strings"
import "core:log"
import "core:c/libc"

exec_windows :: proc(command: ^Command, silent := false) -> bool {
    defer clear(command)
    cmd := strings.join(command[:], " "); defer delete(cmd)
    cstr := strings.clone_to_cstring(cmd); defer delete(cstr)

    if !silent do log.infof("Executing: %s", cmd)
    res := libc.system(cstr)

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
}
