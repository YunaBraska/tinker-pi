#!/usr/bin/env bash
set -e
echo " _______ _      _                        _____ _____  "
echo "|__   __(_)    | |                      |  __ \_   _| "
echo "  | |   _ _ __ | | _____ _ __   ______  | |__) || |   "
echo "  | |  | | '_ \| |/ / _ \ '__| |______| |  ___/ | |   "
echo "  | |  | | | | |   <  __/ |             | |    _| |_  "
echo "  |_|  |_|_| |_|_|\_\___|_|             |_|   |_____| "
#Aschii text made with http://patorjk.com/software/taag/
#Using documentation from https://desertbot.io/blog/ssh-into-pi-zero-over-usb
PI_IMAGE_URL="https://downloads.raspberrypi.org/raspbian_lite_latest"
red='\e[1;31m'
gre='\e[1;32m'
yel='\e[1;33m'
blu='\e[1;34m'
pur='\e[1;35m'
auq='\e[1;36m'
cen='\e[0m\e[21m'
gry='\e[1;37m'
MENU_OPTIONS=("Option1" "Option2")
DEFAULT_HOSTNAME="raspberrypi.local"
if [[ $EUID -ne 0 ]]; then
  echo -e "${red}This script must be run as root/sudo${cen}"
  echo -e "${gry}Reason: This script uses commands like 'mount', 'unmount' and 'dd' which are controlling the connected devices and can't run without these permissions${cen}"
  exit 1
fi
SCRIPTPATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/$(basename "$0")"
STEP="0"
STEPS=$(grep "nextStep" "${SCRIPTPATH}" | tail -n +2 | wc -l | awk '{print $1}')

function nextStep() {
  let "STEP=STEP+1"
}

function speak() {
  if command -v say &>/dev/null; then
    (say "${1}" &)
  elif command -v espeak &>/dev/null; then
    (echo "${1}" | espeak &>/dev/null)
  fi
}

function to_bar() {
  PERC="${1}"
  if [ -z ${PERC+x} ] || [[ "${PERC}" == *"unknown"* ]]; then PERC=1; fi
  BAR_1="$((PERC / 2))"
  BAR_2="$(((100 - PERC) / 2))"
  BAR="${red}"
  for ((i = 0; i < "${BAR_1}"; i++)); do BAR="${BAR}|"; done
  BAR="$BAR${gre}"
  for ((i = 0; i < "${BAR_2}"; i++)); do BAR="${BAR}_"; done
  echo -e "${BAR}${cen}"
}

isPiImage() {
  #AWK IS USED TO GET OFF THE WHITE SPACES - 'cut' command is different on every system...
  FILE_KERNEL="$(find "${1}" -type f -name "kernel.img" -maxdepth 1 -mindepth 1 | wc -l | awk '{print $1}')"
  FILE_CONFIG="$(find "${1}" -type f -name "config.txt" -maxdepth 1 -mindepth 1 | wc -l | awk '{print $1}')"
  FILE_CMDLINE="$(find "${1}" -type f -name "cmdline.txt" -maxdepth 1 -mindepth 1 | wc -l | awk '{print $1}')"
  FILE_RPI="$(find "${1}" -type f -name "*rpi*" -maxdepth 1 -mindepth 1 | wc -l | awk '{print $1}')"
  if [ "${FILE_KERNEL}" != 0 ] && [ "${FILE_CONFIG}" != 0 ] && [ "${FILE_CMDLINE}" != 0 ] && [ "${FILE_RPI}" != 0 ]; then
    echo "true"
  else
    echo "false"
  fi
}

function getPiVolume() {
  #SEARCH FOR PI SD CARD
  find "/Volumes" -type d -not -name ".*" -maxdepth 1 -mindepth 1 | while read -r VOLUME; do
    if [[ "$(isPiImage "${VOLUME}")" == "true" ]]; then
      echo "${VOLUME}"
      return
    fi
  done

  #SEARCH FOR EMPTY SD CARD
  find "/Volumes" -type d -not -name ".*" -maxdepth 1 -mindepth 1 | while read -r VOLUME; do
    if [ "$(find "${VOLUME}" -not -name ".*" -maxdepth 1 -mindepth 1 | wc -l | awk '{print $1}')" == 0 ]; then
      echo "${VOLUME}"
      return
    fi
  done
}

function assertVolumeExists() {
  if [ -z "${1}" ]; then
    speak "Please insert raspberry pi sd card?"
    echo -e "[${STEP}/${STEPS}] [${red}WARN${cen}] Please insert raspberry pi sd card"
    exit 1
  else
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Using raspberry pi card: [${1}]"
  fi
}

