Bootrom controller
=================

This module is a controller for the [25CSM04 EEPROM device](https://ww1.microchip.com/downloads/en/DeviceDoc/25CSM04-4-Mbit-SPI-Serial-EEPROM-With-128-Bit-Serial-Number-and-Enhanced-Write-Protection-20005817C.pdf). The controller is really simple and only implements read operations on the device. To explain the implementation of this RTL module, we will start with its external interface and go deeper, in de sub-modules later.

[img_brom_ctrl_interface]: assets/brom_ctrl_interface.png "Bootrom Controller" 
![img_brom_ctrl_interface][img_brom_ctrl_interface] 

## Interface
We can split the interface in two parts, first the signals that goes/come to/from the core, and then, the dignals that goes/come to/from the EEPROM device.

**Controller - core interface:**

The controller-core interface is straightforward. It consists of a 24-bit address bus with its valid request bit and a 32-bit data bus with its valid response bit. The `ready_o` signal tells us if the controller can receive new requests or, on the contrary, is processing a request.

| name          | type   | #bits | description |
|---------------|--------|-------|-------------|
| clk_i         | input  | 1     |             |
| rstn_i        | input  | 1     |             |
| req_address_i | input  | 24    |             |
| req_valid_i   | input  | 1     |             |
| resp_data_o   | output | 32    |             |
| resp_valid_o  | output | 1     |             |
| ready_o       | output | 1     |             |

**Controller - 25CSM04 interface:**

The controller-25CSM04 interface is a classic SPI interface: miso, mosi, an SPI clock and the chip select bit (cs)
| name          | type   | #bits | description |
|---------------|--------|-------|-------------|
| mi_i          | input  | 1     |             |
| mo_o          | output | 1     |             |
| sclk_o        | output | 1     |             |
| cs_n_o        | output | 1     |             |
