# RFM9x

This library provides driver code for HopeRF’s [RFM95/96/97/98(W)](http://www.hoperf.com/upload/rf/RFM95_96_97_98W.pdf) Low-Power Long-Range (LoRa) transceiver modules.

**To add this library to your project, add** `#require "RFM9x.device.lib.nut:0.1.0"` **to the top of your device code.**

## Class Usage

### Constructor: RFM9x(*spi, intPin[, cs]*) 

The constructor takes the following parameters:

| Parameter | Default | Description |
| --- | --- | --- |
| *spi* | N/A | The imp SPI bus that the RFMx chip is connected to |
| *intPin* | N/A | The imp GPIO pin being used for interrupts from the chip |
| *cs* | Null | The imp chip select pin being used |

The SPI bus must be pre-configured before being passed to the constructor, and must be configured with clock polarity and clock phase low (see the example, below).

If no chip select pin is provided to the constructor, it is assumed that you are using an imp with a dedicated chip select pin for the SPI bus you have passed.

#### Example

```
// Configure for imp005
spiModule <- hardware.spiBCAD;
spiModule.configure(CLOCK_IDLE_LOW | MSB_FIRST | USE_CS_L, 1000);

intPin <- hardware.pinXD;

rf <- RFM9x(spiModule, intPin);
```

## Class Methods

### init()

The *init()* method configures several settings to defaults. It sets frequency to 915MHz, bandwidth to 125kHz, spreading factor to 7, coding rate to 4/5, implicit header mode off, preamble length to 8, and payload length to 10. It also configures the ISR for interrupts on the IRQ pin passed to the constructor. Finally, it sets the chip into LoRa mode.

### sendData(*data[, sendCallback]*) 

The *sendData()* method transmits a string, passed in as *data*, that is no more than 256 characters. If a previous *data* string has not finished transmitting, the method will not send the string. To detect this, you should also provide a callback function, *sendCallback*, which will be called when the data is sent or an error occurs. 

The callback should take two parameters, both strings. The first will contain an error message if error has occurred, or `null` if the transmission was successful. The error message will either be `"data size error"` if the data you tried to send exceeded 256 bytes, or `"could not send new data while sending previous data"` if previous data was still sending when *sendData()* was called. In the latter case, the second parameter will contain the data you tried to send, otherwise it will be `null`.

#### Example

```
function mySendCallback(error, data) {
    if (error == null) {
        // Transmission success
        server.log("Data was successfully sent.");
    } else if (error == "could not send new data while sending previous data") {
        // Could not sent data because other data was still being sent, so try again
        server.error("Data was not sent – will re-send");
        rf.sendData(data, mySendCallback);
    } else {
        server.error("Send failed - data too large");
    }
}

rf.sendData("Hello, World!", mySendCallback);
```

### isSending()

The *isSending()* method will return `true` if the most recently sent message is still transmitting, otherwise `false`.

#### Example

```
if (!rf.isSending()) rf.sendData("Hello again!");
```

### setReceiveHandler(*handler*)

The *setReceiveHandler()* method takes a function as its parameter. This function should be prepared to take a single
string parameter as its input. It will be called whenever data is received, with the received data passed to it as its parameter.

#### Example

```
rf.setReceiveHandler(function(receivedData) {
    server.log("Received message: " + receivedData);
});
```

### receiveData()

The *receiveData()* method puts the module into continuous RX mode. This will allow the *RX_DONE* flag, which indicates when valid data is received, to be set and the callback passed to *setReceiveHandler()* to be called with the received data as its argument. 

**Note** When the radio is sending it cannot receive data. Therefore if *sendData()* is called after *receiveData()*, the module will no longer be in continuous RX mode.

#### Example

```
function receiveHandler(data) {
    server.log(data);
}

// Register the handler for received data
rf.setReceiveHandler(receiveHandler);

// Put the radio into receive mode
rf.receiveData(); 
```

## enableInterrupt(*trigger*)

The *enableInterrupt()* method will enable the interrupt corresponding to the *trigger* parameter. The *trigger* indicates the event on which the interrupt will be triggered and should be one of the following constants in the *RFM9X_FLAGS* enumeration: *RX_TIMEOUT*, *RX_DONE*, *PAYLOAD_CRC_ERROR*, *VALID_HEADER*, *TX_DONE*, *CAD_DONE*, *FHSS_CHANGE_CHANNEL* or *CAD_DETECTED*.

#### Example

```
rf.enableInterrupt(RFM9X_FLAGS.CAD_DONE);
```

## disableInterrupt(*trigger*)

The *disableInterrupt()* method will disable the interrupt corresponding to the *trigger* parameter. The *trigger* indicates the event on which the interrupt was previously set be triggered and should be one of the following constants in the *RFM9X_FLAGS* enumeration: *RX_TIMEOUT*, *RX_DONE*, *PAYLOAD_CRC_ERROR*, *VALID_HEADER*, *TX_DONE*, *CAD_DONE*, *FHSS_CHANGE_CHANNEL* or *CAD_DETECTED*.

#### Example

```
rf.disableInterrupt(RFM9X_FLAGS.CAD_DONE);
```

## maskAllInterrupts()

The *maskAllInterrupts()* method will prevent the interrupt pin from being asserted, but does not clear any interrupts you have set.

#### Example

```
// Set the interrupt pin not to be asserted by the RF module
rf.maskAllInterrupts(); 
```

## Radio Parameter Setter Methods

### setPayloadLength(*length*)

The *setPayloadLength()* method takes an integer between 0 and 255, and should only be necessary in implicit header mode. By default, this is 0x01.

#### Example

```
rf.setPayloadLength(5);
```

### setImplicitHeaderMode(*state*) 

The *setImplicitHeaderMode()* method takes a boolean indicating whether to operate in implicit header mode. By default, this is `false`.

#### Example

```
rf.setImplicitHeaderMode(true);
```

### setPreambleLength(*length*) 

The *setPreambleLength()* method takes an integer between 0 and 65535 to indicate the length of the preamble. By default, this is 8.

#### Example

```
rf.setPreambleLength(6);
```

### setFifoTxBase(*start*)

The *setFifoTxBase()* method sets the start of TX data in the FIFO buffer. By default, this is 0x00, ie. the actual start of the buffer. 

The FIFO buffer is a shared buffer for sending and receiving. Because the radio cannot receive and transmit simultaneously, this library sets the TX pointer to 0 when transmitting so that transmissions can use the full length of the FIFO buffer (256 bytes). If desired, this method could be used along with other code to use part of the buffer for received data and another part for transmitted data.

#### Example

```
// Set the TX FIFO to half-way into the buffer
rf.setFifoTxBase(0x80);
```

### setFifoRxBase(*start*)

The *setFifoRxBase()* method sets the start of RX data in the FIFO buffer. By default, this is 0x00, ie. the actual start of the buffer. 

The FIFO buffer is a shared buffer for sending and receiving. Because the radio cannot receive and transmit simultaneously, this library sets the RX pointer to 0 when receiving so that received data can be placed across the full length of the FIFO buffer (256 bytes). If desired, this method could be used along with other code to use part of the buffer for received data and another part for transmitted data.

#### Example

```
// Set the RX FIFO to half-way into the buffer
rf.setFifoRxBase(0x80);
```

### setCodingRate(*rate*)

The *setCodingRate()* method sets the coding rate. It takes a string value. The available values are `"4/5"`, `"4/6"`, `"4/7"` and `"4/8"`. By default, this is `"4/5"`.

#### Example

```
rf.setCodingRate("4/6");
```

### setRxPayloadCRC(*state*)

The *setRxPayloadCRC()* method takes a boolean indicating whether received packet headers indicate that CRC is active. There is not a default value.

#### Example

```
rf.setRxPayloadCRC(true);
``` 

### setBandwidth(*bandwidth*)

The *setBandwidth()* method takes sets the bandwidth in kHz for the transceiver. The value is a string and the available values are: `"7.8"`, `"10.4"`, `"15.6"`, `"20.8"`, `"31.25"`, `"41.7"`, `"62.5"`, `"125"`, `"250"` and `"500"`. By default, this is 125kHz.

#### Example

```
rf.setBandwidth("250");
```

### setMode(*mode*)

The *setMode()* method sets the current operating mode of the chip. The available modes, which are class constants, are: *RFM9X_SLEEP*, *RFM9X_STANDBY*, *RFM9X_FSTX*, *RFM9X_TX*, *RFM9X_FSRX*, *RFM9X_RXCONTINUOUS*, *RFM9X_RXSINGLE* and *RFM9X_CAD*. By default, this is *RFM9X_STANDBY*.

#### Example

```
rf.setMode(RFM9X_RXSINGLE);
```

### setSpreadingFactor(*factor*)

The *setSpreadingFactor()* method sets the spreading factor of the chip. Only values between 6 and 12 inclusive can be passed as parameters.

#### Example

```
rf.setSpreadingFactor(8);
```

### setMaxPayload(*size*)

The *setMaxPayload()* method sets the maximum payload size in bytes. The default value is 256 bytes.

#### Example

```
rf.setMaxPayload(0x90);
```

### setFrequency(*frequency*)

The *setFrequency()* method sets the desired frequency (in Hertz) for the chip. Please see [the datasheet](http://www.hoperf.com/upload/rf/RFM95_96_97_98W.pdf) for details of which frequencies can be used.

#### Example

```
rf.setFrequency(915000000);
```

# License

The RFM9X library is licensed under MIT [license](./LICENSE)
