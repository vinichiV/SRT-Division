# ================================
# Clean & create work library
# ================================
if {[file exists work]} {
    vdel -all
}
vlib work

# ================================
# Compile
# ================================
vlog srt_radix4.v tb_radix4_srt_divider.v

# ================================
# Simulate
# ================================
vsim -voptargs=+acc work.tb_radix4_srt_divider

# ================================
# Waveform
# ================================
add wave -r *

# ================================
# Run
# ================================
run -all
