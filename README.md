# LoRaWAN SX1301 Packet Forwarder

Packet Forwarder para concentradores **LoRaWAN baseados no Semtech SX1301**, com foco no **Gateway LoRaWAN da Radioenge**, preparado para funcionar com um único código-base em **Raspberry Pi OS** e **Armbian**, sobre SBCs ARM compatíveis.

Este projeto nasceu a partir da instalação utilizada originalmente em Raspberry Pi e foi reorganizado para não depender de um usuário `pi`, de paths fixos em `/home/pi`, de bibliotecas GPIO antigas ou de um binário pré-compilado específico para uma única placa.

A proposta atual é manter o **Raspberry Pi como referência elétrica e lógica de GPIO**, enquanto uma camada de compatibilidade traduz essa referência para Banana Pi, Orange Pi e outros SBCs que tenham um perfil conhecido.

O diretório de runtime continua sendo:

```text
/elcereza/LoRaWAN/
```

O serviço systemd utilizado pelo projeto é:

```text
elcereza-lorawan-sx1301.service
```


## Sumário

1. [Visão geral](#1-visão-geral)
2. [Por que este projeto existe](#2-por-que-este-projeto-existe)
3. [Objetivo do projeto](#3-objetivo-do-projeto)
4. [Hardware concentrador usado e recomendado](#4-hardware-concentrador-usado-e-recomendado)
5. [Arquitetura da solução](#5-arquitetura-da-solução)
6. [Sistemas operacionais compatíveis](#6-sistemas-operacionais-compatíveis)
7. [SBCs compatíveis e estado de validação](#7-sbcs-compatíveis-e-estado-de-validação)
8. [Interfaces utilizadas pelo gateway](#8-interfaces-utilizadas-pelo-gateway)
9. [Pinagem do Gateway LoRaWAN Radioenge](#9-pinagem-do-gateway-lorawan-radioenge)
10. [Pinagem no Raspberry Pi](#10-pinagem-no-raspberry-pi)
11. [Pinagem no Banana Pi](#11-pinagem-no-banana-pi)
12. [Pinagem no Orange Pi](#12-pinagem-no-orange-pi)
13. [Como funciona a compatibilidade de GPIO](#13-como-funciona-a-compatibilidade-de-gpio)
14. [Como adaptar para outro SBC](#14-como-adaptar-para-outro-sbc)
15. [Configuração da interface SPI](#15-configuração-da-interface-spi)
16. [Configuração da UART e GPS](#16-configuração-da-uart-e-gps)
17. [Instalação](#17-instalação)
18. [Configuração do gateway](#18-configuração-do-gateway)
19. [Gateway ID](#19-gateway-id)
20. [Serviço systemd](#20-serviço-systemd)
21. [Diagnóstico](#21-diagnóstico)
22. [Build e dependências](#22-build-e-dependências)
23. [Estrutura do projeto](#23-estrutura-do-projeto)
24. [Erros comuns e troubleshooting](#24-erros-comuns-e-troubleshooting)
25. [Boas práticas](#25-boas-práticas)
26. [Licença](#26-licença)
27. [Contato e referências](#27-contato-e-referências)


## 1. Visão geral

O **LoRaWAN SX1301 Packet Forwarder** prepara um SBC Linux ARM para operar um concentrador LoRaWAN baseado no **Semtech SX1301** utilizando o `mp_pkt_fwd`.

O projeto automatiza as principais etapas necessárias para colocar o gateway em funcionamento:

- detecta o sistema operacional;
- detecta o modelo do SBC quando existe perfil integrado;
- valida a arquitetura ARM;
- instala dependências de compilação;
- habilita SPI;
- compila o HAL do SX1301 e o packet forwarder nativamente;
- mantém compatibilidade de GPIO baseada na numeração BCM do Raspberry Pi;
- instala o serviço systemd;
- preserva `global_conf.json` durante reinstalações;
- fornece diagnóstico da instalação;
- permite adicionar novos SBCs sem criar outro `install.sh`.

O concentrador SX1301 não se comunica com o SBC por UART. A comunicação principal com o concentrador é feita por **SPI**. A **UART é utilizada apenas pelo GPS opcional**, quando presente e habilitado.


## 2. Por que este projeto existe

A instalação original era voltada especificamente para Raspberry Pi/Raspbian e dependia de vários detalhes daquele ambiente, como:

- usuário `pi`;
- paths em `/home/pi`;
- GPIO específico do Raspberry Pi;
- interfaces antigas de GPIO pelo sysfs;
- pacotes hoje obsoletos;
- binários previamente compilados para uma arquitetura específica.

Isso funciona quando todo o hardware é exatamente igual, mas dificulta o uso do mesmo concentrador em SBCs como Banana Pi e Orange Pi.

O objetivo desta versão é manter a mesma função do gateway, porém separar três conceitos:

1. **lógica do packet forwarder**;
2. **interface Linux usada para SPI e serial**;
3. **mapeamento físico de GPIO de cada SBC**.

Dessa forma, o código do gateway continua trabalhando com a mesma referência utilizada no Raspberry Pi e a adaptação fica concentrada na camada de plataforma.


## 3. Objetivo do projeto

Este repositório foi criado para oferecer uma instalação única, previsível e reproduzível do packet forwarder SX1301 em SBCs ARM.

A ideia é permitir que o mesmo projeto seja usado em:

- gateways LoRaWAN fixos;
- Raspberry Pi;
- Banana Pi;
- Orange Pi;
- instalações headless;
- sistemas embarcados baseados em Armbian;
- laboratórios e desenvolvimento de redes LoRaWAN;
- aplicações com Gateway LoRaWAN Radioenge com ou sem GPS.

O projeto não tenta adivinhar o pinout de uma placa desconhecida. Se um SBC não possuir perfil integrado, o instalador exige um mapeamento explícito antes de controlar GPIOs.


## 4. Hardware concentrador usado e recomendado

O concentrador utilizado como referência neste projeto é o **Gateway LoRaWAN da Radioenge baseado no Semtech SX1301**, disponível nas versões **RD43HAT** e **RD43HATGPS**.

A própria Radioenge documenta o equipamento como um concentrador LoRaWAN de oito canais com barramento para integração ao Raspberry Pi e possibilidade de integração a outros equipamentos que disponibilizem **SPI em 3,3 V**. A versão `RD43HATGPS` adiciona um receptor GPS acessível por **UART em 3,3 V**.

### 4.1 Hardware concentrador usado — sem GPS

**Radioenge RD43HAT — Gateway LoRaWAN SX1301 sem GPS**

Indicado para gateways fixos, nos quais latitude, longitude e altitude podem ser configuradas manualmente no `global_conf.json`.

**Link do concentrador:** [Radioenge RD43HAT — sem GPS](https://meli.la/1QiGMkB)

### 4.2 Hardware concentrador usado — com GPS

**Radioenge RD43HATGPS — Gateway LoRaWAN SX1301 com GPS**

A versão com GPS é compatível com a arquitetura do packet forwarder utilizada neste projeto. O GPS é acessado pela UART do SBC e pode fornecer localização e referência temporal ao software quando a interface serial estiver corretamente habilitada e configurada.

**Link do concentrador:** [Radioenge RD43HATGPS — com GPS](https://meli.la/1A13APi)

### 4.3 Página oficial do hardware

- [Gateway LoRaWAN — Radioenge](https://www.radioenge.com.br/produto/gateway-lorawan/)

O SX1301 continua utilizando **SPI** como interface principal. A UART existe exclusivamente para o GPS opcional e não substitui o SPI do concentrador.

## 5. Arquitetura da solução

A arquitetura mantém o Raspberry Pi como contrato lógico para GPIO e traduz apenas o que depende do hardware.

```text
                    install.sh
                        │
                        ▼
                 platform.sh
                        │
            ┌───────────┴───────────┐
            │                       │
            ▼                       ▼
      Interface SPI            GPIO RESET
      /dev/spidevX.Y                 │
            │                        ▼
            │                 gpio-compat.sh
            │                        │
            │          BCM Raspberry Pi canônico
            │                        │
            │       ┌────────────────┼────────────────┐
            │       ▼                ▼                ▼
            │  Raspberry Pi      Banana Pi        Orange Pi
            │       │                │                │
            └───────┴────────────────┴────────────────┘
                             │
                             ▼
                         SX1301
```

Quando existe GPS:

```text
GPS Radioenge
     │
     │ UART 3,3 V
     ▼
/dev/tty...
     │
     ▼
mp_pkt_fwd
```

A UART não passa pela camada `gpio-compat.sh`; ela é exposta pelo kernel como um dispositivo serial Linux.


## 6. Sistemas operacionais compatíveis

O instalador atual aceita duas famílias de sistema automaticamente.

### 6.1 Raspberry Pi OS

Suportado em Raspberry Pi ARM com arquitetura:

```text
armhf
arm64
```

O instalador habilita SPI usando `raspi-config` quando disponível e possui fallback para o `config.txt` do Raspberry Pi OS.

### 6.2 Armbian

Suportado em SBCs ARM que executem Armbian e possuam perfil de hardware integrado ou mapa GPIO fornecido pelo usuário.

Arquiteturas aceitas:

```text
armhf
arm64
```

O projeto foi preparado para imagens Armbian baseadas em Debian/Ubuntu que utilizem `apt`/`apt-get`.

### 6.3 Sistemas não tratados automaticamente

O instalador atual não considera instalação automática oficial em:

- x86;
- x86_64;
- Windows;
- macOS;
- distribuições Linux que não sejam detectadas como Raspberry Pi OS ou Armbian;
- SBC desconhecido sem mapeamento GPIO.

Isso não significa necessariamente que o código nunca possa ser portado para essas plataformas, apenas que elas não fazem parte do fluxo automático atual.


## 7. SBCs compatíveis e estado de validação

É importante separar **suporte implementado no software** de **validação real em hardware**.

### 7.1 Hardware validado

Os seguintes SBCs já foram testados fisicamente com o concentrador e com o packet forwarder em funcionamento:

| SBC | Sistema utilizado no teste | Perfil | Estado |
|---|---|---|---|
| **Raspberry Pi 3** | Raspberry Pi OS / Raspbian | `raspberry-pi` | **Testado em hardware** |
| **Banana Pi M2 Zero** | Armbian | `bananapi-m2-zero` | **Testado em hardware** |

O fato de um perfil estar implementado não significa que todos os modelos da mesma família já tenham sido testados fisicamente.

### 7.2 Suporte implementado — validação física por modelo pendente

| SBC / família | Perfil | Observação |
|---|---|---|
| Raspberry Pi com header de 40 pinos | `raspberry-pi` | GPIO BCM nativo; validar cada modelo antes de declarar hardware testado |
| Banana Pi P2 Zero | `bananapi-p2-zero` | Perfil integrado |
| Banana Pi M2 Plus | `bananapi-m2-plus` | Perfil integrado |
| Orange Pi PC | `orangepi-pc` | Perfil integrado; teste físico pendente |
| Orange Pi PC Plus | `orangepi-pc-plus` | Perfil integrado; teste físico pendente |

### 7.3 Outros SBCs Armbian

Outros SBCs podem utilizar o mesmo código e o mesmo instalador, porém **não devem ser considerados plug-and-play** até que exista um perfil de GPIO e sejam validados SPI, UART e pinagem.

O projeto não deve ser anunciado como compatível com “qualquer Orange Pi” ou “qualquer Banana Pi”. O suporte é definido por modelo/perfil.


## 8. Interfaces utilizadas pelo gateway

O projeto utiliza as seguintes interfaces de hardware.

| Interface | Uso | Obrigatória |
|---|---|---|
| 5 V | alimentação do concentrador | Sim |
| GND | referência elétrica | Sim |
| SPI SCK | clock do SX1301 | Sim |
| SPI MISO | dados SX1301 → SBC | Sim |
| SPI MOSI | dados SBC → SX1301 | Sim |
| SPI CS/CSN | seleção do SX1301 | Sim |
| GPIO RESET | reset do concentrador | Sim |
| UART TX/RX | comunicação com GPS integrado | Apenas versão com GPS |
| TimePulse | sinal disponibilizado pelo hardware Radioenge | Não utilizado pelo software atual |
| GPSRESET | reset dedicado do GPS | Não utilizado pelo software atual |
| I2C | — | Não utilizado pelo projeto atual |

### 8.1 O que realmente passa pelo `gpio-compat.sh`

No funcionamento padrão, o GPIO controlado diretamente pelos scripts é:

```text
RESET = BCM7
```

SPI e UART utilizam drivers do kernel Linux:

```text
SPI  -> /dev/spidevX.Y
UART -> /dev/tty...
```

A camada `gpio-compat.sh` possui a tabela completa BCM → header físico → GPIO nativo para permitir uma referência coerente entre SBCs, mas o acesso SPI continua sendo feito pelo driver `spidev` e a serial pelo driver TTY.


## 9. Pinagem do Gateway LoRaWAN Radioenge

O conector do Gateway LoRaWAN Radioenge possui os seguintes sinais principais:

| Pino no módulo Radioenge | Função | Uso neste projeto |
|---:|---|---|
| 1 | GND | Alimentação/referência |
| 2 | GND | Alimentação/referência |
| 3 | +5VCC | Alimentação |
| 4 | +5VCC | Alimentação |
| 5 | RESET | Reset do SX1301 |
| 6 | SCK | SPI clock |
| 7 | MISO | SPI MISO |
| 8 | MOSI | SPI MOSI |
| 9 | CSN | SPI chip select |
| 10 | NC | Não conectado |
| 11 | TimePulse | Não controlado pelo software atual |
| 12 | GPSRESET | Não controlado pelo software atual |
| 13 | GPSRXD | UART do GPS opcional |
| 14 | GPSTXD | UART do GPS opcional |

Na ligação de referência com Raspberry Pi, os sinais utilizados ficam:

| Função | Pino físico Raspberry Pi | BCM |
|---|---:|---:|
| UART TX → GPS RX | 8 | BCM14 |
| UART RX ← GPS TX | 10 | BCM15 |
| SPI MOSI | 19 | BCM10 |
| SPI MISO | 21 | BCM9 |
| SPI SCLK | 23 | BCM11 |
| SPI CS0 | 24 | BCM8 |
| RESET | 26 | BCM7 |

Alimentação:

```text
+5 V -> pino físico 2 ou 4
GND  -> qualquer GND adequado do header
```

O hardware trabalha com lógica SPI/UART de **3,3 V**. Não aplique 5 V diretamente em sinais lógicos de GPIO, SPI ou UART.


## 10. Pinagem no Raspberry Pi

No Raspberry Pi a referência canônica é nativa, portanto não é necessária tradução de nomes GPIO.

| Função | Pino físico | GPIO Raspberry Pi |
|---|---:|---|
| UART TX | 8 | BCM14 |
| UART RX | 10 | BCM15 |
| SPI MOSI | 19 | BCM10 |
| SPI MISO | 21 | BCM9 |
| SPI SCLK | 23 | BCM11 |
| SPI CS0 | 24 | BCM8 |
| RESET SX1301 | 26 | BCM7 |

> **Importante:** no header do Raspberry Pi, o BCM7/pino físico 26 também é a função alternativa `SPI0 CE1`. Neste projeto esse pino é reservado ao **RESET do SX1301**. A comunicação SPI padrão utiliza `CE0` no pino físico 24 (`/dev/spidev0.0`). Não troque simplesmente para `/dev/spidev0.1`, pois isso conflitaria com o RESET na ligação de referência.

Fluxo do reset:

```text
RESET solicitado pelo projeto
        │
        ▼
      BCM7
        │
        ▼
pino físico 26
```

O `reset.sh` aplica um pulso alto/baixo e depois libera o GPIO.

Para conferir a resolução:

```bash
sudo /elcereza/LoRaWAN/gpio-compat.sh resolve 7
```


## 11. Pinagem no Banana Pi

Os perfis Banana Pi atualmente integrados são:

```text
bananapi-m2-zero
bananapi-p2-zero
bananapi-m2-plus
```

A referência física desses perfis segue o header de 40 pinos compatível com o Raspberry Pi 3. Para o **Banana Pi M2 Zero**, todos os sinais efetivamente necessários ao Gateway Radioenge ficam assim:

| Função no gateway | Pino do módulo Radioenge | Pino físico no Banana Pi | Referência BCM Raspberry | Função nativa Banana Pi M2 Zero | GPIO nativo | Offset usado pelo perfil | Interface Linux |
|---|---:|---:|---:|---|---|---:|---|
| +5 V | 3 ou 4 | 2 ou 4 | — | VCC-5V | — | — | alimentação |
| GND | 1 ou 2 | 6, 9, 14, 20, 25, 30, 34 ou 39 | — | GND | — | — | alimentação |
| GPS RXD ← TX do SBC | 13 | 8 | BCM14 | UART3-TX | **PA13** | **13** | `/dev/ttyS3` quando UART3 está habilitada |
| GPS TXD → RX do SBC | 14 | 10 | BCM15 | UART3-RX | **PA14** | **14** | `/dev/ttyS3` quando UART3 está habilitada |
| SPI MOSI | 8 | 19 | BCM10 | SPI0-MOSI | **PC0** | **64** | `/dev/spidev0.0` |
| SPI MISO | 7 | 21 | BCM9 | SPI0-MISO | **PC1** | **65** | `/dev/spidev0.0` |
| SPI SCLK | 6 | 23 | BCM11 | SPI0-CLK | **PC2** | **66** | `/dev/spidev0.0` |
| SPI CSN / CS0 | 9 | 24 | BCM8 | SPI0-CS | **PC3** | **67** | `/dev/spidev0.0` |
| RESET SX1301 | 5 | 26 | BCM7 | GPIO | **PC7** | **71** | `gpiochip` / `libgpiod` |

Portanto, os GPIOs/sinais nativos efetivamente envolvidos no Banana Pi M2 Zero são:

```text
PA13 = GPIO/offset 13 = UART3 TX = pino físico 8
PA14 = GPIO/offset 14 = UART3 RX = pino físico 10
PC0  = GPIO/offset 64 = SPI0 MOSI = pino físico 19
PC1  = GPIO/offset 65 = SPI0 MISO = pino físico 21
PC2  = GPIO/offset 66 = SPI0 CLK  = pino físico 23
PC3  = GPIO/offset 67 = SPI0 CS   = pino físico 24
PC7  = GPIO/offset 71 = RESET     = pino físico 26
```

Os valores `13`, `14`, `64`, `65`, `66`, `67` e `71` acima são os offsets utilizados pelo perfil H3 deste projeto. O código de aplicação **não deve substituir BCM7 por 71**, por exemplo: `BCM7` continua sendo o contrato lógico e o perfil faz a tradução para `PC7`/offset `71`.

### 11.1 Banana Pi M2 Zero

Este modelo já foi **testado fisicamente** com o concentrador SX1301 e com o packet forwarder em funcionamento.

Para o reset, a aplicação continua solicitando:

```text
BCM7
```

A camada de compatibilidade resolve automaticamente:

```text
BCM7 -> pino físico 26 -> PC7 -> offset 71
```

### 11.2 GPS no Banana Pi M2 Zero

O GPS da versão `RD43HATGPS` utiliza os mesmos pinos físicos 8 e 10 da conexão de referência do Raspberry Pi. No Banana Pi M2 Zero esses pinos correspondem a:

```text
pino 8  -> PA13 -> UART3 TX
pino 10 -> PA14 -> UART3 RX
```

No Armbian para Allwinner H3, a UART3 pode ser habilitada pelo overlay `uart3` e é exposta normalmente como:

```text
/dev/ttyS3
```

A configuração típica do packet forwarder passa então a apontar `gps_tty_path` para `/dev/ttyS3`.

A comunicação GPS nesse SBC é **suportada pela arquitetura**, mas deve ser considerada separadamente da validação já feita do SX1301 via SPI até que a versão `RD43HATGPS` seja testada fisicamente nesse cenário.

## 12. Pinagem no Orange Pi

Os perfis Orange Pi atualmente integrados são:

```text
orangepi-pc
orangepi-pc-plus
```

Para Orange Pi PC e PC Plus:

| Função | Referência Raspberry | Pino físico | GPIO nativo H3 | Offset |
|---|---|---:|---|---:|
| UART TX | BCM14 | 8 | PA13 | 13 |
| UART RX | BCM15 | 10 | PA14 | 14 |
| SPI MOSI | BCM10 | 19 | PC0 | 64 |
| SPI MISO | BCM9 | 21 | PC1 | 65 |
| SPI SCLK | BCM11 | 23 | PC2 | 66 |
| SPI CS0 | BCM8 | 24 | PC3 | 67 |
| RESET SX1301 | BCM7 | 26 | PA21 | 21 |

Portanto, no Orange Pi o mesmo código lógico:

```text
BCM7
```

é interpretado como:

```text
BCM7 -> pino físico 26 -> PA21 -> offset 21
```

### Estado atual

Orange Pi PC e Orange Pi PC Plus possuem **suporte implementado**, porém ainda devem ser considerados **hardware não validado** até que o gateway seja testado fisicamente nesses modelos.

Não assuma essa mesma tabela para Orange Pi Zero, Zero 2W, 3, 4, 5 ou outros modelos.


## 13. Como funciona a compatibilidade de GPIO

O projeto usa a numeração **BCM do Raspberry Pi como API canônica**.

Isso significa que o restante do sistema pode continuar dizendo:

```text
RESET = BCM7
```

independentemente do SoC real.

A tradução segue esta ideia:

```text
BCM Raspberry Pi
      │
      ▼
pino físico canônico
      │
      ▼
perfil do SBC
      │
      ▼
GPIO nativo / gpiochip / offset
```

Exemplo:

```text
Raspberry Pi       BCM7 -> pino 26 -> BCM7
Banana Pi M2 Zero  BCM7 -> pino 26 -> PC7  / offset 71
Orange Pi PC       BCM7 -> pino 26 -> PA21 / offset 21
Orange Pi PC Plus  BCM7 -> pino 26 -> PA21 / offset 21
```

Para visualizar o mapa da placa instalada:

```bash
sudo /elcereza/LoRaWAN/gpio-compat.sh map
```

Para consultar apenas um GPIO:

```bash
sudo /elcereza/LoRaWAN/gpio-compat.sh resolve 7
```


## 14. Como adaptar para outro SBC

Adicionar suporte a um novo SBC não deve exigir uma nova versão do instalador.

Existem três pontos independentes que precisam ser confirmados:

1. SPI;
2. GPIO de RESET;
3. UART, somente se for utilizado GPS.

### 14.1 Primeiro: confirme a pinagem elétrica

Nunca copie offsets de outro SBC apenas porque ambos executam Armbian.

É necessário consultar o pinout oficial da placa e identificar:

```text
SPI MOSI
SPI MISO
SPI SCLK
SPI CS
GPIO ligado ao RESET do SX1301
UART TX
UART RX
```

Se o conector não for fisicamente compatível com Raspberry Pi, faça a ligação pelos **sinais**, não pelo número físico do header Raspberry.

### 14.2 Mapeando o RESET

O arquivo padrão para mapas adicionais é:

```text
/etc/elcereza/gpio-rpi-map.conf
```

Formato:

```text
# BCM backend chip offset native_name physical_pin_canonico
7 gpiod gpiochip0 71 PC7 26
```

O último campo representa o pino físico **canônico do Raspberry Pi associado ao BCM**, usado para validar a coerência lógica do mapa.

Para o RESET do hardware de referência, mantenha normalmente:

```text
BCM7 -> pino canônico 26
```

O que deve mudar de SBC para SBC é o controlador/offset nativo.

### 14.3 Selecionando um perfil

É possível informar explicitamente um perfil:

```bash
sudo -E env \
  LORAWAN_GPIO_PROFILE=bananapi-m2-zero \
  ./install.sh
```

Ou informar um mapa externo:

```bash
sudo -E env \
  LORAWAN_GPIO_MAP=/etc/elcereza/gpio-rpi-map.conf \
  ./install.sh
```

### 14.4 Alterando o dispositivo SPI

Se o SPI correto da placa aparecer como outro dispositivo:

```bash
sudo -E env \
  LORAWAN_SPI_DEV=/dev/spidev1.0 \
  ./install.sh
```

### 14.5 Alterando o BCM lógico de RESET

O instalador permite:

```bash
sudo -E env \
  LORAWAN_RESET_BCM=7 \
  ./install.sh
```

Para o Gateway Radioenge ligado conforme a referência Raspberry, o valor normal é **7**. Não altere esse número apenas para colocar o GPIO nativo do Banana Pi ou Orange Pi; essa tradução pertence ao perfil.

### 14.6 Adaptando o GPS

A serial do GPS é configurada no `global_conf.json`, não pelo `gpio-compat.sh`.

Exemplo:

```json
"gps_tty_path": "/dev/ttyS0"
```

Em outro SBC, altere esse valor para a TTY realmente ligada aos pinos TX/RX utilizados.


## 15. Configuração da interface SPI

O dispositivo padrão é:

```text
/dev/spidev0.0
```

Esse detalhe é intencional: o projeto utiliza **SPI0 CE0** no pino físico 24. No Raspberry Pi, o pino físico 26/BCM7 fica reservado para o RESET do SX1301 e portanto não deve ser usado como `SPI0 CE1` nesta ligação.

### 15.1 Raspberry Pi OS

Quando `raspi-config` está disponível, o instalador o utiliza para habilitar SPI.

Como fallback, configura:

```text
dtparam=spi=on
```

no `config.txt` apropriado.

### 15.2 Armbian

O instalador usa `/boot/armbianEnv.txt` e adiciona/preserva o overlay:

```text
overlays=... spi-spidev
param_spidev_spi_bus=0
param_spidev_spi_cs=0
```

Se o device ainda não existir logo após a instalação:

```bash
ls -l /dev/spidev*
```

reinicie:

```bash
sudo reboot
```

Depois confira novamente:

```bash
ls -l /dev/spidev*
```

### 15.3 Como saber qual SPI usar

Consulte a documentação do SBC e os devices expostos pelo kernel:

```bash
ls -l /dev/spidev*
```

O SPI selecionado precisa estar eletricamente conectado aos sinais MOSI, MISO, SCLK e CS do concentrador.


## 16. Configuração da UART e GPS

A versão **Radioenge RD43HATGPS é compatível com o software utilizado neste projeto**. A Radioenge disponibiliza o GPS opcional por uma UART de **3,3 V**, e o `packet_forwarder` utilizado como base possui suporte a porta serial GPS por meio de `gps_tty_path`, além de rotinas de referência temporal/localização por GPS.

A diferença importante é que **a UART não é configurada automaticamente pelo `gpio-compat.sh`**. O sistema operacional precisa expor a UART correta e o `global_conf.json` deve apontar para a TTY correspondente.

O arquivo distribuído pelo projeto contém parâmetros como:

```json
"gps": false,
"fake_gps": true,
"gps_tty_path": "/dev/ttyS0"
```

### 16.1 Sem GPS

Na versão `RD43HAT`, ou quando o GPS não será utilizado, mantenha o GPS real desabilitado e use coordenadas fixas quando necessário:

```json
"gps": false,
"fake_gps": true,
"ref_latitude": -12.000000,
"ref_longitude": -38.000000,
"ref_altitude": 0
```

### 16.2 Com GPS — suporte real do packet forwarder

Para a versão `RD43HATGPS`, a configuração conceitual é:

```json
"gps": true,
"fake_gps": false,
"gps_tty_path": "/dev/tty_CORRETA"
```

O `mp_pkt_fwd`/packet forwarder possui suporte de software para GPS, incluindo abertura da porta serial configurada, estado de referência GPS e uso dessa referência para operações dependentes de tempo. Portanto, **o GPS não deve ser descrito como incompatível**.

O que varia de plataforma para plataforma é apenas:

1. qual UART está conectada aos pinos físicos 8 e 10;
2. qual overlay ou configuração do kernel habilita essa UART;
3. qual device `/dev/tty*` representa essa interface;
4. se a UART está livre de console/login serial.

### 16.3 Raspberry Pi 3

Na conexão documentada pela Radioenge:

```text
pino físico 8  -> UART TX do Raspberry Pi -> GPS RXD
pino físico 10 -> UART RX do Raspberry Pi <- GPS TXD
```

No Raspberry Pi OS, prefira identificar a UART pelo alias estável quando disponível:

```text
/dev/serial0
```

Dependendo da configuração da placa, também podem aparecer nomes como `/dev/ttyAMA0` ou `/dev/ttyS0`.

Antes de ativar o GPS, confirme que o console serial não está utilizando essa UART.

### 16.4 Banana Pi M2 Zero

No Banana Pi M2 Zero, os mesmos pinos físicos são:

```text
pino 8  -> PA13 -> UART3 TX
pino 10 -> PA14 -> UART3 RX
```

O Armbian para H3 disponibiliza o overlay `uart3`, que utiliza `PA13/PA14` e expõe a interface normalmente como:

```text
/dev/ttyS3
```

Depois de habilitar a UART3 e reiniciar, confirme:

```bash
ls -l /dev/ttyS3
```

E ajuste:

```json
"gps": true,
"fake_gps": false,
"gps_tty_path": "/dev/ttyS3"
```

### 16.5 Orange Pi PC / PC Plus

Esses modelos também são baseados em Allwinner H3 e o perfil utiliza os pinos físicos 8 e 10 como `PA13/PA14`. O mesmo conceito de UART3 se aplica, mas o GPS nesses modelos permanece **sem validação física neste projeto**.

Confirme sempre o device real antes de alterar o `global_conf.json`:

```bash
ls -l /dev/ttyS* /dev/ttyAMA* /dev/serial* 2>/dev/null
```

### 16.6 `TimePulse` e `GPSRESET`

O hardware Radioenge também expõe os sinais `TimePulse` e `GPSRESET` no conector do módulo. Eles **não são controlados diretamente pelos scripts atuais deste repositório** e não fazem parte da tabela de conexão padrão Radioenge → Raspberry Pi 3 usada pelo packet forwarder para SPI/UART.

Isso não impede o uso normal do GPS por UART. Caso uma aplicação futura precise controlar `GPSRESET` ou aproveitar `TimePulse` externamente, esses sinais deverão receber um mapeamento específico na plataforma correspondente.

## 17. Instalação

### 17.1 Clonar o repositório

```bash
git clone https://github.com/elcereza/lorawan-sx1301-packet-forwarder.git
cd lorawan-sx1301-packet-forwarder
```

### 17.2 Executar o instalador

```bash
chmod +x install.sh
sudo ./install.sh
```

Não é necessário clonar o repositório com `sudo`.

O instalador resolve seus arquivos auxiliares a partir do próprio diretório e não depende de:

```text
/home/pi
```

nem de qualquer nome de usuário específico.

### 17.3 O que o instalador faz

Durante a instalação são executadas, entre outras, as seguintes etapas:

- detecção da plataforma;
- detecção do SBC;
- seleção do perfil GPIO;
- validação de `armhf`/`arm64`;
- validação do SPI selecionado;
- instalação das dependências;
- ativação do SPI;
- compilação nativa do packet forwarder;
- instalação das bibliotecas necessárias;
- criação do runtime em `/elcereza/LoRaWAN`;
- instalação do serviço systemd;
- migração de instalações antigas que utilizavam `elcereza.service`.

### 17.4 Reboot quando necessário

Se o SPI tiver acabado de ser habilitado e `/dev/spidev0.0` ainda não existir, o instalador solicitará:

```bash
sudo reboot
```

O serviço fica habilitado para iniciar automaticamente no próximo boot.


## 18. Configuração do gateway

A configuração principal fica em:

```text
/elcereza/LoRaWAN/global_conf.json
```

Para editar:

```bash
sudo nano /elcereza/LoRaWAN/global_conf.json
```

Em uma reinstalação, o instalador **preserva o `global_conf.json` existente**.

Entre os parâmetros importantes estão:

```json
"gateway_conf": {
    "gateway_ID": "b827eb656c123456",
    "server_address": "au1.cloud.thethings.network",
    "serv_port_up": 1700,
    "serv_port_down": 1700,
    "serv_enabled": true,
    "ref_latitude": -12.000000,
    "ref_longitude": -38.000000,
    "ref_altitude": 0
}
```

Depois de alterar a configuração:

```bash
sudo systemctl restart elcereza-lorawan-sx1301.service
```


## 19. Gateway ID

O projeto mantém a regra histórica de gerar o Gateway ID a partir do MAC Address inserindo `656c` entre os três primeiros e os três últimos bytes.

Para consultar interfaces:

```bash
ip link
```

Para consultar diretamente o MAC de `wlan0`:

```bash
cat /sys/class/net/wlan0/address
```

Exemplo:

```text
MAC:        b8:27:eb:12:34:56
Gateway ID: b827eb656c123456
```

A construção fica:

```text
b8 27 eb + 65 6c + 12 34 56
```

resultando em:

```text
b827eb656c123456
```

Use a interface que representa corretamente a identidade desejada para aquele gateway.


## 20. Serviço systemd

O serviço oficial desta versão é:

```text
elcereza-lorawan-sx1301.service
```

### Status

```bash
sudo systemctl status elcereza-lorawan-sx1301.service --no-pager -l
```

### Iniciar

```bash
sudo systemctl start elcereza-lorawan-sx1301.service
```

### Parar

```bash
sudo systemctl stop elcereza-lorawan-sx1301.service
```

### Reiniciar

```bash
sudo systemctl restart elcereza-lorawan-sx1301.service
```

### Logs em tempo real

```bash
sudo journalctl -u elcereza-lorawan-sx1301.service -f
```

### Últimas mensagens

```bash
sudo journalctl -u elcereza-lorawan-sx1301.service -n 100 --no-pager
```

Instalações antigas com:

```text
elcereza.service
```

são migradas pelo instalador somente após um novo build ser concluído com sucesso.


## 21. Diagnóstico

O projeto instala:

```text
/elcereza/LoRaWAN/diagnose.sh
```

Execute:

```bash
sudo /elcereza/LoRaWAN/diagnose.sh
```

O diagnóstico verifica itens como:

- plataforma detectada;
- perfil GPIO;
- GPIO canônico de RESET;
- dispositivo SPI esperado;
- presença do `mp_pkt_fwd`;
- bibliotecas de runtime;
- estado do serviço systemd;
- mensagens recentes do journal.

Também é útil verificar manualmente:

```bash
ls -l /dev/spidev*
```

```bash
sudo /elcereza/LoRaWAN/gpio-compat.sh resolve 7
```

```bash
sudo systemctl status elcereza-lorawan-sx1301.service --no-pager -l
```


## 22. Build e dependências

O packet forwarder é compilado **na própria placa**, evitando depender de um executável ARM pré-compilado distribuído no repositório.

O build utiliza versões/revisões controladas de componentes legados necessários ao ecossistema SX1301, incluindo:

- `kersing/lora_gateway`;
- `kersing/paho.mqtt.embedded-c`;
- `kersing/ttn-gateway-connector`;
- `kersing/protobuf-c`;
- `kersing/packet_forwarder`.

As revisões são fixadas pelo `build.sh` para que uma mudança futura no HEAD de um projeto externo não altere silenciosamente uma instalação de campo.

Também existe uma camada de compatibilidade com compiladores modernos para o código legado do `packet_forwarder`.

O instalador não depende mais de pacotes antigos como:

```text
python-dev
python-rpi.gpio
```

O resultado final é um `mp_pkt_fwd` compilado para a arquitetura real da máquina.


## 23. Estrutura do projeto

```text
lorawan-sx1301-packet-forwarder/
├── LICENSE
├── README.md
├── build-pi.sh
├── build.sh
├── diagnose.sh
├── elcereza-lorawan-sx1301.service
├── global_conf.json
├── gpio-compat.sh
├── install.sh
├── mp_pkt_fwd
├── platform.sh
├── reset.sh
├── start.sh
└── tests/
    └── smoke.sh
```

### `install.sh`

Instalador principal. Detecta plataforma, configura hardware, compila o projeto e instala o serviço.

### `platform.sh`

Detecta Raspberry Pi OS/Armbian, modelo do SBC, arquitetura, SPI e perfil GPIO.

### `gpio-compat.sh`

Implementa a tradução da numeração BCM Raspberry Pi para GPIOs nativos dos SBCs suportados.

### `reset.sh`

Executa o reset do concentrador SX1301 usando o GPIO canônico definido pelo projeto.

### `start.sh`

Valida SPI, executa o reset e inicia `mp_pkt_fwd`.

### `build.sh`

Baixa as revisões fixadas das dependências e compila o packet forwarder nativamente.

### `diagnose.sh`

Executa verificações rápidas de instalação e runtime.

### `global_conf.json`

Configuração principal do gateway e dos servidores LoRaWAN.


## 24. Erros comuns e troubleshooting

### 24.1 `/dev/spidev0.0` não existe

Verifique:

```bash
ls -l /dev/spidev*
```

Se o instalador acabou de habilitar o overlay, reinicie:

```bash
sudo reboot
```

Em outro SBC, confirme também se o bus e chip-select definidos realmente correspondem ao header utilizado.

### 24.2 O serviço inicia e cai imediatamente

Execute:

```bash
sudo journalctl -u elcereza-lorawan-sx1301.service -n 100 --no-pager
```

Depois:

```bash
sudo /elcereza/LoRaWAN/diagnose.sh
```

Confirme principalmente:

- SPI disponível;
- reset correto;
- alimentação do concentrador;
- configuração do `global_conf.json`;
- bibliotecas de runtime.

### 24.3 O SX1301 não responde

Confirme a ligação:

```text
MOSI
MISO
SCLK
CS0
RESET
5 V
GND
```

E valide o reset:

```bash
sudo /elcereza/LoRaWAN/gpio-compat.sh resolve 7
```

No Banana Pi M2 Zero, por exemplo, o esperado é uma resolução equivalente a:

```text
BCM7 -> pino 26 -> PC7 -> offset 71
```

### 24.4 SBC detectado como genérico

Se a placa não tiver perfil integrado, o instalador deve recusar a tentativa de adivinhar o GPIO.

Crie um mapa validado para o hardware ou adicione um novo perfil em `gpio-compat.sh`.

### 24.5 GPS não recebe dados

Confira:

- se a versão do gateway realmente possui GPS;
- se a UART está habilitada;
- se o console serial não está ocupando a porta;
- TX e RX cruzados corretamente;
- tensão lógica de 3,3 V;
- `gps_tty_path` apontando para a TTY correta;
- parâmetros `gps` e `fake_gps` coerentes.

Liste portas disponíveis:

```bash
ls -l /dev/ttyS* /dev/ttyAMA* /dev/serial* 2>/dev/null
```

### 24.6 Alterei o GPIO para o número nativo do SBC e parou de funcionar

Não coloque `71` ou `21` em `LORAWAN_RESET_BCM` para representar Banana Pi ou Orange Pi.

O contrato é BCM Raspberry:

```text
RESET = BCM7
```

A conversão para PC7/PA21 pertence ao perfil de hardware.


## 25. Boas práticas

### 25.1 Use o pinout oficial do SBC

Nunca reutilize GPIOs nativos de outra placa apenas porque o processador ou o sistema operacional parece semelhante.

### 25.2 Preserve o contrato BCM

Código de aplicação e scripts comuns devem continuar utilizando a referência Raspberry Pi BCM.

### 25.3 Teste SPI antes de investigar rede LoRaWAN

Se o concentrador não inicializa, confirme primeiro a camada física SPI/RESET antes de investigar TTN, ChirpStack ou configuração de canais.

### 25.4 Não sobrescreva `global_conf.json` sem necessidade

O instalador já preserva o arquivo existente durante atualizações.

Faça backup antes de mudanças importantes:

```bash
sudo cp /elcereza/LoRaWAN/global_conf.json \
  /elcereza/LoRaWAN/global_conf.json.backup
```

### 25.5 Valide novos SBCs em hardware

Um perfil implementado no software não deve ser anunciado como “hardware testado” antes de uma validação real com o concentrador.

### 25.6 Verifique alimentação

O Gateway LoRaWAN Radioenge é alimentado em 5 V. Garanta uma alimentação estável e corrente suficiente para SBC + concentrador.

### 25.7 Não trate GPIO como tolerante a 5 V

SPI, UART e GPIO são sinais lógicos de 3,3 V. Utilize conversão de nível quando integrar hardware que opere em outra tensão.


## 26. Licença

Este projeto é distribuído sob a **MIT License**.

Consulte:

```text
LICENSE
```


## 27. Contato e referências

### 27.1 Projeto e autor

| Recurso | Link |
|---|---|
| **Projeto** | [elcereza/lorawan-sx1301-packet-forwarder](https://github.com/elcereza/lorawan-sx1301-packet-forwarder) |
| **Autor** | Gustavo Cereza |
| **GitHub** | [github.com/GustavoCereza](https://github.com/GustavoCereza) |
| **LinkedIn** | [linkedin.com/in/gustavo-cereza](https://www.linkedin.com/in/gustavo-cereza/) |
| **Site** | [elcereza.com](https://elcereza.com) |

### 27.2 Hardware concentrador usado neste projeto

| Hardware | Link |
|---|---|
| **Radioenge RD43HAT — SX1301 sem GPS** | [Ver concentrador](https://meli.la/1QiGMkB) |
| **Radioenge RD43HATGPS — SX1301 com GPS** | [Ver concentrador](https://meli.la/1A13APi) |
| **Página oficial do Gateway LoRaWAN** | [radioenge.com.br/produto/gateway-lorawan](https://www.radioenge.com.br/produto/gateway-lorawan/) |
| **Fabricante** | [Radioenge](https://www.radioenge.com.br/) |
| **Fórum técnico** | [Fórum Radioenge — Gateway LoRaWAN](https://forum.radioenge.com.br/c/LoRaWAN/Gateway-LoRaWAN/6) |

### 27.3 Documentação de hardware e plataforma

- [Banana Pi BPI-M2 Zero — pinout oficial](https://wiki.banana-pi.org/Banana_Pi_BPI-M2_ZERO)
- [Armbian sun8i-H3 overlays — SPI e UART](https://github.com/armbian/sunxi-DT-overlays/blob/master/sun8i-h3/README.sun8i-h3-overlays)
- [Packet Forwarder — kersing](https://github.com/kersing/packet_forwarder)

### 27.4 Tutoriais relacionados

- [Tutorial completo do Gateway LoRaWAN da Radioenge](https://elcereza.com/gateway-lorawan-da-radioenge-tutorial-completo)
- [The Things Network — primeiros passos](https://elcereza.com/the-things-network-primeiros-passos/)
