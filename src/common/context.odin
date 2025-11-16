package api

import "core:os"

API :: struct {
    dll_path: string,
    last_dll_change_time: os.File_Time,
}
