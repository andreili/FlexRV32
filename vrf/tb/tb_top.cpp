#include <memory>
#include "tb.h"

double sc_time_stamp() { return 0; }

#define TICK_TIME 2
#define TICK_PERIOD (TICK_TIME / 2)
#define SIM_TIME_MAX (1000*10)
#define SIM_TIME_MAX_TICK (TICK_TIME * SIM_TIME_MAX)

uint32_t prev_marker;
bool initialized;

int on_step_cb(uint64_t time, TOP_CLASS* p_top)
{
    if ((time % TICK_PERIOD) == 0)
    {
        if (((p_top->o_debug & 0x1) == 1) && initialized)
        {
            printf("Finished. Undefined instruction\n");
            return -1;
        }
        if ((p_top->o_wb_addr == 0xf0000000) && (p_top->o_wb_we == 1) && (p_top->i_clk))
        {
            uint32_t data = p_top->o_wb_wdata;
            uint32_t marker = data >> 8;
            uint32_t ch = data & 0xff;
            if (marker != prev_marker)
            {
                if ((ch & 0xf0) == 0xf0)
                {
                    // exit code
                    switch (ch)
                    {
                    case 0xf0:
                        printf("Finished. Ok.\n");
                        return 1;
                    case 0xf1:
                        printf("Finished. Failed.\n");
                        return -1;
                    }
                }
                else
                {
                    printf("%c", ch);
                }
                prev_marker = marker;
            }
        }

        p_top->i_clk = !p_top->i_clk;
    }
    return 0;
}

int main(int argc, char** argv, char** env)
{
    TB* tb = new TB(TOP_NAME_STR, argc, argv);
    tb->init(on_step_cb);
    TOP_CLASS* top = tb->get_top();
    prev_marker = 0x5a5a;
    initialized = false;

    const char* cycles_str = tb->get_context()->commandArgsPlusMatch("cycles");
    uint32_t cycles = (uint32_t)-1;
    if (strlen(cycles_str) > 8)
    {
        cycles_str += 8;
        cycles = atoi(cycles_str);
    }

    // wait for reset
    top->i_reset_n = 0;
    tb->run_steps(20 * TICK_TIME);
    top->i_reset_n = 1;
    initialized = true;

    int ret = -1;
    for (int i=0 ; i<cycles ; ++i)
    {
        ret = tb->run_steps(TICK_TIME);
        if (ret != 0)
        {
            break;
        }
    }
    if (cycles != (uint32_t)-1)
    {
        ret = 0;
    }

    if (ret == 1)
    {
        ret = 0;
    }

    tb->finish();
    top->final();
#if VM_COVERAGE
    //tb->get_context()->coveragep()->write(COV_FN);
#endif
    return ret;
}
