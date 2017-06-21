/***
*	Example using the HopeRF RFM9x radio transceiver module and the imp005. This device
*	code transmits data using the module.
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