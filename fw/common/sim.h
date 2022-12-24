#pragma once

#include <inttypes.h>

#define CNT_ADDR 0x20000000
#define COMM_ADDR 0xf0000000
#define EXIT_CODE 0xfffffff0
#define EXIT_OK 0
#define EXIT_FAIL 1

#define READ_REG32(addr) (*((volatile uint32_t*)addr))
#define WRITE_REG32(addr, data) (*((volatile uint32_t*)addr) = data)

void sim_exit(uint32_t code);
void sim_send_str(const char* const str);
