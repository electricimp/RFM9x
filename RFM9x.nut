    const RFM9X_FIFO = 0x00;

    // SPI masks
    const RFM9X_WRITE_MASK = 0x80;
    const RFM9X_READ_MASK = 0x00;
    
    const RFM9X_REG_OP_MODE = 0x01;
    // f_RF = ((X_OSC) * Fr_f ) / (2^19). Resolution is 61.035 Hz if X_OSC = 32MHz
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
    
    
    // -------------------- Shared Registers ---------------------- //

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
    const RFM9X_DEFAULT_IMPLICIT_HEADER_MODE = false;
    const RFM9X_DEFAULT_PREAMBLE_LENGTH = 8;

class RFM9x {
    
    _spiModule = null;
    _cs = null;
    _irqPin = null;
    _receiveHandler = null;
    _sendFinished = true;
    _error = false;

    static FREQ_STEP = 61.035;
    
    // LoRa Mode
    static CONFIG_BYTE = 0x80; 
    
    // Interrupt Masks AND flags
    static RX_TIMEOUT = 7;
    static RX_DONE = 6;
    static PAYLOAD_CRC_ERROR = 5;
    static VALID_HEADER = 4;
    static TX_DONE = 3;
    static CAD_DONE = 2;
    static FHSS_CHANGE_CHANNEL = 1;
    static CAD_DETECTED = 0;
    
    
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
    
    // Operating modes
    static SLEEP = 0x00;
    static STANDBY = 0x01;
    static FSTX = 0x02;
    static TX = 0x03;
    static FSRX = 0x04;
    static RXCONTINUOUS = 0x05;
    static RXSINGLE = 0x06;
    static CAD = 0x07;

    
    
    
    constructor(spi, irq, cs=null) {
        // Assume spi is already initialized, assume cs is already initialized
        this._spiModule = spi;
        this._irqPin = irq;
        this._cs = cs;
    }
    
