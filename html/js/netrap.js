function netrapUplink(jsonuri) {
	var self = this;

	this.jsonuri = jsonuri;

	this.printers = [ 'default' ];
	this.currentPrinter = 'default';
	this.temperatures = {
		hotend: 0,
		bed: 0,
	};
	this.lastPos = {
		X: 0,
		Y: 0,
		Z: 0,
		E: 0,
	};
	this.queue = [];
	this.eventListeners = {
		printerListUpdated: [],
		temperatureListUpdated: [],
		positionUpdated: [],
	}

	this.fireEvent = function(name, dataObject) {
		if (self.eventListeners[name]) {
			if (self.eventListeners[name].length > 0) {
				var e = new Event(name);
				for (var a in dataObject) {
					e[a] = dataObject[a];
				}
				for (var f = 0; f < self.eventListeners[name].length; f++) {
					self.eventListeners[name][f](e);
				}
			}
		}
	};
}

netrapUplink.prototype = {
	sendCmd: function(cmd) {
		this.queueCmd(cmd);
		this.queueCommit();
	},
	queueCmd: function(cmd) {
		this.queue[this.queue.length] = cmd;
	},
	queueCommit: function() {
		// TODO: json: send commands
// 		alert(this.queue.join("\n"));
		try {
		var r = new Ajax.Request("json/enqueue", {
			contentType: "text/plain",
			parameters: this.queue.join("\n") + "\n",
			onSuccess: function (response) {
				var json = response.responseText.evalJSON(true);
// 				alert('AJAX: Success: ' + response);
			},
		});
		} catch (e) {
			alert(e);
		}
		this.queue = [];
	},
	query: function(query) {
		var self = this;
		var r = new Ajax.Request("json/query", {
			contentType: "text/plain",
			parameters: "select " + $('printer').options[$('printer').selectedIndex].value + "\n" + query + "\n",
			onSuccess: function (response) {
				try {
					var json = response.responseText.evalJSON(true);
				} catch (e) {
					alert(e);
				}
				// 				alert('AJAX: Success: ' + response);
				if (json) {
					if (json.replies) {
						var queries = response.request.body.split("\n");
						for (var i = 0; i < json.replies.length; i++) {
							$('log').value += "< " + json.replies[i] + "\n";
							$('log').scrollTop = $('log').scrollHeight;
							try {
								self.parseReply(queries[i], json.replies[i]);
							} catch (e) {
								alert(e);
							}
						}
					}
				}
			},
			onFailure: function (response) {
				// 				alert('AJAX: Failure: ' + response);
			},
		});
	},
	refreshPrinterList: function() {
		// TODO: json: listPrinters
// 		this.sendCmd("TODO: listPrinters");
		var self = this;
		var r = new Ajax.Request("json/printer-list", {
			onSuccess: function (response) {
				try {
					var json = response.responseText.evalJSON(true);
				} catch (e) {
					alert(e);
				}
				// 				alert('AJAX: Success: ' + response);
				if (json) {
					if (json.printercount > 0) {
						$('printer').options.length = 0;
						for (var i = 0; i < json.printercount; i++) {
							var printer = json.printers[i];
							if (printer) {
								var o = document.createElement('option');
								o.setAttribute('value', printer.name);
								o.innerHTML = printer.name;
								$('printer').appendChild(o);
							}
						}
					}
				}
			},
			onFailure: function (response) {
				// 				alert('AJAX: Failure: ' + response);
			},
		});
	},
	printerList: function() {
		return this.printers;
	},
	selectPrinter: function(printer) {
		// TODO: json: select printer
	},
	selectedPrinter: function() {
		return this.currentPrinter;
	},
	refreshTemperatureList: function() {
		this.query('M105');
	},
	temperatureList: function() {
		return this.temperatures;
	},
	refreshPosition: function() {
		this.query('M114');
	},
	position: function() {
		return this.lastPos;
	},
	jog: function(x, y, z, e) {
		var l = [ 'G1' ];
		if (!isNaN(x) && isFinite(x)) {
			l.push('X' + x);
			this.lastPos.X += x;
		}
		if (!isNaN(y) && isFinite(y)) {
			l.push('Y' + y);
			this.lastPos.Y += y;
		}
		if (!isNaN(z) && isFinite(z)) {
			l.push('Z' + z);
			this.lastPos.Z += z;
		}
		if (!isNaN(e) && isFinite(e)) {
			l.push('E' + e);
			this.lastPos.E += e;
		}
		if (l.length > 1) {
			this.queueCmd('G91');
			this.queueCmd(l.join(" "))
			this.queueCmd('G90');
// 			alert(this.queue.join("\n"));
			this.queueCommit();
			this.fireEvent('positionUpdated', this.lastPos);
		}
	},
	moveTo: function(x, y, z, e) {
		var l = [ 'G1' ];
		if (!isNaN(x) && isFinite(x)) {
			l.push('X' + x);
			this.lastPos.X = x;
		}
		if (!isNaN(y) && isFinite(y)) {
			l.push('Y' + y);
			this.lastPos.Y = y;
		}
		if (!isNaN(z) && isFinite(z)) {
			this.lastPos.Z = z;
			l.push('Z' + z);
		}
		if (!isNaN(e) && isFinite(e)) {
			this.lastPos.E = e;
			l.push('E' + e);
		}
		if (l.length > 1) {
			this.sendCmd(l.join(" "));
			this.fireEvent('positionUpdated', this.lastPos);
		}
	},
	parseReply: function(query, reply) {
		// check for printers
		if (reply.printerList) {
			this.printers = reply.printerList;
			this.fireEvent('printerListUpdated', this.printers);
		}
		// check for temperatures
		if (reply.temperatureList) {
			this.temperatureList =reply.temperatureList;
			this.fireEvent('temperatureListUpdated', this.temperatures);
		}
		// check for position
		if (reply.position) {
			this.lastPos =reply.position;
			this.fireEvent('positionUpdated', this.lastPos);
		}
	}
};
