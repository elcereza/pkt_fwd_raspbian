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

# Atualização do sistema
sudo apt -y update &&
sudo apt-get -y update &&

# Criando diretório de destino
sudo mkdir -p /elcereza/LoRaWAN &&
sudo chown pi:pi /elcereza/LoRaWAN &&

# Clonando repositórios necessários diretamente para /elcereza/LoRaWAN
REPOS=(
    "https://github.com/elcereza/pkt_fwd_raspbian"
    "https://github.com/kersing/lora_gateway.git"
    "https://github.com/kersing/paho.mqtt.embedded-c.git"
    "https://github.com/kersing/ttn-gateway-connector.git"
    "https://github.com/kersing/protobuf-c.git"
    "https://github.com/google/protobuf.git"
)

for repo in "${REPOS[@]}"; do
    git clone "$repo" /elcereza/LoRaWAN/ || { echo "Erro ao clonar $repo"; exit 1; }
done

# Clonando packet_forwarder e movendo o conteúdo diretamente para /elcereza/LoRaWAN
git clone https://github.com/kersing/packet_forwarder.git &&
sudo mv /pkt_fwd_raspbian/* /elcereza/LoRaWAN/ &&
sudo rm -rf /pkt_fwd_raspbian &&

# Instalação de dependências
sudo apt -y install protobuf-compiler libprotobuf-dev libprotoc-dev &&
sudo apt-get -y install automake libtool autoconf &&
sudo apt -y install libftdi1 libftdi-dev swig python-dev libusb-1.0-0 libusb-1.0-0-dev &&

# Compilação do packet forwarder (agora em /elcereza/LoRaWAN)
cd /elcereza/LoRaWAN/ &&
sudo cp /elcereza/LoRaWAN/build-pi.sh ./ &&
sudo chmod +x build-pi.sh &&
sudo ./build-pi.sh || { echo "Erro durante a compilação do packet forwarder"; exit 1; }

# Configuração dos arquivos para o elcereza
sudo cp /elcereza/LoRaWAN/{global_conf.json,start.sh} /elcereza/LoRaWAN/ &&
sudo chmod +x /elcereza/LoRaWAN/start.sh &&
sudo chown pi:pi /elcereza/LoRaWAN/{start.sh,mp_pkt_fwd,global_conf.json} &&

# Certifique-se de que o arquivo `mp_pkt_fwd` (executável) tenha permissões corretas
sudo chmod +x /elcereza/LoRaWAN/mp_pkt_fwd &&
sudo chown pi:pi /elcereza/LoRaWAN/mp_pkt_fwd &&

# Configuração do serviço systemd
sudo cp /elcereza/LoRaWAN/elcereza.service /lib/systemd/system/ &&
sudo chmod +x /lib/systemd/system/elcereza.service &&
sudo chown pi:pi /lib/systemd/system/elcereza.service &&

# Copiar o serviço para o diretório LoRaWAN
sudo cp /elcereza/LoRaWAN/elcereza.service /elcereza/LoRaWAN/ &&
sudo chown pi:pi /elcereza/LoRaWAN/elcereza.service &&

# Habilitar e iniciar o serviço
sudo systemctl daemon-reload &&
sudo systemctl enable elcereza.service &&
sudo systemctl start elcereza.service &&
sudo systemctl status elcereza.service
