# Instalação do Gateway LoRaWAN da Radioenge no Raspbian

Se você ainda não possui o Gateway LoRaWAN da Radioenge, pode adquirir o modelo desejado pelos links abaixo:

- **Gateway LoRaWAN da Radioenge (COM GPS)**: [Adquirir no Mercado Livre](https://mercadolivre.com/sec/2bjyVGK)
- **Gateway LoRaWAN da Radioenge (SEM GPS)**: [Adquirir no Mercado Livre](https://mercadolivre.com/sec/1qDmBH6)

Se você não está familiarizado com o Gateway LoRaWAN da Radioenge ou está procurando um tutorial mais detalhado sobre o que ele faz e como funciona, confira o link abaixo:

👉 [Tutorial Completo do Gateway LoRaWAN da Radioenge](https://elcereza.com/gateway-lorawan-da-radioenge-tutorial-completo/)

---

Este guia rápido irá te mostrar como instalar e configurar o gateway LoRaWAN da Radioenge em uma Raspberry Pi com Raspbian. O processo inclui clonagem do repositório, configuração de permissões, execução do script de instalação e ajustes das configurações de localização no arquivo `global_conf.json`.

## Requisitos

- Raspberry Pi com Raspbian instalado
- Acesso à internet na Raspberry Pi
- Conexão física ao gateway LoRaWAN da Radioenge

## Passos de Instalação

### 1. Clonar o repositório com o pacote de instalação:

Abra o terminal e execute o comando abaixo para clonar o repositório que contém os arquivos necessários para configurar o gateway LoRaWAN:

```bash
sudo git clone https://github.com/elcereza/pkt_fwd_raspbian
```

### 2. Acessar o diretório clonado:
Após clonar o repositório, entre no diretório `pkt_fwd_raspbian`:

```bash
cd pkt_fwd_raspbian
```

### 3. Ajustar permissões do script de instalação:
Torne o script install.sh executável e ajuste as permissões para o usuário pi:

```bash
sudo chmod +x install.sh
sudo chown pi:pi install.sh
```
### 4. Executar o script de instalação:
Inicie o processo de instalação executando o script install.sh:

```bash
sudo ./install.sh
```
Este script irá configurar os componentes necessários para o funcionamento do gateway LoRaWAN.

### 5. Parar o serviço elcereza antes de editar as configurações:
Antes de modificar o arquivo de configuração, pare o serviço elcereza para garantir que as alterações sejam aplicadas corretamente:

```bash
sudo systemctl stop elcereza.service
```

### 6. Editar o arquivo global_conf.json:
#### 6.1. Obter o MAC Address da rede Wi-Fi:
O Gateway ID é derivado do MAC Address da interface de rede da Raspberry Pi. Para obter o MAC Address da rede Wi-Fi, use o seguinte comando:
```bash
ifconfig wlan0 | grep ether
```
A saída será algo semelhante a:
```bash
ether b8:27:eb:12:34:56  txqueuelen 1000  (Ethernet)
```
O MAC Address neste exemplo é b8:27:eb:12:34:56. Para criar o Gateway ID, siga as etapas abaixo:

Pegue os 3 primeiros bytes do MAC Address (b8:27:eb).
Adicione o valor fixo 656C após os 3 primeiros bytes.
Pegue os 3 últimos bytes do MAC Address (12:34:56).
O resultado será: b827eb656c123456.

#### 6.2. Modificar o arquivo global_conf.json:
Agora que você tem o Gateway ID, abra o arquivo global_conf.json para editar o Gateway ID, latitude (lat) e longitude (long) conforme a localização física do seu gateway.

Para editar o arquivo, use um editor de texto como o nano:

```bash
sudo nano /elcereza/LoRaWAN/global_conf.json
```
Ajuste os campos de acordo com seu Gateway ID e localização:

```json
"gateway_conf": {
    "gateway_ID": "b827eb656c123456",
    "server_address": "router.eu.thethings.network",
    "serv_port_up": 1700,
    "serv_port_down": 1700,
    "serv_enabled": true,
    "ref_latitude": X.XXXXX,
    "ref_longitude": Y.YYYYY,
    "ref_altitude": Z
}
```
gateway_ID: Insira o Gateway ID gerado com base no MAC Address da sua Raspberry Pi.
ref_latitude: Insira a latitude da localização do gateway.
ref_longitude: Insira a longitude da localização do gateway.
ref_altitude: Insira a altitude da localização (em metros, opcional).
Salve o arquivo (Ctrl + O, depois pressione Enter) e feche o editor (Ctrl + X).

### 7. Reiniciar o serviço elcereza:
Após salvar as alterações no arquivo de configuração, reinicie o serviço elcereza:

```bash
sudo systemctl start elcereza.service
```
Verifique se o LED verde no gateway acende, indicando que ele está em funcionamento.

### 8. Verificar o status do serviço elcereza:
Para confirmar que o serviço foi iniciado corretamente, use o comando abaixo para verificar o status:

```bash
sudo systemctl status elcereza.service
```
Se o serviço estiver rodando corretamente, a saída deve exibir algo semelhante a "active (running)".

#### 8.1 Troubleshooting
Caso o LED verde não acenda, verifique os logs do serviço para diagnosticar possíveis problemas:
```bash
sudo journalctl -u elcereza.service
```
Certifique-se de que o gateway está conectado corretamente à Raspberry Pi e que todas as dependências foram instaladas corretamente durante a execução do install.sh.
