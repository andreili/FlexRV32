#include <inttypes.h>
#include "sim.h"
#include "xprintf.h"

#define read_csr(reg) ({ unsigned long __tmp; \
  asm volatile ("csrr %0, " #reg : "=r"(__tmp)); \
  __tmp; })

#define write_csr(reg, val) ({ \
  asm volatile ("csrw " #reg ", %0" :: "rK"(val)); })

#define swap_csr(reg, val) ({ unsigned long __tmp; \
  asm volatile ("csrrw %0, " #reg ", %1" : "=r"(__tmp) : "rK"(val)); \
  __tmp; })

#define set_csr(reg, bit) ({ unsigned long __tmp; \
  asm volatile ("csrrs %0, " #reg ", %1" : "=r"(__tmp) : "rK"(bit)); \
  __tmp; })

#define clear_csr(reg, bit) ({ unsigned long __tmp; \
  asm volatile ("csrrc %0, " #reg ", %1" : "=r"(__tmp) : "rK"(bit)); \
  __tmp; })

int main(void)
{
    uint32_t cycle_start = read_csr(cycle);
    uint32_t time_start = read_csr(time);
    uint32_t instret_start = read_csr(instret);
    static const char* p_str = "Hello RISC-V core!\n";
    sim_send_str(p_str);
    uint32_t cycle_end = read_csr(cycle);
    uint32_t time_end = read_csr(time);
    uint32_t instret_end = read_csr(instret);
    xprintf("Cycles: %d->%d\n", cycle_start, cycle_end);
    xprintf("Time: %d->%d\n", time_start, time_end);
    xprintf("Instret: %d->%d\n", instret_start, instret_end);
    sim_exit(EXIT_OK);
    while (1);
    return 0;
}
