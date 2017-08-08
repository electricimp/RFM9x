// MIT License
//
// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE. 

const RFM9X_FIFO = 0x00;

// SPI masks
const RFM9X_WRITE_MASK = 0x80;
const RFM9X_READ_MASK = 0x00;

const RFM9X_REG_OP_MODE = 0x01;
const RFM9X_REG_FREQUENCY_HIGH = 0x06; // MSB (3 bytes long, contiguous)
const RFM9X_REG_PA_CONFIG = 0x09;
const RFM9X_REG_PA_RAMP = 0x0A;
const RFM9X_REG_OCP = 0x0B;
const RFM9X_REG_LNA = 0x0C;
const RFM9X_REG_FIFO_ADDR_PTR = 0x0D;
const RFM9X_REG_FIFO_TX_BASE_ADDR = 0x0E; // write base address in RFM9X_FIFO data buffer
const RFM9X_REG_FIFO_RX_BASE_ADDR = 0x0F; // read base address in RFM9X_FIFO data buffer
const RFM9X_REG_FIFO_RX_CURRENT_ADDR = 0x10; // Start address of last packet received

const RFM9X_REG_IRQ_FLAGS_MASK = 0x11;

// IRQ flags
const RFM9X_REG_IRQ_FLAGS = 0x12;

// Number of bytes in most recent payload
const RFM9X_REG_RX_N_BYTES = 0x13; 

const RFM9X_REG_RX_HEADER_CNT_VALUE_MSB = 0x14;
const RFM9X_REG_RX_HEADER_CNT_VALUE_LSB = 0x15;
const RFM9X_REG_RX_PACKET_CNT_VALUE_MSB = 0x16;
const RFM9X_REG_RX_PACKET_CNT_VALUE_LSB = 0x17;

const RFM9X_REG_MODEL_STAT = 0x18;
const RFM9X_REG_PKT_SNR_VALUE = 0x19;
const RFM9X_REG_PKT_RSSI_VALUE = 0x1A;
const RFM9X_REG_RSSI_VALUE = 0x1B;
const RFM9X_REG_HOP_CHANNEL = 0x1C;
const RFM9X_REG_MODEM_CONFIG1 = 0x1D;
const RFM9X_REG_MODEM_CONFIG2 = 0x1E;
const RFM9X_REG_MODEM_CONFIG3 = 0x26;
const RFM9X_REG_SYMB_TIMEOUT_LSB = 0x1F;

const RFM9X_REG_PREAMBLE_MSB = 0x20;
const RFM9X_REG_PREAMBLE_LSB = 0x21;
const RFM9X_REG_PAYLOAD_LENGTH = 0x22;
const RFM9X_REG_MAX_PAYLOAD_LENGTH = 0x23;
const RFM9X_REG_HOP_PERIOD = 0x24;
const RFM9X_REG_FIFO_RX_BYTE_ADDR = 0x25;

// DIO mappings are used for interrupts
const RFM9X_REG_DIO_MAPPING1 = 0x40;
const RFM9X_REG_DIO_MAPPING2 = 0x41;
const RFM9X_REG_VERSION = 0x42;
const RFM9X_REG_TCXO = 0x4B;

// Default init constants
const RFM9X_DEFAULT_FREQUENCY = 915000000;
const RFM9X_DEFAULT_BANDWIDTH = "125";
const RFM9X_DEFAULT_SF = 7;
const RFM9X_DEFAULT_CODING_RATE = "4/5";
const RFM9X_DEFAULT_IMPLICIT_HEADER_MODE = 0;
const RFM9X_DEFAULT_PREAMBLE_LENGTH = 8;

// f_RF = ((X_OSC) * Fr_f ) / (2^19). Resolution is 61.035 Hz if X_OSC = 32MHz
const RFM9X_FREQ_STEP = 61.035;

// LoRa Mode
const RFM9X_CONFIG_BYTE = 0x80; 

// Interrupt flags
enum RFM9X_FLAGS {
    CAD_DETECTED,
    FHSS_CHANGE_CHANNEL,
    CAD_DONE,
    TX_DONE,
    VALID_HEADER,
    PAYLOAD_CRC_ERROR,
    RX_DONE,
    RX_TIMEOUT
};

