#pragma once

#include <inttypes.h>
#include "mem_map.h"

#define READ_REG32(addr) (*((volatile uint32_t*)addr))
#define WRITE_REG32(addr, data) (*((volatile uint32_t*)addr) = data)

#define SOC_CORE_SPEED (75*1000*1000)
