#!/bin/bash

echo "                                                                      "
echo "                                                                      "
echo "                                %@@                                   "
echo "                                @@   (@@@@@@@@@@@@@@@@@@              "
echo "                               @ @@@@@@@@@@@@@@@@@@@@@@@@@@           "
echo "                            @@@@@@@@@@@@@@@@@@@@@@@@@@@               "
echo "                          @@ @@      &@@@@@@@@@@#                     "
echo "                        @@   .@                                       "
echo "                       @/     @#                                      "
echo "                      @,       @                                      "
echo "                     @@         @/                                    "
echo "                     @           @@                                   "
echo "                     @             @@@@@&                             "
echo "                    @@@@#      @@@@@@@@@@@@@@                         "
echo "               &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                       "
echo "             *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                       "
echo "             @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(                      "
echo "             @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                       "
echo "             @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&                        "
echo "              &@@@@@@@@@@@@@@@   @@@@@@@@@@                           "
echo "                 @@@@@@@@@@                                           "
echo "                                                                      "
echo "                        elcereza.com                                  "
echo "               Gustavo Cereza  &  Adail Silva                         "
echo "                                                                      "

sudo apt -y update &&
sudo apt-get -y update &&

sudo mkdir -p /elcereza/LoRaWAN &&
sudo chown pi:pi /elcereza/LoRaWAN &&

REPOS=(
    "https://github.com/elcereza/pkt_fwd_raspbian"
    "https://github.com/kersing/lora_gateway.git"
    "https://github.com/kersing/paho.mqtt.embedded-c.git"
    "https://github.com/kersing/ttn-gateway-connector.git"
    "https://github.com/kersing/protobuf-c.git"
    "https://github.com/kersing/packet_forwarder.git"
    "https://github.com/google/protobuf.git"
)

for repo in "${REPOS[@]}"; do
    git clone "$repo" /elcereza/LoRaWAN/ || { echo "Erro ao clonar $repo"; exit 1; }
done

sudo apt -y install protobuf-compiler libprotobuf-dev libprotoc-dev &&
sudo apt-get -y install automake libtool autoconf &&
sudo apt -y install libftdi1 libftdi-dev swig python-dev libusb-1.0-0 libusb-1.0-0-dev &&

cd /elcereza/LoRaWAN/packet_forwarder/mp_pkt_fwd/ &&
sudo cp /elcereza/LoRaWAN/pkt_fwd_raspbian/build-pi.sh ./ &&
sudo chmod +x build-pi.sh &&
sudo ./build-pi.sh || { echo "Erro durante a compilação do packet forwarder"; exit 1; }

sudo cp /elcereza/LoRaWAN/pkt_fwd_raspbian/{global_conf.json,start.sh} /elcereza/LoRaWAN/ &&
sudo chmod +x /elcereza/LoRaWAN/start.sh &&
sudo chown pi:pi /elcereza/LoRaWAN/{start.sh,mp_pkt_fwd,global_conf.json} &&

sudo cp /elcereza/LoRaWAN/pkt_fwd_raspbian/elcereza.service /lib/systemd/system/ &&
sudo chmod +x /lib/systemd/system/elcereza.service &&
sudo chown pi:pi /lib/systemd/system/elcereza.service &&

sudo systemctl daemon-reload &&
sudo systemctl enable elcereza.service &&
sudo systemctl start elcereza.service &&
sudo systemctl status elcereza.service
