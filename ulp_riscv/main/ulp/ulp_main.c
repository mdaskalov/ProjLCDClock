/*
 * SPDX-FileCopyrightText: 2021-2023 Espressif Systems (Shanghai) CO LTD
 *
 * SPDX-License-Identifier: Unlicense OR CC0-1.0
 */
/* ULP-RISC-V example

   This example code is in the Public Domain (or CC0 licensed, at your option.)

   Unless required by applicable law or agreed to in writing, this
   software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
   CONDITIONS OF ANY KIND, either express or implied.

   This code runs on ULP-RISC-V  coprocessor
*/

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include "ulp_riscv.h"
#include "ulp_riscv_utils.h"
#include "ulp_riscv_gpio.h"

#define DATA_GPIO GPIO_NUM_1
#define CLOCK_GPIO GPIO_NUM_2

int32_t data = 0; // also RTC_SLOW_MEM[140]
int32_t bits = 0; // also RTC_SLOW_MEM[141]

static void write_dword(uint32_t data, uint32_t bits)
{
    ulp_riscv_gpio_output_level(DATA_GPIO, 0);
    ulp_riscv_gpio_output_level(CLOCK_GPIO, 1);
    ulp_riscv_delay_cycles(498 * ULP_RISCV_CYCLES_PER_US); // 488.375us
    ulp_riscv_gpio_output_level(DATA_GPIO, 1);
    ulp_riscv_gpio_output_level(CLOCK_GPIO, 0);
    ulp_riscv_delay_cycles(1007 * ULP_RISCV_CYCLES_PER_US); // 976.75us
    ulp_riscv_gpio_output_level(CLOCK_GPIO, 1);
    ulp_riscv_delay_cycles(501 * ULP_RISCV_CYCLES_PER_US); // 488.375us
    ulp_riscv_gpio_output_level(CLOCK_GPIO, 0);

    for (int i = bits - 1; i >= 0; i--)
    {
        ulp_riscv_gpio_output_level(DATA_GPIO, (data >> i) & 0x1);
        ulp_riscv_gpio_output_level(CLOCK_GPIO, 0);
        ulp_riscv_delay_cycles(494 * ULP_RISCV_CYCLES_PER_US); // 488.375us
        ulp_riscv_gpio_output_level(CLOCK_GPIO, 1);
        ulp_riscv_delay_cycles(502 * ULP_RISCV_CYCLES_PER_US); // 488.375us
        ulp_riscv_gpio_output_level(CLOCK_GPIO, 0);
    }

    ulp_riscv_gpio_output_level(DATA_GPIO, 0);
    ulp_riscv_gpio_output_level(CLOCK_GPIO, 0);
}

int main(void)
{
    if (data == 0)
        return 0;

    /* Setup data GPIO */
    ulp_riscv_gpio_init(DATA_GPIO);
    ulp_riscv_gpio_input_enable(DATA_GPIO);
    ulp_riscv_gpio_output_enable(DATA_GPIO);
    ulp_riscv_gpio_set_output_mode(DATA_GPIO, RTCIO_MODE_OUTPUT_OD);
    ulp_riscv_gpio_pullup(DATA_GPIO);
    ulp_riscv_gpio_pulldown_disable(DATA_GPIO);
    /* Setup clock GPIO */
    ulp_riscv_gpio_init(CLOCK_GPIO);
    ulp_riscv_gpio_input_enable(CLOCK_GPIO);
    ulp_riscv_gpio_output_enable(CLOCK_GPIO);
    ulp_riscv_gpio_set_output_mode(CLOCK_GPIO, RTCIO_MODE_OUTPUT_OD);
    ulp_riscv_gpio_pullup(CLOCK_GPIO);
    ulp_riscv_gpio_pulldown_disable(CLOCK_GPIO);

    if (bits != 0)
    {
        write_dword(data, bits);
        bits = 0;
    }

    data = 0;

    // ULP.set_mem(140,0x5012E00C)
    // ULP.set_mem(141,32)

    return 0;
}
