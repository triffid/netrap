// TODO: inherit from generic 'jog' object to reduce code copying

function jogXY(canvas) {
	var self = this;

	this.eventListeners = {
		jog: [],
		jogX: [],
		jogY: [],
		jogZ: [],
		jogE: [],
	};
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

	this.canvas = canvas;

	this.context = canvas.getContext('2d');
	this.context.circle = function(x, y, radius) {
		this.save();
		this.beginPath();
		this.arc(x, y, radius, 0, Math.PI * 2, true);
		this.stroke();
		this.restore();
	};
	this.context.line = function(x1, y1, x2, y2) {
		this.save();
		this.beginPath();
		this.moveTo(x1, y1);
		this.lineTo(x2, y2);
		this.stroke();
		this.restore();
	};

	this.buttons = [];
	function buttonXY(axis, length) {
		var innerR;
		var outerR;
		var centerX = self.canvas.width * 0.5;
		var centerY = self.canvas.height * 0.5;
		var quadrant;
		if (length == 0.1 || length == -0.1) {
			innerR = 0;
			outerR = 242 * 0.175;
		}
		if (length == 1   || length == -1  ) {
			innerR = 242 * 0.175;
			outerR = 242 * 0.28;
		}
		if (length == 10  || length == -10 ) {
			innerR = 242 * 0.28;
			outerR = 242 * 0.38;
		}
		if (length == 100 || length == -100) {
			innerR = 242 * 0.38;
			outerR = 242 * 0.465;
		}

		if (axis == 'X') {
			quadrant = 1;
		}
		else if (axis == 'Y') {
			quadrant = 0;
		}
		if (length < 0)
			quadrant += 2;

		this.axis = axis;
		this.length = length;
		this.quadrant = quadrant;
		this.innerR = innerR;
		this.outerR = outerR;

		this.check = function(x, y) {
			var cx = x - centerX;
			var cy = y - centerY;
			var r = Math.sqrt((cx * cx) + (cy * cy));
			if (r <= innerR || r > outerR)
				return false;
			var a = Math.atan2(cx, cy) * 180 / Math.PI;
			var q;
			if (a >= 135 || a < -135)
				q = 0;
			if (a >= 45 && a < 135)
				q = 1;
			if (a >= -45 && a < 45)
				q = 2;
			if (a >= -135 && a < -45)
				q = 3;
			if (q != quadrant)
				return false;
// 			window.log.textContent = 'cx: ' + cx + '\ncy: ' + cy + '\nr: ' + r + '\na: ' + a + '\nq: ' + quadrant;
			return true;
		}
		this.toString = function() {
			return axis + length;
		}
		this.highlight = function() {
			self.context.save();
			self.context.lineWidth = 2;
			self.context.strokeStyle = "rgba(255, 255, 64, 1)";
			self.context.fillStyle = "rgba(255, 255, 64, 0.25)";
			self.context.beginPath();
			self.context.arc(centerX, centerY, outerR, (quadrant * 90 - 45) * Math.PI / 180, (quadrant * 90 - 135) * Math.PI / 180, true);
			self.context.arc(centerX, centerY, innerR, (quadrant * 90 - 135) * Math.PI / 180, (quadrant * 90 - 45) * Math.PI / 180, false);
			self.context.lineTo(centerX + outerR * Math.cos((quadrant * 90 - 45) * Math.PI / 180), centerY + outerR * Math.sin((quadrant * 90 - 45) * Math.PI / 180));
			self.context.stroke();
			self.context.fill();
			self.context.restore();
		}
	}
	for (var d = 0.1; d < 101; d *= 10) {
		this.buttons.push(new buttonXY('X',  d));
		this.buttons.push(new buttonXY('X', -d));
		this.buttons.push(new buttonXY('Y',  d));
		this.buttons.push(new buttonXY('Y', -d));
	}
	this.canvas.onmousemove = function(e) {
		self.draw();
		for (var b = 0; b < self.buttons.length; b++) {
			if (self.buttons[b].check(e.offsetX, e.offsetY)) {
				// TODO: highlight
				self.buttons[b].highlight(self.canvas);
			}
		}
	}
	this.canvas.onmouseup = function(e) {
// 		alert(e);
		for (var b = 0; b < self.buttons.length; b++) {
			var button = self.buttons[b];
			if (button.check(e.offsetX, e.offsetY)) {
				var jogX = undefined;
				var jogY = undefined;
				if (button.axis == 'X') {
					jogX = button.length;
					self.fireEvent('jogX', { X: jogX, Y: undefined });
				}
				else {
					jogY = button.length;
					self.fireEvent('jogY', { X: undefined, Y: jogY });
				}
// 				alert(button);
				self.fireEvent('jog', { X: jogX, Y: jogY });
			}
		}
	}
}

