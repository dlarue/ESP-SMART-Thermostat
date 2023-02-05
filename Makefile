#
# Usage: make filesystem.bin flash-fs
# ToDo: 
#  1) figure out why build doesn't compile like the IDE does and instead causes reboot loop
#  2) fix makefile so hardcoded vars like BUILD_SPIFFS_START_HEX, BUILD_SPIFFS_SIZE_HEX and BUILD_SPIFFS_SIZE get computed 
sketch      := ESP32-SMART-Thermostat.ino
CORE        :=esp32:esp32
# Flashing on  an "ESP32 Dev Module" board
boardconfig :="${CORE}:esp32"

TOOL_PATH=~/.arduino15/packages/esp32/tools/mkspiffs/0.2.3
ARDUINO_PATH=~/Projects/Arduino/arduino-ide_nightly-20230129_Linux_64bit/resources/app/node_modules/arduino-ide-extension/build/
ARDUINO_CLI ?= $(ARDUINO_PATH)/arduino-cli
MKSPIFFS    ?= $(TOOL_PATH)/mkspiffs
BC          ?= bc

PARTITION_TABLE=~/.arduino15/packages/esp32/hardware/esp32/2.0.5/tools/partitions/default.csv

DEVICE :=/dev/ttyUSB1

.PHONY: build
build:
	$(ARDUINO_CLI) compile --verbose --fqbn $(boardconfig) $(sketch)

.PHONY: flash
flash:
	$(ARDUINO_CLI) upload --verbose -p ${DEVICE} --fqbn ${boardconfig} ${sketch} 

.PHONY: filesystem.bin
.ONESHELL:
filesystem.bin:
	PROPS=$$($(ARDUINO_CLI) compile --fqbn $(boardconfig) --show-properties)
	BUILD_SPIFFS_BLOCKSIZE=4096
	BUILD_SPIFFS_PAGESIZE=256
	BUILD_SPIFFS_START_HEX=$$(cat ${PARTITION_TABLE} | grep "^spiffs"|cut -d"," -f4 | xargs)
	BUILD_SPIFFS_START_HEX=`cat $(PARTITION_TABLE)`
	BUILD_SPIFFS_START_HEX="0x290000"
	BUILD_SPIFFS_START=$$(echo "ibase=16;$${BUILD_SPIFFS_START_HEX:2}"|bc -q)
	BUILD_SPIFFS_START=0
	echo "BUILD_SPIFFS_START $$BUILD_SPIFFS_START_HEX ($$BUILD_SPIFFS_START)"
	BUILD_SPIFFS_SIZE_HEX=$$(cat ${PARTITION_TABLE} | grep "^spiffs"|cut -d, -f5 | xargs)
	BUILD_SPIFFS_SIZE_HEX="0x170000"
	BUILD_SPIFFS_SIZE=$$(echo "ibase=16;$${BUILD_SPIFFS_SIZE_HEX:2}"|bc -q)
	BUILD_SPIFFS_SIZE=1507328
	echo "BUILD_SPIFFS_SIZE  $$BUILD_SPIFFS_SIZE_HEX ($$BUILD_SPIFFS_SIZE)"
#	echo 'DJL-$(MKSPIFFS) -c data --page ${BUILD_SPIFFS_PAGESIZE} --block ${BUILD_SPIFFS_BLOCKSIZE} --size ${BUILD_SPIFFS_SIZE} $@'
	$(MKSPIFFS) -c data --page $$BUILD_SPIFFS_PAGESIZE --block $$BUILD_SPIFFS_BLOCKSIZE --size $$BUILD_SPIFFS_SIZE $@

.PHONY: flash-fs
.ONESHELL:
flash-fs: filesystem.bin
	BUILD_SPIFFS_START_HEX=$$(cat ${PARTITION_TABLE} | grep "^spiffs"|cut -d, -f4 | xargs)
	python ~/.arduino15/packages/esp32/tools/esptool_py/4.2.1/esptool.py --chip esp32 \
	  --port ${DEVICE} \
	  --baud 460800 \
	  --before default_reset \
	  --after hard_reset \
	  write_flash $${BUILD_SPIFFS_START_HEX} filesystem.bin


.PHONY: clean
clean:
	rm -rf build
	rm -f filesystem.bin