function downloadPiImage() {
  if [[ "$(isPiImage "${1}")" == "false" ]]; then
    speak "Do you want install to the raspberry pi image on ${1}?"
    echo -e "Do you want install to the raspberry pi image on [${yel}${1}${cen}]?"
    select yn in "Yes" "No"; do
      case $yn in
      Yes)
        downloadPiImageReal "${1}"
        break
        ;;
      No)
        speak "Hey! How sould i continue without any sd card??"
        echo -e "[${STEP}/${STEPS}] [${yel}WARN${cen}] Cannot proceed without any raspberry pi sd card"
        exit 0
        ;;
      esac
    done
  else
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Image already installed on [${1}]"
  fi
}

function getMountPartition() {
  echo "$(df -ah | grep "${1}" | awk '{print $1}')"
}

#TODO: how to get the device
function getMountDevice() {
  MOUNT_POINT="$(getMountPartition "${1}")"
  #MOUNT_POINT="$(echo "${1}" | awk -F's' '{print $1}')s$(echo "${1}" | awk -F's' '{print $2}')"
  echo "${MOUNT_POINT:0:-2}"
}

#TODO: how to unmount disk in linux
function f_unmountByDevice() {
  #GET DEVIGE WITH PARTITION
  if ! command -v diskutil &>/dev/null; then
    echo -e "[${yel}]WARNING[${cen}] Linux 'mount' and 'unmount' wasn't tested for this script."
    unmount "${1}"
  else
    diskutil unmountDisk "${1}"
  fi
}

#TODO: how to mount disk in linux
function f_mount() {
  if ! command -v diskutil &>/dev/null; then
    echo -e "[${yel}]WARNING[${cen}] Linux 'mount' and 'unmount' wasn't tested for this script."
    echo -e "${gry}* You can also insall the 'Raspbian Buster Lite' image manually [https://www.raspberrypi.org/downloads/raspbian/][ and https://www.raspberrypi.org/documentation/installation/installing-images/README.md]${cen}"
    mount "${1}" "${2}"
  else
    diskutil mount "${1}"
  fi
}

function downloadPiImageReal() {
  PI_IMAGE="/tmp/raspbian_lite_latest_image"
  if [ -f "${PI_IMAGE}.zip" ]; then
    echo -e "Image already downloaded to [${PI_IMAGE}.zip]"
  else
    if ! command -v wget &>/dev/null; then
      speak "I need to have th command wget. Please install this for me"
      echo "Command wget not found - plase install e.g. [brew install wget]"
      exit 1
    fi
    speak "Downloading raspberry pi image"
    wget -O "${PI_IMAGE}.zip" "${PI_IMAGE_URL}"
  fi
  rm -rf "${PI_IMAGE}"
  mkdir -p "${PI_IMAGE}"
  (tar -xvf "${PI_IMAGE}.zip" -C "${PI_IMAGE}")
  PI_IMAGE="$(find "${PI_IMAGE}" -maxdepth 1 -mindepth 1 | head -n1)"
  MOUNT_PARTITION="$(getMountPartition "${1}")"
  MOUNT_DEVICE="$(getMountDevice "${1}")"
  f_unmountByDevice "${1}"
  speak "Installing raspberry pi image to ${1}. You can get some tee, this may take a while."
  echo -e "${gry}* HINT: Installing image to [${1}] [${MOUNT_DEVICE}] this may take few minutes...${cen}"
  dd bs=4096 if="${PI_IMAGE}" of="${MOUNT_DEVICE}"

  MOUNT_COUNT=0
  until f_mount "${MOUNT_PARTITION}" "${1}" >/dev/null 2>&1 || [ ${MOUNT_COUNT} -eq 30 ]; do
    sleep $((1))
    MOUNT_COUNT=$((MOUNT_COUNT + 1))
  done
  if [[ ${MOUNT_COUNT} == 30 ]]; then
    speak "Done! Image is oinstalled on ${1}. If you want to continue then plase reinsert the sd card and select SETUP_SD_CARD again."
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Image installed on [${1}] [${MOUNT_PARTITION}]"
    echo -e "If you want to continue then plase reinsert the sd card and select [${yel}SETUP_SD_CARD${cen}] in the menu"
    return
  fi
  speak "Done! Image is oinstalled on ${1}"
  echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Image installed on [${1}] [${MOUNT_PARTITION}]"
}

function createFile() {
  if [ ! -e "$1" ]; then
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Creating file [${1}]"
    touch "$1"
  else
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] File [${1}] already exists"
  fi
}

