#!/bin/sh
blink_led_blue() {
    gpio 1 1
    gpio 2 1
    gpio 3 1
    gpio l 11 2 2 1 0 4000
}

blink_led_red() {
    gpio 1 1
    gpio 2 1
    gpio 3 1
    gpio l 44 2 2 1 0 4000
}
