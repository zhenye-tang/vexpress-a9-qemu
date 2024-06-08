#!/bin/bash
qemu-system-arm \
    -M vexpress-a9 \
    -m 512M \
    -kernel images/u-boot \
    -sd images/sd_card.img \
    -nographic \
    -serial mon:stdio \
