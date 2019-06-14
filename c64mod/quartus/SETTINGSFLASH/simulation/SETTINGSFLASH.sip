set_global_assignment -entity "SETTINGSFLASH" -library "lib_SETTINGSFLASH" -name IP_TOOL_NAME "Qsys"
set_global_assignment -entity "SETTINGSFLASH" -library "lib_SETTINGSFLASH" -name IP_TOOL_VERSION "18.1"
set_global_assignment -entity "SETTINGSFLASH" -library "lib_SETTINGSFLASH" -name IP_TOOL_ENV "Qsys"
set_global_assignment -library "lib_SETTINGSFLASH" -name SPD_FILE [file join $::quartus(sip_path) "../SETTINGSFLASH.spd"]
set_global_assignment -library "lib_SETTINGSFLASH" -name MISC_FILE [file join $::quartus(sip_path) "../../SETTINGSFLASH.qsys"]

set_global_assignment -library "lib_SETTINGSFLASH" -name MISC_FILE [file join $::quartus(sip_path) "SETTINGSFLASH.vhd"]
set_global_assignment -library "lib_SETTINGSFLASH" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_onchip_flash_util.v"]
set_global_assignment -library "lib_SETTINGSFLASH" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_onchip_flash.v"]
set_global_assignment -library "lib_SETTINGSFLASH" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_onchip_flash_avmm_data_controller.v"]
set_global_assignment -library "lib_SETTINGSFLASH" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_onchip_flash_avmm_csr_controller.v"]
