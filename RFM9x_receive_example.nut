#require "RFM9x.device.nut:0.1.0"
/***
MIT License

Copyright 2017 Electric Imp

SPDX-License-Identifier: MIT

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
***/   

/***
*	Example using the HopeRF RFM9x radio transceiver module and the imp005. This device
*	code receives data using the module.
***/

// Simple callback for receiving data
function logData(data) {
	server.log(data);
}

// You MUST configure and pass a spi module to the constructor
spi <- hardware.spiBCAD;
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | USE_CS_L, 1000);

// You MUST pass an interrupt pin (that is connected to the RFM9x's interrupt output)
// to the constructor
irq <- hardware.pinXD;

// Note that the imp005 has dedicated chip select pins for its spi modules. This example uses
// them. For modules without dedicated chip select pins, you MUST configure and
// pass them to the constructor
rf <- RFM9x(spi, irq);

rf.init();

rf.setReceiveHandler(logData);

// Configure the radio to continuous RX mode so that it is listening for data
rf.receiveData();