jogXY.prototype = {
	draw: function() {
		var canvas = this.canvas;
		var context = this.context;
			context.clearRect(0, 0, canvas.width, canvas.height);
		if (0) {
			context.save();
				var mr = (canvas.width < canvas.height)?canvas.width:canvas.height;
				context.lineWidth = 1;
				context.strokeStyle = "rgba(0,0,0,1)";
				context.circle(canvas.width / 2, canvas.height / 2, mr * 0.465);
				context.circle(canvas.width / 2, canvas.height / 2, mr * 0.38);
				context.circle(canvas.width / 2, canvas.height / 2, mr * 0.28);
				context.circle(canvas.width / 2, canvas.height / 2, mr * 0.175);
				for (var r = 45; r < 360; r += 90) {
					context.line(canvas.width / 2 + Math.sin(r * Math.PI / 180) * mr * 0.175, canvas.height / 2 + Math.cos(r * Math.PI / 180) * mr * 0.175,
								canvas.width / 2 + Math.sin(r * Math.PI / 180) * mr * 0.46, canvas.height / 2 + Math.cos(r * Math.PI / 180) * mr * 0.46);
				}
			context.restore();
		}
	},
	observe: function(event, callback) {
		if (this.eventListeners[event]) {
			this.eventListeners[event].push(callback);
		}
	},
};

/*
function jogZE(canvas, axis) {
	var self = this;

	this.eventListeners = {
		jog: [],
		jogZ: [],
		jogE: [],
	};
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

	this.canvas = canvas;

	this.context = canvas.getContext('2d');
	this.context.circle = function(x, y, radius) {
		this.save();
		this.beginPath();
		this.arc(x, y, radius, 0, Math.PI * 2, true);
		this.stroke();
		this.restore();
	};
	this.context.line = function(x1, y1, x2, y2) {
		this.save();
		this.beginPath();
		this.moveTo(x1, y1);
		this.lineTo(x2, y2);
		this.stroke();
		this.restore();
	};

	this.buttons = [];
	function buttonZE(length) {
		var x1 = 10;
		var x2 = 50;
		var y1 = 122 + log(length) / log(10) * 30 + 10;
		var y2 = 122 + log(length) / log(10) * 30;
		this.check = function(x, y) {
// 			if (x < x1 || x >= x2)
// 				return false;
// 			if (y < y1 || y >= y2)
// 				return false;
// 			return true;
		}
		this.toString = function() {
			return axis + length;
		}
		this.highlight = function() {
			self.context.save();
			self.context.lineWidth = 2;
			self.context.strokeStyle = "rgba(255, 255, 64, 1)";
			self.context.fillStyle = "rgba(255, 255, 64, 0.25)";
			self.context.beginPath();
// 			self.context.moveTo(x1, y1);
// 			self.context.lineTo(x2, y1);
// 			self.context.lineTo(x2, y2);
// 			self.context.lineTo(x1, y2);
// 			self.context.lineTo(x1, y1);
			self.context.stroke();
			self.context.fill();
			self.context.restore();
		}
	}
	for (var d = 0.1; d < 11; d *= 10) {
		this.buttons.push(new buttonXY(axis,  d));
		this.buttons.push(new buttonXY(axis, -d));
	}
	this.canvas.onmousemove = function(e) {
		self.draw();
		for (var b = 0; b < self.buttons.length; b++) {
			if (self.buttons[b].check(e.offsetX, e.offsetY)) {
				// TODO: highlight
				self.buttons[b].highlight(self.canvas);
			}
		}
	}
	this.canvas.onmouseup = function(e) {
		// 		alert(e);
		for (var b = 0; b < self.buttons.length; b++) {
			var button = self.buttons[b];
			if (button.check(e.offsetX, e.offsetY)) {
// 				var jogZ = undefined;
// 				var jogE = undefined;
// 				if (axis == 'Z')
// 					jogZ = button.length;
// 				else
// 					jogE = button.length;
// 				self.fireEvent('jog', { Z: jogZ, E: jogE });
			}
		}
	}
}

jogZE.prototype = {
	draw: function() {
		var canvas = this.canvas;
		var context = this.context;
			context.clearRect(0, 0, canvas.width, canvas.height);

			if (0) {
				context.save();
				var mr = (canvas.width < canvas.height)?canvas.width:canvas.height;
				context.lineWidth = 1;
				context.strokeStyle = "rgba(0,0,0,1)";
				context.circle(canvas.width / 2, canvas.height / 2, mr * 0.465);
				context.circle(canvas.width / 2, canvas.height / 2, mr * 0.38);
				context.circle(canvas.width / 2, canvas.height / 2, mr * 0.28);
				context.circle(canvas.width / 2, canvas.height / 2, mr * 0.175);
				for (var r = 45; r < 360; r += 90) {
					context.line(canvas.width / 2 + Math.sin(r * Math.PI / 180) * mr * 0.175, canvas.height / 2 + Math.cos(r * Math.PI / 180) * mr * 0.175,
								 canvas.width / 2 + Math.sin(r * Math.PI / 180) * mr * 0.46, canvas.height / 2 + Math.cos(r * Math.PI / 180) * mr * 0.46);
				}
				context.restore();
			}
	},
	observe: function(event, callback) {
		if (this.eventListeners[event]) {
			this.eventListeners[event].push(callback);
		}
	},
};
/**/