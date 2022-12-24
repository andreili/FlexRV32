#include "sim.h"
#include <string.h>

uint32_t cnt;

int _times()
{
    return READ_REG32(CNT_ADDR);
}

void sim_send_ch(char ch)
{
    uint32_t data = (cnt << 8) | ch;
    WRITE_REG32(COMM_ADDR, data);
    ++cnt;
}

void sim_exit(uint32_t code)
{
    WRITE_REG32(COMM_ADDR, (EXIT_CODE | code));
}

void xfunc_out(unsigned char ch)
{
    sim_send_ch(ch);
}

void sim_send_str(const char* const str)
{
    uint32_t len = strlen(str);
    for (uint32_t i=0 ; i<len ; ++i)
    {
        sim_send_ch(str[i]);
    }
}
