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

class MyTestCase extends ImpTestCase {

	function construct(sendCb) {
		local spi = hardware.spiBCAD;
		spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | USE_CS_L, 1000);
		local irq = hardware.pinXD;
		return RFM9x(spi, irq);
	}

	function testSendDataTooLong() {
		local strTooLong = "";
		for (local i = 0; i < 0x101; ++i) {
			strTooLong += "c";
		}
		return Promise(function(resolve, reject) {
		    local rf = construct(function(error, data) {
				if (error == "data size error") {
					resolve("threw correct error");
				} else {
					reject("did not throw correct error");
				}
			}.bindenv(this));
			rf.sendData(strTooLong);
		}).bindenv(this);
	}

	function testSendDataTooSoon() {
		return Promise(function(resolve, reject) {
			local rf = construct(function(error, data) {
				if (error == "sending") {
					resolve("threw correct error");
				} else {
					reject("did not throw correct error");
				}
			}.bindenv(this));

			rf.sendData("test");
			// The successive calls should occur too quickly for the radio to have finished
			// transmitting, therefore causing it to produce a "sending" error
			rf.sendData("test");
			
		}.bindenv(this));
	}
}
