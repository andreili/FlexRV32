# Useful procs

#
# Get quartus location
#
proc get_quartus_dir {} {
    set path [info nameofexecutable]
    set path [file dirname ${path}]
    set path [file dirname ${path}]
    return ${path}
}

#
# Get sopc kit nios 2 location
#
proc get_sopc_kit_nios2_dir {} {
    set path [info nameofexecutable]
    set path [file dirname ${path}]
    set path [file dirname ${path}]
    set path [file dirname ${path}]
    return [file join ${path} "nios2eds"]
}
