#!/usr/bin/env bash

IOT_SK_SX1301_RESET_PIN=7

echo "Accessing concentrator reset pin through GPIO$IOT_SK_SX1301_RESET_PIN..."

WAIT_GPIO() {
    sleep 0.1
}

iot_sk_init() {
    # setup GPIO 7
    echo "$IOT_SK_SX1301_RESET_PIN" > /sys/class/gpio/export; WAIT_GPIO

    # set GPIO 7 as output
    echo "out" > /sys/class/gpio/gpio$IOT_SK_SX1301_RESET_PIN/direction; WAIT_GPIO

    # write output for SX1301 reset
    echo "1" > /sys/class/gpio/gpio$IOT_SK_SX1301_RESET_PIN/value; WAIT_GPIO
    echo "0" > /sys/class/gpio/gpio$IOT_SK_SX1301_RESET_PIN/value; WAIT_GPIO

    # set GPIO 7 as input
    echo "in" > /sys/class/gpio/gpio$IOT_SK_SX1301_RESET_PIN/direction; WAIT_GPIO
}

iot_sk_term() {
    # cleanup GPIO 7
    if [ -d /sys/class/gpio/gpio$IOT_SK_SX1301_RESET_PIN ]
    then
        echo "$IOT_SK_SX1301_RESET_PIN" > /sys/class/gpio/unexport; WAIT_GPIO
    fi
}

iot_sk_term
iot_sk_init
sleep 3
#rm -f /var/run/packet_forwarder/packet_forwarder.pid
#touch /var/run/packet_forwarder/packet_forwarder.pid
#echo $! > /var/run/packet_forwarder/packet_forwarder.pid
#PIDFILE=/var/run/packet_forwarder/packet_forwarder.pid
#PATHEXEC=/opt/LoRa/packet_forwarder/lora_pkt_fwd
#NAMEEXEC=lora_pkt_fwd
#start-stop-daemon --start -m --pidfile $PIDFILE  --chdir $PATHEXEC --exec $PATHEXEC/lora_pkt_fwd
cd /opt/elcereza
./mp_pkt_fwd
