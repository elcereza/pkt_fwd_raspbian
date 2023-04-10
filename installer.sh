apt update 
apt-get update

git clone https://github.com/kersing/lora_gateway.git
git clone https://github.com/kersing/paho.mqtt.embedded-c.git
git clone https://github.com/kersing/ttn-gateway-connector.git
git clone https://github.com/kersing/protobuf-c.git
git clone https://github.com/kersing/packet_forwarder.git
git clone https://github.com/google/protobuf.git

apt install protobuf-compiler
apt install libprotobuf-dev
apt install libprotoc-dev

apt-get install automake
apt install libtool
apt install autoconf

apt install libftdi1
apt install libftdi-dev
apt install swig
apt install python-dev
apt search libusb
apt install libusb-1.0-0
apt install libusb-1.0-0-dev

cd packet_forwarder/
cd mp_pkt_fwd/
rm -rf build-pi.sh
cp /home/pi/pkt_fwd_raspbian/build-pi.sh ./
chmod +x ./build-pi.sh
./build-pi.sh

cd /opt/elcereza
cp /home/pi/pkt_fwd_raspbian/global_conf.json ./
cp /home/pi/pkt_fwd_raspbian/start.sh ./
chmod +x start.sh

cd /lib/systemd/systemd
cp /home/pi/pkt_fwd_raspbian/elcereza.service ./
chmod +x elcereza.service

systemctl daemon-reload
systemctl enable elcereza.service
systemctl start elcereza.service
systemctl status elcereza.service

cd 
rm -rf lora_gateway
rm -rf packet_forwarder
rm -rf paho.mqtt.embedded-c
rm -rf protobuf
rm -rf protobuf-c
rm -rf ttn-gateway-connector

exit 0