    function init() {
        setMode(SLEEP); // need to do this to go into LoRa mode
        
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

    function _configISR() {
        if (_irqPin) {
            _irqPin.configure(DIGITAL_IN_PULLDOWN, _interruptServiceRoutine.bindenv(this));
        }
        else {
            throw "interrupt pin passed to constructor is invalid";
        }
    }

    function _interruptServiceRoutine() {
        // Active high
        if (_irqPin.read()) {
            local read = readReg(RFM9X_REG_IRQ_FLAGS);
            if (read & (1 << PAYLOAD_CRC_ERROR)) {
                _error = true;
            }
            else if (read & (1 << TX_DONE)) {
                _sendFinished = true;
            }
            else if (read == ((1 << RX_DONE) | (1 << VALID_HEADER))) {
                _receive(_readFromRXBuffer());
            }
            
            clearInterrupts();
        }
    }

    function _receive(data) {
        _receiveHandler && _receiveHandler(data);
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
    
    function sendData(data) {
        local len = data.len();

        // Ensure that the data string is not larger than the fifo buffer
        if (len > 0x100) return;

        
        if (_sendFinished) {
            _sendFinished = false;
            setMode(STANDBY);
            writeReg(RFM9X_REG_DIO_MAPPING1, 0x40);
            setFifoTxBase(0x00);
            writeReg(RFM9X_REG_FIFO_ADDR_PTR, 0x00);

            // Write the data here
            writeToTXBuffer(data, len);
            
            writeReg(RFM9X_REG_PAYLOAD_LENGTH, len);
            setMode(FSTX);
            imp.sleep(0.0002);
            _sendFinished = false;
            setMode(TX);
        }
        
    }
    
    function receiveData() {
        setMode(STANDBY);
        writeReg(RFM9X_REG_FIFO_ADDR_PTR, 0x00);
        writeReg(RFM9X_REG_DIO_MAPPING1, 0x00);
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
        local numBytes = readReg(RFM9X_REG_RX_N_BYTES);
        local fifoRXPointer = readReg(RFM9X_REG_FIFO_RX_CURRENT_ADDR);
        writeReg(RFM9X_REG_FIFO_ADDR_PTR, fifoRXPointer);
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
    
    function setPayloadLength(len) {
        writeReg(RFM9X_REG_PAYLOAD_LENGTH, len);
    }
    
    function setImplicitHeaderMode(state) {
        local cur = readReg(RFM9X_REG_MODEM_CONFIG1);
        writeReg(RFM9X_REG_MODEM_CONFIG1, (cur & 0xfe) | (state ? 1 : 0));
    }
    
    function setPreambleLength(len) {
        writeReg(RFM9X_REG_PREAMBLE_MSB, (len >>8) & 0xff);
        writeReg(RFM9X_REG_PREAMBLE_LSB, len & 0xff);
    }
    
    function setFifoTxBase(start) {
        writeReg(RFM9X_REG_FIFO_TX_BASE_ADDR, start & 0xff);
    }
    
    function setFifoRxBase(start) {
        writeReg(RFM9X_REG_FIFO_RX_BASE_ADDR, start & 0xff);
    }
    
    function setCodingRate(cr) {
        local cur = readReg(RFM9X_REG_MODEM_CONFIG1);
        local clear = cur & 0xf1; // exclude bits 3-1
        writeReg(RFM9X_REG_MODEM_CONFIG1, clear | (CRTABLE[cr] << 1));
    }
    
    function setRxPayloadCRC(state) {
        local current = readReg(RFM9X_REG_MODEM_CONFIG2);
        writeReg(RFM9X_REG_MODEM_CONFIG2, (current & 0xfb) | (state ? 0x04 : 0x00));
    }
    
    function setBandwidth(bw) {
        local current = readReg(RFM9X_REG_MODEM_CONFIG1);
        writeReg(RFM9X_REG_MODEM_CONFIG1, BWTABLE[bw] << 4 | (current & 0x0f));
    }
    
    function setMode(mode) {
        local current = readReg(RFM9X_REG_OP_MODE);
        writeReg(RFM9X_REG_OP_MODE, mode | (current & 0xf8));
    }
        
    function clearInterrupts() {
        writeReg(RFM9X_REG_IRQ_FLAGS, 0xff);
    }
    
    function maskAllInterrupts() {
        writeReg(RFM9X_REG_IRQ_FLAGS_MASK, 0xff);
    }
    
    function enableInterrupt(mask) {
        local currentInterrupts = readReg(RFM9X_REG_IRQ_FLAGS);
        // Mask the interrupt by writing high, therefore enable by writing low
        local newInterrupts = currentInterrupts & (~ (1<<mask));
        writeReg(RFM9X_REG_IRQ_FLAGS_MASK, newInterrupts);
    }
    
    function _setInLoRaMode() {
       writeReg(RFM9X_REG_OP_MODE, CONFIG_BYTE);
    }
    
    function _csLow() {
        if (_cs != null) {
            _cs.write(0);
        }
        else {
            _spiModule.chipselect(1);
        }
    }
    
    function _csHigh() {
        if (_cs != null) {
            _cs.write(1);
        }
        else {
            _spiModule.chipselect(0);
        }
    }
    
    function setMaxPayload(pl) {
        pl = pl & 0xff;
        writeReg(RFM9X_REG_MAX_PAYLOAD_LENGTH, pl);
    }
    
    function setSpreadingFactor(sf) {
        writeReg(RFM9X_REG_MODEM_CONFIG2, (sf & 0x0f) << 4);
    }
    
    function setFrequency(freq) {
        setMode(SLEEP);
        local reg_freq = (freq/FREQ_STEP).tointeger();
        local freq_blob = blob(4); // big-endian blob
        freq_blob[0] = RFM9X_REG_FREQUENCY_HIGH | RFM9X_WRITE_MASK;
        freq_blob[1] = (reg_freq >> 16) & 0xFF;
        freq_blob[2] = (reg_freq >> 8) & 0xFF;
        freq_blob[3] = (reg_freq) & 0xFF;
        
        _csLow();
        _spiModule.writeread(freq_blob);
        _csHigh();
    }
    
    function writeReg(address, data) {
        local b = blob();
        b.writen(address | RFM9X_WRITE_MASK, 'b');
        b.writen(data, 'b');
        _csLow();
        _spiModule.writeread(b);
        _csHigh();
    }
    
    function readReg(address) {
        local b = blob(2);
        b[0] = address;
        _csLow();
        local data = _spiModule.writeread(b);
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