// Operating modes
const RFM9X_SLEEP = 0x00;
const RFM9X_STANDBY = 0x01;
const RFM9X_FSTX = 0x02;
const RFM9X_TX = 0x03;
const RFM9X_FSRX = 0x04;
const RFM9X_RXCONTINUOUS = 0x05;
const RFM9X_RXSINGLE = 0x06;
const RFM9X_CAD = 0x07;


class RFM9x {
    static VERSION = "0.1.0";

    // -------------------- Some Tables --------------------------- //
    
    // This table maps bandwidth strings (in kHz) to the values which go in the 
    // corresponding register
    static BWTABLE = {
        "7.8" : 0x00,
        "10.4" : 0x01,
        "15.6" : 0x02,
        "20.8" : 0x03,
        "31.25": 0x04,
        "41.7": 0x05,
        "62.5": 0x06,
        "125": 0x07,
        "250" : 0x08,
        "500": 0x09
    };
    
    // This table maps coding rate strings to the values which go in the corresponding
    // register
    static CRTABLE = {
        "4/5": 0x01,
        "4/6": 0x02,
        "4/7": 0x03,
        "4/8": 0x04
    };

    _spiModule = null;
    _cs = null;
    _irqPin = null;
    _receiveHandler = null;
    _isSending = false;
    _error = false;    
    _sendcb = null;
    
    constructor(spi, intPin, cs=null) {
        // Assume spi is already initialized, assume cs is already initialized
        _spiModule = spi;
        _irqPin = intPin;
        _cs = cs;
        _cs.configure(DIGITAL_OUT, 1);
    }
    
    // Set radio default settings, configure an interrupt service routine on
    // the interrupt pin passed to the constructor, and set into LoRa mode
    function init() {
        // need to do this to go into LoRa mode
        setMode(RFM9X_SLEEP); 
        
        // Defaults
        setFrequency(RFM9X_DEFAULT_FREQUENCY);
        setBandwidth(RFM9X_DEFAULT_BANDWIDTH);
        setSpreadingFactor(RFM9X_DEFAULT_SF);
        setCodingRate(RFM9X_DEFAULT_CODING_RATE);
        setImplicitHeaderMode(RFM9X_DEFAULT_IMPLICIT_HEADER_MODE);
        setPreambleLength(RFM9X_DEFAULT_PREAMBLE_LENGTH);

        _configISR();
        
        _setInLoRaMode();

    }
    
    // Call this method to send data. Data must be a string less than 256 characters
    function sendData(data, sendcb=null) {
        local len = data.len();

        // Ensure that the data string is not larger than the fifo buffer
        if (len > 0x100) {
            _sendcb("data size error", null);
            return;
        }

        if (!_isSending) {
            setMode(RFM9X_STANDBY);
            _writeReg(RFM9X_REG_DIO_MAPPING1, 0x40);
            setFifoTxBase(0x00);
            _writeReg(RFM9X_REG_FIFO_ADDR_PTR, 0x00);

            // Write the data here
            _writeToTXBuffer(data, len);
            
            _writeReg(RFM9X_REG_PAYLOAD_LENGTH, len);
            setMode(RFM9X_FSTX);
            _isSending = true;
            setMode(RFM9X_TX);
        } else {
            _sendcb = sendcb;
            if (_sendcb != null) _sendcb("could not send new data while still sending previous data", data);
        }
        
    }
    
    // Call this method to start listening for packets
    function receiveData() {
        setMode(RFM9X_STANDBY);
        _writeReg(RFM9X_REG_FIFO_ADDR_PTR, 0x00);
        _writeReg(RFM9X_REG_DIO_MAPPING1, 0x00);
        setMode(RFM9X_FSRX);
        rf.setMode(RFM9X_RXCONTINUOUS);
    }
    
    // Set the payload length of packets
    function setPayloadLength(len) {
        _writeReg(RFM9X_REG_PAYLOAD_LENGTH, len);
    }
    