function deleteInFileEcho() {
  deleteInFile "${1}" "${2}"
  echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Deleted [${1}] from file [${2}]"
}

function deleteInFile() {
  while read -r LINE; do
    if [[ ${LINE} != "${1}"* ]]; then echo "${LINE}"; fi
  done <"${2}" >"${2}.t"
  mv "${2}"{.t,}
}

function appendToFile() {
  if grep -q "${1}" "${2}"; then
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] [${1}] already exists in file [${2}]"
  else
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Appending [${1}] to file [${2}]"
    echo -e "${1}" >>"${2}"
  fi
}

function replaceInFile() {
  if grep -q "${2}" "${3}"; then
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] [${2}] already exists in file [${3}]"
  else
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Replacing [${1}] with [${1} ${2}] in file [${3}]"
    while read a; do
      echo ${a//${1}/${1} ${2}}
    done <"${3}" >"${3}.t"
    mv "${3}"{.t,}
  fi
}

function action_setup_sd_card() {
  nextStep
  assertVolumeExists "${1}"

  nextStep
  downloadPiImage "${1}"

  sleep 2
  nextStep
  createFile "${1}/ssh"

  nextStep
  createFile "${1}/avahi"

  nextStep
  deleteInFile "dtoverlay" "${1}/config.txt"
  appendToFile "dtoverlay=dwc2" "${1}/config.txt"

  nextStep
  replaceInFile "rootwait" "modules-load=dwc2,g_ether,g_serial" "${1}/cmdline.txt"

  f_unmountByDevice "${1}"
  speak "Setup is finished. You can now start your pi with the sd card and go on with the menu item CONFIGURE_PI"
  echo -e "${gre}FINISH${cen} You can now insert the sd card into your pi and continue with [${yel}CONFIGURE_PI${cen}]"
  echo -e "${gry}Hint: To connect the PI with the computer, use the micro USB which is clothest to the center on the PI Zero - there is NO need for an additional power cable${cen}"

  showMenu
}

