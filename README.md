# RFM9x

This library provides driver code for HopeRF's RFM95/96/97/98(W) Low-Power Long Range LoRa Technology Transceiver Modules.

# Class Usage

## Constructor: RFM9x(spi, irq[, cs]) 
The constructor takes two required parameters: spi, the spi lines that the chip is connected to, and irq, the hardware pin on the imp 
being used for interrupts from the chip. spi must be pre-configurd before being passed to the constructor. The optional third argument,
cs, is the chip select pin being used. If it is not passed to the constructor, it is assumed that you are using an imp with a
dedicated chip select pin for the spi module you have passed. NOTE: spi must be configured with clock polarity
and clock phase low.
#### Example
```
spiModule <- hardware.spiBCAD;
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | USE_CS_L, 1000);

irq <- hardware.pinXD;

rf <- RFM9x(spiModule, irq);
```

# Class Methods

## init()
The init() method configures several settings to defaults. It sets frequency to 915MHz, bandwidth to 125kHz, spreading factor to 7, 
coding rate to 4/5, implicit header mode off, preamble length to 8, and payload length to 10. It also configures the isr for
interrupts on the irq pin passed to the constructor. Finally, it sets the chip into LoRa mode.
#### Example
```
rf.init();
```

## sendData(data) 
The sendData(data) method sends a data string that is no more than 256 characters. If a previous data string has not finished transmitting, the method will not send the string.
#### Example
```
rf.sendData("hello world!");
```
## setReceiveHandler(handler)
The setReceiveHandler(handler) method takes a function as its parameter. This function should be prepared to take a single
string parameter as its input. It will be called whenever data is received, with the received data passed to it as its parameter

## receiveData()
The receiveData() method puts the module into continuous RX mode. This will allow the RX_DONE flag to be set, meaning that when
valid data is received, the callback passed to setReceiveHandler will be called with the received data as its argument
#### Example
```
function receiveHandler(data) {
  server.log(data);
}
rf.setReceiveHandler(receiveHandler);
rf.receiveData(); // receiveHandler will be called when a valid packet is received
```

## readReg(address)
The readReg(address) method returns the value stored at the register addressed by the passed address parameter
#### Example
```
rf.readReg(RFM9x.RFM9X_REG_HEADER_CNT_VALUE_MSB); // retrieve the MSB of the number of valid headers received since last
// transition into RX mode
```

## writeReg(address, data)
The writeReg(address, data) method writes the data parameter to the register addressed by the address parameter
#### Example
```
local data = 0x84;
rf.writeReg(RFM9x.RFM9X_REG_OP_MODE, data);
```

## maskAllInterrupts() 
The maskAllInterrupts() method will mask all interrupts.
#### Example
```
rf.maskAllInterrupts(); // Now the interrupt pin will not be asserted by the rf module
```

## enableInterrupt(mask)
The enableInterrupt(mask) method will enable the interrupt corresponding to the mask parameter. The mask parameter should be
one of the class constants corresponding to interrupts. These are RX_TIMEOUT, RX_DONE, PAYLOAD_CRC_ERROR, VALID_HEADER, TX_DONE,
CAD_DONE, FHSS_CHANGE_CHANNEL, and CAD_DETECTED.
#### Example
```
rf.enableInterrupt(CAD_DONE);
```

## isDoneSending()
The isDoneSending() method will return whether the last message to be transmitted has finished sending
```
if(rf.isDoneSending()) {
  rf.sendData("hello again!");
}
```

## setters
The following methods are available to set various radio parameters:
- setPayloadLength(len): this method takes a length 0-255 as a parameter, and should only be necessary in implicit header mode
- setImplicitHeaderMode(state): this method takes a boolean indicating whether to operate in implicit header mode
- setPreambleLength(len): this method takes a two byte parameter for the length of the preamble
- setFifoTxBase(start): this method sets the start of Tx data in the FIFO buffer
- setFifoRxBase(start): this method sets the start of Rx data in the FIFO buffer
- setCodingRate(cr): this method sets the coding rate. It takes a parameter which is mapped via a table. The available values are 4/5, 4/6, 4/7,
and 4/8. These should be passed as strings like so: "4/5"
- setRxPayloadCRC(state): this method takes a boolean indicating whether received packet headers indicate CRC being on
- setBandwidth(bw): this method takes sets the bandwidth for the transceiver. It takes a paramter which is mapped via a table.
The available values in kHz are 7.8, 10.4, 15.6, 20.8, 31.25, 41.7, 62.5, 125, 250, 500. These should be passed as strings like
so: "125"
- setMode(mode): this method sets the mode of the chip. The available modes, which are class constants, are SLEEP, STANDBY, FSTX,
TX, FSRX, RXCONTINUOUS, RXSINGLE, and CAD. They should be passed to setMode as its sole parameter
- setSpreadingFactor(sf): this method sets the spreading factor of the chip. Only 6-12 can be passed as parameters
- setMaxPayload(pl): this method sets the maximum payload size.
- setFrequency(freq): this method sets the desired frequency for the chip. See the datasheet for specifics on which frequencies
can be used

#### Examples
```
rf.setPreambleLength(20);

rf.setBandwidth("250");

rf.setSpreadingFactor(11);
```

# License
[license](https://github.com/electricimp/RFM9x/blob/develp/LICENSE)