    // Sets the radio into implicit header mode if true, explicit header mode if
    // false. In implicit header mode, the header is removed from the packet in
    // order to reduce transmission time. In this case, the payload length, 
    // error coding rate and prsence of the payload CRC must be manually configured
    // manually on both sides of the radio link (must be known in advance)
    function setImplicitHeaderMode(state) {
        local cur = _readReg(RFM9X_REG_MODEM_CONFIG1);
        _writeReg(RFM9X_REG_MODEM_CONFIG1, (cur & 0xfe) | (state ? 1 : 0));
    }
    
    // Sets the length of packet preambles
    function setPreambleLength(len) {
        _writeReg(RFM9X_REG_PREAMBLE_MSB, (len >>8) & 0xff);
        _writeReg(RFM9X_REG_PREAMBLE_LSB, len & 0xff);
    }
    
    // Sets the start pointer of TX data in FIFO
    function setFifoTxBase(start) {
        _writeReg(RFM9X_REG_FIFO_TX_BASE_ADDR, start & 0xff);
    }
    
    // Sets the start pointer of RX data in FIFO
    function setFifoRxBase(start) {
        _writeReg(RFM9X_REG_FIFO_RX_BASE_ADDR, start & 0xff);
    }
    
    // Sets the coding rate
    function setCodingRate(cr) {
        local cur = _readReg(RFM9X_REG_MODEM_CONFIG1);
        local clear = cur & 0xf1; // exclude bits 3-1
        _writeReg(RFM9X_REG_MODEM_CONFIG1, clear | (CRTABLE[cr] << 1));
    }
    
    // Enable RX payload CRC
    function setRxPayloadCRC(state) {
        local current = _readReg(RFM9X_REG_MODEM_CONFIG2);
        _writeReg(RFM9X_REG_MODEM_CONFIG2, (current & 0xfb) | (state ? 0x04 : 0x00));
    }
    
    // Sets the bandwidth of the radio
    function setBandwidth(bw) {
        local current = _readReg(RFM9X_REG_MODEM_CONFIG1);
        _writeReg(RFM9X_REG_MODEM_CONFIG1, BWTABLE[bw] << 4 | (current & 0x0f));
    }
    
    // Sets the mode of the radio. Options are constants: SLEEP, STANDBY, FSTX,
    // TX, FSRX, RXCONTINUOUS, RXSINGLE, CAD
    function setMode(mode) {
        local current = _readReg(RFM9X_REG_OP_MODE);
        _writeReg(RFM9X_REG_OP_MODE, mode | (current & 0xf8));
    }
        
    // Clear all interrupt flags
    function clearInterrupts() {
        _writeReg(RFM9X_REG_IRQ_FLAGS, 0xff);
    }
    
    // Mask all interrupts. Calling this method will prevent the interrupt
    // pin from being asserted
    function maskAllInterrupts() {
        _writeReg(RFM9X_REG_IRQ_FLAGS_MASK, 0xff);
    }
    
    // Enable a specific interrupt. Avaliable interrupts are in
    // RFM9X_FLAGS
    function enableInterrupt(bitnumber) {
        local currentInterrupts = _readReg(RFM9X_REG_IRQ_FLAGS);
        // Mask the interrupt by writing high, therefore enable by writing low
        local newInterrupts = currentInterrupts & (~ (1 << bitnumber));
        _writeReg(RFM9X_REG_IRQ_FLAGS_MASK, newInterrupts);
    }

    // Disable a specific interrupt. Available interrupts are in
    // RFM9X_FLAGS 
    function disableInterrupt(bitnumber) {
        local currentInterrupts = _readReg(RFM9X_REG_IRQ_FLAGS);
        // Mask the interrupt by writing high
        local newInterrupts = currentInterrupts | (1 << bitnumber);
        _writeReg(RFM9X_REG_IRQ_FLAGS, newInterrupts);
    }

    // Sets the max payload size of the FIFO buffer
    function setMaxPayload(pl) {
        pl = pl & 0xff;
        _writeReg(RFM9X_REG_MAX_PAYLOAD_LENGTH, pl);
    }
    
    // Sets the spreading factor of the radio
    function setSpreadingFactor(sf) {
        _writeReg(RFM9X_REG_MODEM_CONFIG2, (sf & 0x0f) << 4);
    }
    
