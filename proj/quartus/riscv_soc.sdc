create_clock -period 50MHz -name {clk} [get_ports {i_clk}]
derive_pll_clocks
