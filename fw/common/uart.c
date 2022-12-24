#include "uart.h"
#include "core.h"

#define UART_BAUD_RATE (115200)

typedef union
{
    struct
    {
        uint32_t tx_full : 1;
        uint32_t rx_full : 1;
        uint32_t tx_overrun : 1;
        uint32_t rx_overrun : 1;
        uint32_t : 28;
    } bt;
    uint32_t dw;
} uart_state_reg_t;

typedef union
{
    struct
    {
        uint32_t tx_enable : 1;
        uint32_t rx_enable : 1;
        uint32_t tx_int_enable : 1;
        uint32_t rx_int_enable : 1;
        uint32_t tx_overrun_int_enable : 1;
        uint32_t rx_overrun_int_enable : 1;
        uint32_t hs_test_mode : 1;
        uint32_t : 25;
    } bt;
    uint32_t dw;
} uart_ctrl_reg_t;

typedef union
{
    struct
    {
        uint32_t tx : 1;
        uint32_t rx : 1;
        uint32_t tx_overrun : 1;
        uint32_t rx_overrun : 1;
        uint32_t : 28;
    } bt;
    uint32_t dw;
} uart_intr_reg_t;

typedef union
{
    struct
    {
        uint32_t value : 20;
        uint32_t : 12;
    } bt;
    uint32_t dw;
} uart_div_reg_t;

typedef struct
{
    uint32_t dr;
    uart_state_reg_t state;
    uart_ctrl_reg_t ctrl;
    uart_intr_reg_t intr;
    uart_div_reg_t div;
} uart_reg_t;

static const uart_reg_t* p_uart = (uart_reg_t*)SOC_UART_REG_ADDR;

void uart_init(void)
{
    uart_ctrl_reg_t ctrl = { .bt.rx_enable=1, .bt.tx_enable=1 };
    WRITE_REG32(&p_uart->ctrl, ctrl.dw);
    uint32_t div = ((SOC_CORE_SPEED / UART_BAUD_RATE) - 1);
    WRITE_REG32(&p_uart->div, div);
}

void uart_send_ch(char ch)
{
    uart_state_reg_t state;
    do
    {
        state.dw = READ_REG32(&p_uart->state);
    } while (state.bt.tx_full);
    WRITE_REG32(&p_uart->dr, ch);
}

void uart_send_str(const char* const str, uint32_t len)
{
    for (uint32_t i=0 ; i<len ; ++i)
    {
        uart_state_reg_t state;
        do
        {
            state.dw = READ_REG32(&p_uart->state);
        } while (state.bt.tx_full);
        WRITE_REG32(&p_uart->dr, str[i]);
    }
}

char uart_getch(void)
{
    uart_state_reg_t state;
    state.dw = READ_REG32(&p_uart->state);
    if (state.bt.rx_full == 0)
        return '\0';
    else
        return READ_REG32(&p_uart->dr) & 0xff;
}

void uart_irq(void)
{
    //WRITE_REG32(SOC_UART_STATE_REG_ADDR, 1);
}