    // Sets the transmission frequency of the radio
    function setFrequency(freq) {
        setMode(RFM9X_SLEEP);
        local reg_freq = (freq/RFM9X_FREQ_STEP).tointeger();
        local freq_blob = blob(4); // big-endian blob
        freq_blob[0] = RFM9X_REG_FREQUENCY_HIGH | RFM9X_WRITE_MASK;
        freq_blob[1] = (reg_freq >> 16) & 0xFF;
        freq_blob[2] = (reg_freq >> 8) & 0xFF;
        freq_blob[3] = (reg_freq) & 0xFF;
        
        _csLow();
        _spiModule.writeread(freq_blob);
        _csHigh();
    }

    // Sets the receive handler. The receive handler should take two 
    // parameters: an error message and the received data. The error message
    // will either be "error" or "valid". If the message is "error", the
    // received data parameter will be passed as null. 
    function setReceiveHandler(handler) {
        _receiveHandler = handler;
    }

    // Returns whether the last send operation is ongoing
    function isSending() {
        return _isSending;
    }
    
    function _setInLoRaMode() {
       _writeReg(RFM9X_REG_OP_MODE, RFM9X_CONFIG_BYTE);
    }

    function _configISR() {
        if (_irqPin) {
            _irqPin.configure(DIGITAL_IN_PULLDOWN, _interruptServiceRoutine.bindenv(this));
        } else {
            throw "interrupt pin passed to constructor is invalid";
        }
    }

    function _interruptServiceRoutine() {
        // Active high
        if (_irqPin.read()) {
            local read = _readReg(RFM9X_REG_IRQ_FLAGS);
            if (read & (1 << RFM9X_FLAGS.PAYLOAD_CRC_ERROR)) {
                _error = true;
                _receive("payload crc error", null);
            } else if (read & (1 << RFM9X_FLAGS.TX_DONE)) {
                _isSending = false;
                _sendcb(null, "done");
            } else if (read == ((1 << RFM9X_FLAGS.RX_DONE) | (1 << RFM9X_FLAGS.VALID_HEADER))) {
                _receive(null, _readFromRXBuffer());
            }
            
            clearInterrupts();
        }
    }

    function _receive(error, data) {
        _receiveHandler && _receiveHandler(error, data);
    }
    
    function _writeToTXBuffer(data, len) {
        local write = blob(len + 1);
        write[0] = (RFM9X_FIFO | RFM9X_WRITE_MASK);
        for(local i = 0; i < len; ++i) {
            write[i+1] = data[i];
        }
        _csLow();
        _spiModule.writeread(write);
        _csHigh();
    }

    function _readFromRXBuffer() {
        // To retrieve:
        // 1. Read Fifo num bytes
        // 2. Read RegRxDataAddr
        // 3. Set FifoPtrAddr to FifoRxCurrentAddr, 
        // Read RegFifo address Fifo num bytes times
        local numBytes = _readReg(RFM9X_REG_RX_N_BYTES);
        local fifoRXPointer = _readReg(RFM9X_REG_FIFO_RX_CURRENT_ADDR);
        _writeReg(RFM9X_REG_FIFO_ADDR_PTR, fifoRXPointer);
        local b = blob(numBytes);
        local fifo = blob(1);
        fifo[0] = RFM9X_FIFO | RFM9X_READ_MASK;
        _csLow();
        // initiate RFM9X_FIFO read
        _spiModule.writeread(fifo);
        local read = _spiModule.writeread(b);
        _csHigh();
        clearInterrupts();
        return read;
    }

    function _csLow() {
        if (_cs != null) {
            _cs.write(0);
        } else {
            _spiModule.chipselect(1);
        }
    }
    
    function _csHigh() {
        if (_cs != null) {
            _cs.write(1);
        } else {
            _spiModule.chipselect(0);
        }
    }
    
    function _writeReg(address, data) {
        local b = blob();
        b.writen(address | RFM9X_WRITE_MASK, 'b');
        b.writen(data, 'b');
        _csLow();
        _spiModule.writeread(b);
        _csHigh();
    }
    
    function _readReg(address) {
        local b = blob(2);
        b[0] = address;
        _csLow();
        local data = _spiModule.writeread(b);
        _csHigh();
        return data[1];
    }
}