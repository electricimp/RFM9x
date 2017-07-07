# RFM9x

This library provides driver code for HopeRF's RFM95/96/97/98(W) Low-Power Long Range LoRa Technology Transceiver Modules.

# Class Usage

## Constructor: RFM9x(spi, intPin[, cs]) 
The constructor takes two required parameters: *spi*, the spi lines that the chip is connected to, and *intPin*, the hardware pin on the imp 
being used for interrupts from the chip. spi must be pre-configurd before being passed to the constructor. The optional third argument,
*cs*, is the chip select pin being used. If it is not passed to the constructor, it is assumed that you are using an imp with a
dedicated chip select pin for the spi module you have passed. NOTE: *spi* must be configured with clock polarity
and clock phase low.
#### Example
```
spiModule <- hardware.spiBCAD;
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | USE_CS_L, 1000);

intPin <- hardware.pinXD;

rf <- RFM9x(spiModule, intPin);
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
The sendData(*data*) method sends a data string that is no more than 256 characters. If a previous data string has not finished transmitting, the method will not send the string.
#### Example
```
rf.sendData("hello world!");
```

## isDoneSending()
The isDoneSending() method will return whether the last message to be transmitted has finished sending
```
if(rf.isDoneSending()) {
  rf.sendData("hello again!");
}
```

## setReceiveHandler(handler)
The setReceiveHandler(*handler*) method takes a function as its parameter. This function should be prepared to take a single
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

## maskAllInterrupts() 
The maskAllInterrupts() method will mask all interrupts.
#### Example
```
rf.maskAllInterrupts(); // Now the interrupt pin will not be asserted by the rf module
```

## enableInterrupt(mask)
The enableInterrupt(*mask*) method will enable the interrupt corresponding to the *mask* parameter. The *mask* parameter should be
one of the constants in the RFM9X_FLAGS enum variable corresponding to interrupts. These are RX_TIMEOUT, RX_DONE, PAYLOAD_CRC_ERROR, VALID_HEADER, TX_DONE,
CAD_DONE, FHSS_CHANGE_CHANNEL, and CAD_DETECTED.
#### Example
```
rf.enableInterrupt(RFM9X_FLAGS.CAD_DONE);
```

## setters
The following methods are available to set various radio parameters:

### setPayloadLength(len)
This method takes a length 0-255 as a parameter, and should only be necessary in implicit header mode. By default, this is 0x01

#### Example
```
rf.setPayloadLength(5);
```

### setImplicitHeaderMode(state) 
This method takes a boolean indicating whether to operate in implicit header mode. By default, this is false

#### Example
```
rf.setImplicitHeaderMode(true);
```

### setPreambleLength(len) 
This method takes a two byte parameter for the length of the preamble. By default, this is 8

#### Example
```
rf.setPreambleLength(6);
```

### setFifoTxBase(start) 
This method sets the start of Tx data in the FIFO buffer. Bby default, this is 0x00

#### Example
```
rf.setFifoTxBase(0x7f);
```

### setFifoRxBase(start) 
This method sets the start of Rx data in the FIFO buffer. By default, this is 0x00

#### Example
```
rf.setFifoRxBase(0x00);
```

### setCodingRate(cr) 
This method sets the coding rate. It takes a parameter which is mapped via a table. The available values are 4/5, 4/6, 4/7,
and 4/8. These should be passed as strings like so: "4/5". By default, this is 4/5

#### Example
```
rf.setCodingRate("4/6");
```

### setRxPayloadCRC(state) 
This method takes a boolean indicating whether received packet headers indicate CRC being on. There is not a default value.

#### Example
```
rf.setRxPayloadCRC(true);
``` 

### setBandwidth(bw)
This method takes sets the bandwidth for the transceiver. It takes a parameter which is mapped via a table. By default, this is 125kHz.
The available values in kHz are 7.8, 10.4, 15.6, 20.8, 31.25, 41.7, 62.5, 125, 250, 500. These should be passed as strings like so: "125"

#### Example
```
rf.setBandwidth("250");
```

### setMode(mode) 
This method sets the *mode* of the chip. The available modes, which are class constants, are RFM9X_SLEEP, RFM9X_STANDBY, RFM9X_FSTX,
RFM9X_TX, RFM9X_FSRX, RFM9X_RXCONTINUOUS, RFM9X_RXSINGLE, and RFM9X_CAD. They should be passed to setMode as its sole parameter. By default, this is STANDBY

#### Example
```
rf.setMode(RFM9X_RXSINGLE);
```

### setSpreadingFactor(sf)
This method sets the spreading factor of the chip. Only 6-12 can be passed as parameters

#### Example
```
rf.setSpreadingFactor(8);
```

### setMaxPayload(pl)
This method sets the maximum payload size. The default value is 0xff

#### Example
```
rf.setMaxPayload(0x90);
```

### setFrequency(freq)
This method sets the desired frequency for the chip. See the datasheet for specifics on which frequencies can be used

#### Example
```
rf.setFrequency(915000000);
```


# License
The RFM9X library is licensed under MIT [license](https://github.com/electricimp/RFM9x/blob/develp/LICENSE)