function action_configure_pi() {
  #This number comes from function "action_setup_sd_card"
  STEP=6

  nextStep
  if ping -c1 "${DEFAULT_HOSTNAME}" &>/dev/null; then
    echo -e "[${STEP}/${STEPS}] Found default raspberry pi [${yel}${DEFAULT_HOSTNAME}${cen}]"
    TARGET_HOSTNAME="${DEFAULT_HOSTNAME}"
    speak "I found it!"
    sleep 2
  else
    speak "Enter raspberry pi hostname. Press enter to use the default"
    read -rp "$(echo -e "[${STEP}/${STEPS}] Enter raspberrypi hostname to connect (default=${yel}${DEFAULT_HOSTNAME}${cen}): ")" TARGET_HOSTNAME
    if [ -z "${TARGET_HOSTNAME}" ]; then TARGET_HOSTNAME="${DEFAULT_HOSTNAME}"; fi

    speak "Searching for raspberry pi."
    echo -e "[${STEP}/${STEPS}] Searching for [${yel}${TARGET_HOSTNAME}${cen}] Please connect the pi with the usb wire"
    echo -e "${gry}* Where to connect? On PI Zero use the micro USB which is clothest to the center to connect to your computer - there wont be a need for an additional power cable${cen}"
    echo -e "${gry}* How often can i connect? On default you can connect via USB until the raspberry pi restards. If you need to run again [SETUP_SD_CARD]${cen}"
    echo -e "${gry}* Can't connect? Be patience cause starting the pi can take around 90 seconds${cen}"
    echo -e "${gry}* Troubleshoot? Sometimes it can help to enable to enable 'Link-local only' on your 'RNDIS' network connection ${cen}"
    MAX_WAIT=100
    PING_COUNT=0
    echo -n "[${PING_COUNT}]$(to_bar "${PING_COUNT}")"
    until ping -c1 "${TARGET_HOSTNAME}" >/dev/null 2>&1 || [ ${PING_COUNT} -eq ${MAX_WAIT} ]; do
      sleep $((1))
      PING_COUNT=$((PING_COUNT + 1))
      echo -ne "\e[0K\r[${PING_COUNT}]$(to_bar "${PING_COUNT}")"
    done
    if [[ "${PING_COUNT}" == "${MAX_WAIT}" ]]; then
      speak "Error! I could not reach ${TARGET_HOSTNAME} in time. Please try again"
      echo ""
      echo -e "[${STEP}/${STEPS}] [${red}ERROR${cen}] Could not reach [${yel}${TARGET_HOSTNAME}${cen}] in time"
      exit 6
    fi
    sleep 2
    echo -ne "\e[0K\r[100]$(to_bar "100")"
    echo ""
    speak "I found it!"
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Found [${yel}${TARGET_HOSTNAME}${cen}]"
    sleep 2
  fi

  nextStep
  deleteInFileEcho "$(echo "${TARGET_HOSTNAME}" | awk -F'.' '{print $1}')" ~/.ssh/known_hosts

  nextStep
  speak "Terminal mode is active"
  echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Configuring raspberry pi over terminal [${yel}${TARGET_HOSTNAME}${cen}]"
  if [[ "${1}" == "TERMINAL=true" ]]; then
    ssh -t -o "StrictHostKeyChecking=no" "pi@${TARGET_HOSTNAME}"
    speak "You are a professional!"
    echo -e "${pur}Bye${cen}"
    exit 0
  else
    speak "Don't forget to setup your wifi"
    echo -e "[${STEP}/${STEPS}] [${gre}OK${cen}] Configuring raspberry pi [${yel}${TARGET_HOSTNAME}${cen}]"
    echo -e "${gry}* The default raspberry pi password is [raspberry] ${cen}"
    echo -e "${gry}* (On Pi config) Rename pi hosname (nice to have if you have multiple pi's) [Network Options -> Hostname] ${cen}"
    echo -e "${gry}* (On Pi config) Turn on Wifi (permanent remote access) [Network Options -> Wi-fi] ${cen}"
    echo -e "${gry}* (On Pi config) Raspberry PI enable ssh (permanent remote access) [Interfacing Options -> SSH -> YES -> OK -> FINISH] ${cen}"
    #EOF/Heredoc didn't worked cause of an error on pi like 'tput: unknown terminal "unknown"'
    #Needed one line so you only have tu enter the pi password once'
    ssh -t -o "StrictHostKeyChecking=no" "pi@${TARGET_HOSTNAME}" \
      "(echo none | sudo tee /sys/class/leds/led0/trigger &>/dev/null); (echo 1 | sudo tee /sys/class/leds/led0/brightness &>/dev/null); \
    sudo ZEBRA=true '/usr/bin/env' raspi-config; \
    MAX_WAIT=30; PING_COUNT=0; echo 'Try to reach internet'; \
    until ping -c1 '8.8.8.8' >/dev/null 2>&1 || [ \${PING_COUNT} -eq \${MAX_WAIT} ]; do sleep \$((1)); PING_COUNT=\$((PING_COUNT + 1)); sleep \$((1)); PING_COUNT=\$((PING_COUNT + 1)); done; \
    if [[ \"\${PING_COUNT}\" != \"\${MAX_WAIT}\" ]]; then echo 'Updating pi'; (echo mmc0 | sudo tee /sys/class/leds/led0/trigger &>/dev/null); (echo 0 | sudo tee /sys/class/leds/led0/brightness &>/dev/null); sudo apt-get -y update; sudo apt-get install -y libusb-1.0-0 libudev0 pm-utils; wget https://download.tinkerforge.com/tools/brickd/linux/brickd_linux_latest_armhf.deb; yes | sudo dpkg -i brickd_linux_latest_armhf.deb; rm -rf brickd_linux_latest_armhf.deb; else echo 'No internet connection found. Please connect to wifi and try again later'; fi; \
  "
  fi
  speak "Finised setup"
  echo -e "[${gre}FINISH${cen}] setup"
  showMenu
}

function showMenu() {
  MENU_OPTIONS=()
  #IF PI VOLUME EXISTS
  if [ -n "${1}" ]; then
    MENU_OPTIONS+=("SETUP_SD_CARD")
    echo -e "${gry}Possible sd card found [${PI_VOLUME}]${cen}"
  fi
  MENU_OPTIONS+=("CONFIGURE_PI")
  MENU_OPTIONS+=("CONFIGURE_PI_TERMINAL")
  MENU_OPTIONS+=("EXIT")

  select SELECTED in "${MENU_OPTIONS[@]}"; do
    case $SELECTED in
    SETUP_SD_CARD) action_setup_sd_card "${PI_VOLUME}" ;;
    CONFIGURE_PI) action_configure_pi ;;
    CONFIGURE_PI_TERMINAL) action_configure_pi "TERMINAL=true" ;;
    EXIT)
      speak "See you soon"
      echo -e "${pur}Bye${cen}"
      exit 0
      ;;
    esac
  done
}
PI_VOLUME="$(getPiVolume)"
showMenu "${PI_VOLUME}"
