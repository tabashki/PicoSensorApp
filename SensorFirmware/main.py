
# This example demonstrates a simple temperature sensor peripheral.
#
# The sensor's local value is updated, and it will notify
# any connected central every second.

import random
import struct
import time
import ubinascii
import dht

from bluetooth import BLE, UUID, FLAG_READ, FLAG_WRITE_NO_RESPONSE, FLAG_NOTIFY, FLAG_INDICATE
from ble_advertising import advertising_payload
from micropython import const
from machine import Pin

_IRQ_CENTRAL_CONNECT = const(1)
_IRQ_CENTRAL_DISCONNECT = const(2)
_IRQ_GATTS_WRITE = const(3)
_IRQ_GATTS_INDICATE_DONE = const(20)

# org.bluetooth.service.environmental_sensing
_ENV_SENSE_UUID = UUID(0x181A)
# org.bluetooth.characteristic.temperature
_TEMP_CHAR = (
    UUID(0x2A6E),
    FLAG_READ | FLAG_NOTIFY | FLAG_INDICATE,
)
# org.bluetooth.characteristic.humidity
_HUMID_CHAR = (
    UUID(0x2A6F),
    FLAG_READ | FLAG_NOTIFY | FLAG_INDICATE,
)
# Custom relay I/O control characteristic
_RELAY_CHAR = (
    UUID('E04E0525-ECBC-4E2C-AAB6-A3EC009506C6'),
    FLAG_READ | FLAG_WRITE_NO_RESPONSE | FLAG_NOTIFY,
)
# Service declaration
_ENV_SENSE_SERVICE = (
    _ENV_SENSE_UUID,
    (_TEMP_CHAR, _HUMID_CHAR, _RELAY_CHAR),
)

# org.bluetooth.characteristic.gap.appearance.xml
_ADV_APPEARANCE_GENERIC_THERMOMETER = const(768)

_DHT_DATA_PIN = Pin(28)
_RELAY1_PIN = Pin(27, Pin.OUT, Pin.PULL_DOWN)
_RELAY2_PIN = Pin(26, Pin.OUT, Pin.PULL_DOWN)

class BLESensor:
    def __init__(self, ble, name=""):
        self._dht_sensor = dht.DHT22(_DHT_DATA_PIN)
        self._ble = ble
        self._ble.active(True)
        self._ble.irq(self._irq)

        ((th, hh, rh),) = self._ble.gatts_register_services((_ENV_SENSE_SERVICE,))
        self._thandle, self._hhandle, self._rhandle = th, hh, rh
        self._connections = set()

        if len(name) == 0:
            name = 'Pi Pico Sensor'
        print('Sensor name: %s' % name)
        self._payload = advertising_payload(
            name=name, services=[_ENV_SENSE_UUID], appearance=_ADV_APPEARANCE_GENERIC_THERMOMETER
        )
        self._advertise()

    def _irq(self, event, data):
        # Track connections so we can send notifications.
        if event == _IRQ_CENTRAL_CONNECT:
            conn_handle, _, _ = data
            self._connections.add(conn_handle)
        elif event == _IRQ_CENTRAL_DISCONNECT:
            conn_handle, _, _ = data
            self._connections.remove(conn_handle)
            # Start advertising again to allow a new connection.
            self._advertise()
        elif event == _IRQ_GATTS_INDICATE_DONE:
            conn_handle, value_handle, status = data
        elif event == _IRQ_GATTS_WRITE:
            conn_handle, attr_handle = data
            if attr_handle == self._rhandle:
                # Relay write recieved
                data = self._ble.gatts_read(attr_handle)
                bits = None
                if len(data) > 0:
                    bits = int(data[0]) & 0x3
                if bits is not None:
                    _RELAY1_PIN.value(bool(bits & 0x1))
                    _RELAY2_PIN.value(bool(bits & 0x2))
                    self._ble.gatts_write(attr_handle, struct.pack('b', bits))
                    self._ble.gatts_notify(conn_handle, attr_handle)
                    

    def _update_i16_value(self, handle, value, notify=False, indicate=False):
        # Write a local value, ready for a central to read.
        self._ble.gatts_write(handle, struct.pack('<h', int(value)))
        if notify or indicate:
            for conn_handle in self._connections:
                if notify:
                    # Notify connected centrals.
                    self._ble.gatts_notify(conn_handle, handle)
                if indicate:
                    # Indicate connected centrals.
                    self._ble.gatts_indicate(conn_handle, handle)

    def _update_temp(self, notify=False, indicate=False):
        temp_deg_c = self._get_temp()
        self._update_i16_value(self._thandle, int(temp_deg_c * 100), notify, indicate)

    def _update_humi(self, notify=False, indicate=False):
        humidity_percent = self._get_humidity()
        self._update_i16_value(self._hhandle, int(humidity_percent * 100), notify, indicate)

    def update_measurements(self):
        self._dht_sensor.measure()
        self._update_temp(notify=True)
        self._update_humi(notify=True)

    def _advertise(self, interval_us=250000):
        self._ble.gap_advertise(interval_us, adv_data=self._payload)

    def _get_temp(self):
        return self._dht_sensor.temperature()
    
    def _get_humidity(self):
        return self._dht_sensor.humidity()
        
def main():
    ble = BLE()
    sensor = BLESensor(ble)

    time.sleep_ms(1000)  # Give the sensor some time to initialize
    led = Pin('LED', Pin.OUT)

    while True:
        sensor.update_measurements()
        led.toggle()
        time.sleep_ms(1000)

if __name__ == '__main__':
    main()