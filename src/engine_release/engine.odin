package engine_release

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:mem"
import app ".."

_ :: mem

USE_TRACKING_ALLOCATOR :: #config(USE_TRACKING_ALLOCATOR, false)

main :: proc() {
    defer free_all(context.temp_allocator)
    // Set working dir to dir of executable.
    exe_path := os.args[0]
    exe_dir := filepath.dir(exe_path, context.temp_allocator)
    os.set_current_directory(exe_dir)

    when USE_TRACKING_ALLOCATOR {
        tracking_allocator: mem.Tracking_Allocator
        mem.tracking_allocator_init(&tracking_allocator, context.allocator)
        context.allocator = mem.tracking_allocator(&tracking_allocator)
    }

    mode: int = 0
    when ODIN_OS == .Linux {
        mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
    }
    logfile, logfile_err := os.open("log.txt", (os.O_CREATE | os.O_TRUNC | os.O_RDWR), mode)

    if logfile_err == os.ERROR_NONE {
        os.stdout = logfile
        os.stderr = logfile
    }

    logger_alloc := context.allocator
    logger := logfile_err == os.ERROR_NONE ? log.create_file_logger(logfile) : log.create_console_logger()
    context.logger = logger

    app.app_open()
    app.app_init()
    for app.app_should_run() { app.app_update() }
    app.app_shutdown()
    app.app_close()

    when USE_TRACKING_ALLOCATOR {
        for _, value in tracking_allocator.allocation_map {
            log.errorf("{}: Leaked {} bytes\n", value.location, value.size)
        }
        for value in tracking_allocator.bad_free_array {
            fmt.printf("[{}] {} double free detected\n", value.memory, value.location)
        }
        mem.tracking_allocator_destroy(&tracking_allocator)
    }

    if logfile_err == os.ERROR_NONE {
        log.destroy_file_logger(logger, logger_alloc)
    }
}

// make app use good GPU on laptops etc
@(export) NvOptimusEnablement: u32 = 1
@(export) AmdPowerXpressRequestHighPerformance: i32 = 1
