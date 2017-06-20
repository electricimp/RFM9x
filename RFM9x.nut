class RFM9x {
    
    _spi = null;
    _cs = null;
    _irqPin = null;
    _receiveHandler = null;
    _sendFinished = true;
    _error = false;

    static FIFO = 0x00;
    
    // SPI masks
    static WRITE_MASK = 0x80;
    static READ_MASK = 0x00;
    
    static REG_OP_MODE = 0x01;
    // f_RF = ((X_OSC) * Fr_f ) / (2^19). Resolution is 61.035 Hz if X_OSC = 32MHz
    static REG_FREQUENCY_HIGH = 0x06; // MSB (3 bytes long, contiguous)
    static X_OSC = 0x1E84800; // 32 MHz
    static FREQ_STEP = 61.035;
    
    // LoRa Mode
    static CONFIG_BYTE = 0x80; 
    
    // CPHA and CPOL must be 0 
    
    static REG_PA_CONFIG = 0x09;
    static REG_PA_RAMP = 0x0A;
    static REG_OCP = 0x0B;
    static REG_LNA = 0x0C;
    static REG_FIFO_ADDR_PTR = 0x0D;
    static REG_FIFO_TX_BASE_ADDR = 0x0E; // write base address in FIFO data buffer
    static REG_FIFO_RX_BASE_ADDR = 0x0F; // read base address in FIFO data buffer
    static REG_FIFO_RX_CURRENT_ADDR = 0x10; // Start address of last packet received
    
    static REG_IRQ_FLAGS_MASK = 0x11;
    
    // Interrupt Masks AND flags
    static RX_TIMEOUT = 7;
    static RX_DONE = 6;
    static PAYLOAD_CRC_ERROR = 5;
    static VALID_HEADER = 4;
    static TX_DONE = 3;
    static CAD_DONE = 2;
    static FHSS_CHANGE_CHANNEL = 1;
    static CAD_DETECTED = 0;
    
    // IRQ
    static REG_IRQ_FLAGS = 0x12;
    
    static REG_RX_N_BYTES = 0x13; // number of bytes in most recent payload
    
    static REG_RX_HEADER_CNT_VALUE_MSB = 0x14;
    static REG_RX_HEADER_CNT_VALUE_LSB = 0x15;
    static REG_RX_PACKET_CNT_VALUE_MSB = 0x16;
    static REG_RX_PACKET_CNT_VALUE_LSB = 0x17;
    
    static REG_MODEL_STAT = 0x18;
    static REG_PKT_SNR_VALUE = 0x19;
    static REG_PKT_RSSI_VALUE = 0x1A;
    static REG_RSSI_VALUE = 0x1B;
    static REG_HOP_CHANNEL = 0x1C;
    static REG_MODEM_CONFIG1 = 0x1D;
    static REG_MODEM_CONFIG2 = 0x1E;
    static REG_MODEM_CONFIG3 = 0x26;
    static REG_SYMB_TIMEOUT_LSB = 0x1F;
    
    static REG_PREAMBLE_MSB = 0x20;
    static REG_PREAMBLE_LSB = 0x21;
    static REG_PAYLOAD_LENGTH = 0x22;
    static REG_MAX_PAYLOAD_LENGTH = 0x23;
    static REG_HOP_PERIOD = 0x24;
    static REG_FIFO_RX_BYTE_ADDR = 0x25;
    
    
    // -------------------- Shared Registers ---------------------- //

    static REG_DIO_MAPPING1 = 0x40;
    static REG_DIO_MAPPING2 = 0x41;
    static REG_VERSION = 0x42;
    static REG_TCXO = 0x4B;
    
    // -------------------- Some Tables --------------------------- //
    
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
    
    static CRTABLE = {
        "4/5": 0x01,
        "4/6": 0x02,
        "4/7": 0x03,
        "4/8": 0x04
    };
    
    static SLEEP = 0x00;
    static STANDBY = 0x01;
    static FSTX = 0x02;
    static TX = 0x03;
    static FSRX = 0x04;
    static RXCONTINUOUS = 0x05;
    static RXSINGLE = 0x06;
    static CAD = 0x07;
    
    static _txHeaderTo = 0xFF;
    static _txHeaderFrom = 0x00;
    static _txHeaderId = 0;
    static _thisAddress = 0x66;
    static _txHeaderFlags = 0;
    
    constructor(spi, irq, cs=null) {
        // Assume spi is already initialized, assume cs is already initialized
        this._spi = spi;
        this._irqPin = irq;
        this._cs = cs;
    }
    
    function init() {
        setMode(SLEEP); // need to do this to go into LoRa mode
        
        // Defaults
        setFrequency(915000000);
        setBandwidth("125");
        setSpreadingFactor(7);
        setCodingRate("4/5");
        setImplicitHeaderMode(false);
        setPreambleLength(8);
        setPayloadLength(10);

        configIRQ();
        
        _setInLoRaMode();

    }

    function configIRQ() {
        if(_irqPin) {
            _irqPin.configure(DIGITAL_IN_PULLDOWN, _isr.bindenv(this));
        }
        else {
            throw "interrupt pin passed to constructor is invalid";
        }
    }

    function _isr() {
        // Active high]
        if(_irqPin.read()) {
            local read = readReg(REG_IRQ_FLAGS);
            if (read & (1 << PAYLOAD_CRC_ERROR)) {
                _error = true;
            }
            else if(read & (1 << TX_DONE)) {
                _sendFinished = true;
            }
            else if (read == ((1 << RX_DONE) | (1 << VALID_HEADER))) {
                _receive(_readFromRXBuffer());
            }
            
            clearInterrupts();
        }
    }

    function _receive(data) {
        if(_receiveHandler) {
            _receiveHandler(data);
        }
    }
    
    function _writeToTXBuffer(data, len) {
        //writeReg(REG_FIFO_TX_BASE_ADDR, 0x00);
        // writeReg(REG_FIFO_ADDR_PTR, 0x00);
        local write = blob(len + 1);
        write[0] = (FIFO | WRITE_MASK);
        for(local i = 0; i < len; ++i) {
            //writeReg(FIFO,data[i]);
            write[i+1] = data[i];
        }
        _csLow();
        _spi.writeread(write);
        _csHigh();
    }
    
    function sendData(data, header, footer) {
        local len = data.len();

        local extra_len = 0;
        extra_len += (header ? 4 : 0);
        extra_len += (footer ? 1 : 0);

        if(len + extra_len > 0xff) return;

        
        if(_sendFinished) {
            _sendFinished = false;
            setMode(STANDBY);
            writeReg(REG_DIO_MAPPING1, 0x40);
            setFifoTxBase(0x00);
            writeReg(REG_FIFO_ADDR_PTR, 0x00);
            // Header
            if(header) {
                writeReg(FIFO, _txHeaderTo);
                writeReg(FIFO, _txHeaderFrom);
                writeReg(FIFO, _txHeaderId);
                writeReg(FIFO, _txHeaderFlags);
            }
            
            // data
            writeToTXBuffer(data, len);
            
            // Footer
            if(footer) {
                writeReg(FIFO, 0x00);
            }
            
            
            writeReg(REG_PAYLOAD_LENGTH, len + extra_len);
            setMode(FSTX);
            imp.sleep(0.0002);
            _sendFinished = false;
            setMode(TX);
        }
        
    }
    
    function receiveData() {
        setMode(STANDBY);
        writeReg(REG_FIFO_ADDR_PTR, 0x00);
        writeReg(REG_DIO_MAPPING1, 0x00);
        setMode(FSRX);
        imp.sleep(0.0002);
        rf.setMode(RXCONTINUOUS);
    }
    
    
    function _readFromRXBuffer() {
        // To retrieve:
        // 1. Read Fifo num bytes
        // 2. Read RegRxDataAddr
        // 3. Set FifoPtrAddr to FifoRxCurrentAddr, 
        // Read RegFifo address Fifo num bytes times
        local numBytes = readReg(REG_RX_N_BYTES);
        local fifoRXPointer = readReg(REG_FIFO_RX_CURRENT_ADDR);
        writeReg(REG_FIFO_ADDR_PTR, fifoRXPointer);
        local b = blob(numBytes);
        local fifo = blob(1);
        fifo[0] = FIFO | READ_MASK;
        _csLow();
        // initiate FIFO read
        _spi.writeread(fifo);
        local read = _spi.writeread(b);
        _csHigh();
        clearInterrupts();
        return read;
    }
    
    function setPayloadLength(len) {
        writeReg(REG_PAYLOAD_LENGTH, len);
    }
    
    function setImplicitHeaderMode(state) {
        local cur = readReg(REG_MODEM_CONFIG1);
        writeReg(REG_MODEM_CONFIG1, (cur & 0xfe) | (state ? 1 : 0));
    }
    
    function setPreambleLength(len) {
        writeReg(REG_PREAMBLE_MSB, (len >>8) & 0xff);
        writeReg(REG_PREAMBLE_LSB, len & 0xff);
    }
    
    function setFifoTxBase(start) {
        writeReg(REG_FIFO_TX_BASE_ADDR, start & 0xff);
    }
    
    function setFifoRxBase(start) {
        writeReg(REG_FIFO_RX_BASE_ADDR, start & 0xff);
    }
    
    function setCodingRate(cr) {
        local cur = readReg(REG_MODEM_CONFIG1);
        local clear = cur & 0xf1; // exclude bits 3-1
        writeReg(REG_MODEM_CONFIG1, clear | (CRTABLE[cr] << 1));
    }
    
    function setRxPayloadCRC(state) {
        local current = readReg(REG_MODEM_CONFIG2);
        writeReg(REG_MODEM_CONFIG2, (current & 0xfb) | (state ? 0x04 : 0x00));
    }
    
    function setBandwidth(bw) {
        local current = readReg(REG_MODEM_CONFIG1);
        writeReg(REG_MODEM_CONFIG1, BWTABLE[bw] << 4 | (current & 0x0f));
    }
    
    function setMode(mode) {
        local current = readReg(REG_OP_MODE);
        writeReg(REG_OP_MODE, mode | (current & 0xf8));
    }
    
    function checkInterrupt(flag) {
        local interrupts = readReg(REG_IRQ_FLAGS);
        return ((1 << flag) & interrupts);
    }
    
    function clearInterrupts() {
        writeReg(REG_IRQ_FLAGS, 0xff);
    }
    
    function maskAllInterrupts() {
        writeReg(REG_IRQ_FLAGS_MASK, 0xff);
    }
    
    function enableInterrupt(mask) {
        local currentInterrupts = readReg(REG_IRQ_FLAGS);
        // Mask the interrupt by writing high, therefore enable by writing low
        local newInterrupts = currentInterrupts & (~ (1<<mask));
        writeReg(REG_IRQ_FLAGS_MASK, newInterrupts);
    }
    
    function _setInLoRaMode() {
       writeReg(REG_OP_MODE, CONFIG_BYTE);
    }
    
    function _csLow() {
        if(_cs != null) {
            _cs.write(0);
        }
        else {
            _spi.chipselect(1);
        }
    }
    
    function _csHigh() {
        if(_cs != null) {
            _cs.write(1);
        }
        else {
            _spi.chipselect(0);
        }
    }
    
    function setMaxPayload(pl) {
        pl = pl & 0xff;
        writeReg(REG_MAX_PAYLOAD_LENGTH, pl);
    }
    
    function setSpreadingFactor(sf) {
        writeReg(REG_MODEM_CONFIG2, (sf & 0x0f) << 4);
    }
    
    function setFrequency(freq) {
        setMode(SLEEP);
        local reg_freq = (freq/FREQ_STEP).tointeger();
        //local reg_freq = 14991360;
        local freq_blob = blob(4); // big-endian blob
        freq_blob[0] = REG_FREQUENCY_HIGH | WRITE_MASK;
        freq_blob[1] = (reg_freq >> 16) & 0xFF;
        freq_blob[2] = (reg_freq >> 8) & 0xFF;
        freq_blob[3] = (reg_freq) & 0xFF;
        
        _csLow();
        _spi.writeread(freq_blob);
        _csHigh();
    }
    
    function writeReg(address, data) {
        local b = blob();
        b.writen(address | WRITE_MASK, 'b');
        b.writen(data, 'b');
        _csLow();
        _spi.writeread(b);
        _csHigh();
    }
    
    function readReg(address) {
        local b = blob(2);
        b[0] = address;
        _csLow();
        local data = _spi.writeread(b);
        _csHigh();
        return data[1];
    }

    function setReceiveHandler(handler) {
        _receiveHandler = handler;
    }

    function isDoneSending() {
        return _sendFinished;
    }
}
