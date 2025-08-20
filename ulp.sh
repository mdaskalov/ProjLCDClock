#!/bin/bash
cd ulp_riscv
# idf.py fullclean
idf.py set-target esp32s3
idf.py ulp_main.bin.S
python3 ../binS2Berry.py

