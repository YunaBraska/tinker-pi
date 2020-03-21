```shell script
 _______ _      _                        _____ _____  
|__   __(_)    | |                      |  __ \_   _|
  | |   _ _ __ | | _____ _ __   ______  | |__) || |  
  | |  | | '_ \| |/ / _ \ '__| |______| |  ___/ | |   
  | |  | | | | |   <  __/ |             | |    _| |_  
  |_|  |_|_| |_|_|\_\___|_|             |_|   |_____| 
```
#### Setup Raspberry Pi Zero over USB (UART SSH) - UNIX ONLY

## Motivation
Since i am using the PI Zero for many projects, i wanted to have a way for setting it up without any keyboard or monitor connected

## How to use it
1) Download the script `tinkerPi.sh`
2) Insert an empty or pi micro SD-Card in your computer
![SD-Card](resources/mac_sd_card.jpg)
3) Open the terminal
4) Start the script like this `sodo /pat-to-the-downloaded-script-folder/tinkerPi.sh`
5) Select `SETUP_SD_CARD` from the menu and follow the setup
![SD-Card](resources/TINKERPI_SETUP.jpg) 
6) Insert the micro SD-Card now to the raspberry pi zero
![SD-Card](resources/PI_ZERO_SD_CARD.jpg)
7) Connect the Pi with your computer using a micro USB wire (On PI, use the micro usb slot which is the closest to the center)
![SD-Card](resources/PI_ZER_MICRO_USB.jpg) 
8) Select not the menu item `CONFIGURE_PI` from the `tinkerPI.sh` script and follow the instructions
![SD-Card](resources/TINKERPI_CONFIGURE.jpg)
![SD-Card](resources/RASPI_CONFIG.jpg)
9) Done

### Interesting tools:
* [SparkFun-Pi-Zero-USB-Stem](https://www.amazon.de/SparkFun-Pi-Zero-USB-Stem/dp/B079H4CWTL)
![SparkFun-Pi-Zero-USB-Stem](resources/PI_STEM.jpg)
* [hat-zero-brick](https://www.tinkerforge.com/en/shop/bricks/hat-zero-brick.html)
![hat-zero-brick](resources/brick_hat_zero_tilted_w_rpi_800.jpg)
* [Java Tinkerforge-Sensor library](https://github.com/YunaBraska/tinkerforge-sensor)