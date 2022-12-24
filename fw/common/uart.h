#pragma once

#include <inttypes.h>

void uart_init(void);
void uart_send_ch(char ch);
void uart_send_str(const char* const str, uint32_t len);
char uart_getch(void);
void uart_irq(void);
