# Generate IP
#
# Arguments:
#   path to project qpf
#   project revision
#   path to json that stores info about IPs
#     if it's empty, ip generation will be skipped

set qpf [lindex ${argv} 0]
set rev [lindex ${argv} 1]
set ip_json [lindex ${argv} 2]

if {[file exist ${qpf}] == 0} {
    error "\nERROR: QPF file \"${qpf}\" not found\n"
}

set project_dir [file dirname ${qpf}]
set scripts_dir [file dirname [info script]]

source ${scripts_dir}/util.tcl
source ${scripts_dir}/json.tcl

set quartus_dir [get_quartus_dir]

set sopc_dir "${quartus_dir}/sopc_builder/bin"
set qsys_gen "${sopc_dir}/qsys-generate"
set qmegawiz "${quartus_dir}/bin/qmegawiz"

project_open -force ${qpf} -revision ${rev}

set family [get_global_assignment -name FAMILY]
set device [get_global_assignment -name DEVICE]

project_close

if {[file exist ${ip_json}]} {
    set ip_json_file [open ${ip_json} "r"]
    set ip_json_buf [read ${ip_json_file}]
    close ${ip_json_file}
    
    if {[json::validate ${ip_json_buf}]} {
        set ip_dict [json::json2dict ${ip_json_buf}]
        foreach ip [dict keys ${ip_dict}] {
            puts "\nINFO: Generate ${ip}"
            
            if {[dict exists ${ip_dict} ${ip} "type"]} {
                set type [dict get ${ip_dict} ${ip} "type"]
                
                if {[string match ${type} "qsys"]} {
                    
                    if {[dict exists ${ip_dict} ${ip} "file"] && [dict exists ${ip_dict} ${ip} "output_directory"]} {
                        set qsys_file [file join ${project_dir} [dict get ${ip_dict} ${ip} "file"]]
                        set output_directory [file join ${project_dir} [dict get ${ip_dict} ${ip} "output_directory"]]
                        
                        if {[file exist ${qsys_file}]} {
                            # don't handle qsys-generate error cause command always returns error (even in success)
                            if {[string length ${family}] > 0 && [string length ${device}] > 0} {
                                catch {exec ${qsys_gen} ${qsys_file} --synthesis=VERILOG --output-directory=${output_directory} --family=${family} --part=${device}} result
                            } else {
                                catch {exec ${qsys_gen} ${qsys_file} --synthesis=VERILOG --output-directory=${output_directory}} result
                            }
                        } else {
                            error "\nERROR: File \"${qsys_file}\" not found\n"
                        }
                    } else {
                        error "\nERROR: IP ${ip} doesn't have necessary parameters (\"file\" or \"output_directory\") in JSON\n"
                    }
                    
                } elseif {[string match ${type} "hdl"]} {
                
                    if {[dict exists ${ip_dict} ${ip} "file"]} {
                        set hdl_file [file join ${project_dir} [dict get ${ip_dict} ${ip} "file"]]
                        
                        if {[file exist ${hdl_file}]} {
                            set status [exec ${qmegawiz} -silent OPTIONAL_FILES=NONE ${hdl_file}]
                        } else {
                            error "\nERROR: File \"${hdl_file}\" not found\n"
                        }
                    } else {
                        error "\nERROR: IP ${ip} doesn't have parameter \"file\" in JSON\n"
                    }
                
                } else {
                    error "\nERROR: IP ${ip} has unknown type in JSON\n"
                }   
                
            } else {
                error "\nERROR: IP ${ip} doesn't have parameter \"type\" in JSON\n"
            }                
        }
    } else {
        error "\nERROR: JSON file ${ip_json} is corrupted\n"
    }
} else {
    puts "\nWARNING: JSON file \"${ip_json}\" not found, nothing to generate"
}

return 0
