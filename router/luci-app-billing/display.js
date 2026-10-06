"use strict";
"require view";
"require fs";
"require rpc";
"require uci";
"require ui";

var callHostHints = rpc.declare({
	object: "luci-rpc",
	method: "getHostHints",
	expect: { "": {} }
});

function formatBytes(bytes) {
	if (!bytes || bytes === 0) return "0 B";
	var k = 1000;
	var sizes = ["B", "KB", "MB", "GB", "TB"];
	var i = Math.floor(Math.log(bytes) / Math.log(k));
	if (i < 0) i = 0;
	if (i >= sizes.length) i = sizes.length - 1;
	return (bytes / Math.pow(k, i)).toFixed(2) + " " + sizes[i];
}

function formatMoney(amount, currency) {
	return Number(Math.round(amount)).toLocaleString() + " " + currency;
}

var PALETTE = [
	"#3b82f6", "#10b981", "#8b5cf6", "#f59e0b",
	"#ec4899", "#06b6d4", "#f97316", "#64748b"
];

return view.extend({
	currentPeriod: null,
	periods: [],

	load: function() {
		return Promise.all([
			uci.load("billing"),
			callHostHints(),
			fs.exec("/usr/libexec/nlbwmon-action", ["periods"]).then(function(res) {
				try {
					var parsed = JSON.parse(res.stdout || "{}");
					return parsed.periods || [];
				} catch(e) {
					return [];
				}
			}),
			fs.exec("/usr/libexec/samantel-balance", ["status"]).then(function(res) {
				try {
					return JSON.parse(res.stdout || "{}");
				} catch(e) {
					return { connected: false };
				}
			}),
			fs.read_direct("/etc/usage-log/device-identities.tsv").catch(function() { return ""; })
		]);
	},

	fetchSamantelData: function(force) {
		var action = force ? "fetch" : "status";
		return fs.exec("/usr/libexec/samantel-balance", [action]).then(function(res) {
			try {
				return JSON.parse(res.stdout || "{}");
			} catch(e) {
				return { connected: false };
			}
		});
	},

	fetchPeriodData: function(period) {
		var args = ["download", "-f", "json", "-g", "ip,mac"];
		if (period) {
			args.push("-t", period);
		}
		return fs.exec("/usr/libexec/nlbwmon-action", args).then(function(res) {
			try {
				return JSON.parse(res.stdout || "{}");
			} catch(e) {
				return { columns: [], data: [] };
			}
		});
	},

	renderSVGDonut: function(groups, totalBytes) {
		if (totalBytes === 0) {
			return E("div", { "style": "text-align: center; padding: 2rem; opacity: 0.6;" }, _("No traffic recorded yet."));
		}

		var size = 220;
		var half = size / 2;
		var radius = 70;
		var strokeWidth = 28;
		var circumference = 2 * Math.PI * radius;

		var svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
		svg.setAttribute("viewBox", "0 0 " + size + " " + size);
		svg.setAttribute("style", "width: 100%; max-width: 220px; height: auto; transform: rotate(-90deg);");

		var accumulatedPercent = 0;
		groups.forEach(function(g) {
			if (g.totalBytes === 0) return;
			var percent = g.totalBytes / totalBytes;
			var circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");
			circle.setAttribute("cx", half);
			circle.setAttribute("cy", half);
			circle.setAttribute("r", radius);
			circle.setAttribute("fill", "transparent");
			circle.setAttribute("stroke", g.color);
			circle.setAttribute("stroke-width", strokeWidth);
			circle.setAttribute("stroke-dasharray", (percent * circumference) + " " + circumference);
			circle.setAttribute("stroke-dashoffset", -(accumulatedPercent * circumference));
			circle.setAttribute("style", "transition: stroke-dasharray 0.5s ease;");

			var title = document.createElementNS("http://www.w3.org/2000/svg", "title");
			title.textContent = g.name + ": " + (percent * 100).toFixed(1) + "% (" + formatBytes(g.totalBytes) + ")";
			circle.appendChild(title);

			svg.appendChild(circle);
			accumulatedPercent += percent;
		});

		var container = E("div", { "style": "display: flex; flex-direction: column; align-items: center; justify-content: center;" }, [
			svg,
			E("div", { "style": "margin-top: 0.5rem; font-weight: bold; font-size: 0.9rem;" }, formatBytes(totalBytes) + " " + _("Total"))
		]);

		return container;
	},

	render: function(data) {
		var self = this;
		var hostHints = data[1] || {};
		self.periods = data[2] || [];
		self.deviceIdentitiesTsv = data[4] || "";
		if (!self.currentPeriod && self.periods.length > 0) {
			self.currentPeriod = self.periods[0];
		}

		var viewContainer = E("div", { "class": "cbi-map" }, [
			E("h2", {}, _("Bandwidth Usage & Household Billing")),
			E("div", { "class": "cbi-map-descr" }, _("Real-time network usage grouped by family member or device group with automated billing splits."))
		]);

		var periodSelector = E("select", {
			"class": "cbi-input-select",
			"style": "margin-bottom: 1rem; padding: 0.35rem 0.75rem; border-radius: 6px; font-weight: bold;",
			"change": function(ev) {
				self.currentPeriod = ev.target.value;
				self.updateView(viewContainer, hostHints);
			}
		});

		if (self.periods.length === 0) {
			periodSelector.appendChild(E("option", { "value": "" }, _("Current Period")));
		} else {
			self.periods.forEach(function(p) {
				var opt = E("option", { "value": p }, p + (p === self.periods[0] ? " (" + _("Current") + ")" : ""));
				if (p === self.currentPeriod) opt.selected = true;
				periodSelector.appendChild(opt);
			});
		}

		var topControls = E("div", { "style": "display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem;" }, [
			E("div", { "style": "display: flex; align-items: center; gap: 0.5rem;" }, [
				E("strong", {}, _("Billing Cycle: ")),
				periodSelector
			]),
			E("div", {}, [
				E("button", {
					"class": "btn cbi-button cbi-button-action",
					"click": function() {
						self.updateView(viewContainer, hostHints);
					}
				}, "↻ " + _("Refresh Now"))
			])
		]);

		viewContainer.appendChild(topControls);

		var dynamicArea = E("div", { "id": "billing-dynamic-area" }, [
			E("p", { "class": "spinning" }, _("Loading bandwidth statistics..."))
		]);
		viewContainer.appendChild(dynamicArea);

		self.updateView(viewContainer, hostHints);

		return viewContainer;
	},

	updateView: function(viewContainer, hostHints, forceSamantel) {
		var self = this;
		var dynamicArea = viewContainer.querySelector("#billing-dynamic-area");
		if (!dynamicArea) return;

		Promise.all([
			self.fetchPeriodData(self.currentPeriod),
			self.fetchSamantelData(forceSamantel)
		]).then(function(results) {
			var dataset = results[0] || {};
			var smt = results[1] || {};
			dynamicArea.innerHTML = "";

			var costPerGb = parseFloat(uci.get("billing", "main", "cost_per_gb") || (smt.cost_per_gb ? smt.cost_per_gb : "7700"));
			var monthlyBudget = parseFloat(uci.get("billing", "main", "monthly_budget") || "0");
			var currency = uci.get("billing", "main", "currency") || "Toman";
			var billingMode = uci.get("billing", "main", "billing_mode") || "per_gb";

			/* Samantel ISP Banner Card */
			var ispBanner = null;
			if (smt.connected) {
				var pctStr = smt.percent_left + "%";
				ispBanner = E("div", {
					"class": "cbi-section",
					"style": "padding: 1.25rem 1.5rem; border-radius: 12px; margin-bottom: 1.5rem; background: linear-gradient(135deg, rgba(59, 130, 246, 0.08) 0%, rgba(16, 185, 129, 0.08) 100%); border: 1px solid rgba(59, 130, 246, 0.2);"
				}, [
					E("div", { "style": "display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem; margin-bottom: 1rem;" }, [
						E("div", {}, [
							E("div", { "style": "display: flex; align-items: center; gap: 0.5rem;" }, [
								E("span", { "style": "font-size: 1.4rem;" }, "📶"),
								E("h3", { "style": "margin: 0; font-size: 1.2rem; font-weight: bold;" }, "Samantel ISP — " + smt.package_name)
							]),
							E("div", { "style": "font-size: 0.85rem; opacity: 0.8; margin-top: 0.25rem;" },
								_("Expires: ") + (smt.expire_date || "2027-09-04") + " | " + _("SIM Cash: ") + Number(smt.cash_toman).toLocaleString() + " " + currency)
						]),
						E("div", { "style": "display: flex; align-items: center; gap: 0.75rem;" }, [
							E("span", { "style": "font-size: 0.85rem; opacity: 0.7;" }, smt.last_update ? "Synced: " + smt.last_update : ""),
							E("button", {
								"class": "btn cbi-button cbi-button-action",
								"style": "font-size: 0.85rem;",
								"click": function() {
									self.updateView(viewContainer, hostHints, true);
								}
							}, "↻ " + _("Sync ISP"))
						])
					]),
					/* Progress Bar */
					E("div", { "style": "margin-bottom: 0.5rem;" }, [
						E("div", { "style": "display: flex; justify-content: space-between; font-size: 0.9rem; font-weight: bold; margin-bottom: 0.35rem;" }, [
							E("span", { "style": "color: #10b981;" }, smt.remain_gb + " GB " + _("Remaining")),
							E("span", { "style": "opacity: 0.7;" }, smt.used_gb + " GB " + _("Used") + " / " + smt.total_gb + " GB (" + pctStr + ")")
						]),
						E("div", { "style": "width: 100%; height: 10px; background: rgba(150, 150, 150, 0.2); border-radius: 5px; overflow: hidden;" }, [
							E("div", { "style": "width: " + pctStr + "; height: 100%; background: linear-gradient(90deg, #3b82f6, #10b981); border-radius: 5px;" })
						])
					])
				]);
			}

			var macToDeviceName = {};
			var macToDevId = {};
			if (self.deviceIdentitiesTsv) {
				var lines = self.deviceIdentitiesTsv.split("\n");
				lines.forEach(function(line) {
					var parts = line.split("\t");
					if (parts.length >= 5) {
						var devId = parts[0].trim();
						var devName = parts[1].trim();
						var macList = parts[4].split(",");
						macList.forEach(function(m) {
							var cleanM = m.trim().toLowerCase();
							if (cleanM) {
								macToDeviceName[cleanM] = devName;
								macToDevId[cleanM] = devId;
							}
						});
					}
				});
			}

			/* Build groups dictionary from UCI */
			var uciGroups = uci.sections("billing", "group");
			var groups = [];

			uciGroups.forEach(function(g, idx) {
				var name = g.name || "Group " + (idx + 1);
				var matches = L.toArray(g.match || []);
				var groupObj = {
					name: name,
					matches: matches.map(function(m) { return m.toLowerCase().trim(); }),
					rx: 0,
					tx: 0,
					totalBytes: 0,
					devices: {},
					color: PALETTE[idx % PALETTE.length]
				};
				groups.push(groupObj);
			});

			/* Catch-all group for devices not yet assigned */
			var unassignedGroup = {
				name: _("Other / Unassigned"),
				matches: [],
				rx: 0,
				tx: 0,
				totalBytes: 0,
				devices: {},
				color: "#94a3b8"
			};

			/* Only count household client devices on LAN (192.168.1.x / 192.168.3.x) */
			var records = dataset.data || [];
			var totalHouseholdBytes = 0;

			records.forEach(function(row) {
				var mac = (row[0] || "").toLowerCase();
				var ip = (row[1] || "").trim();
				var rx = row[3] || 0; /* Download */
				var tx = row[4] || 0; /* Upload */
				var total = rx + tx;

				/* Exclude router itself and upstream/WAN networks */
				if (!ip.startsWith("192.168.1.") && !ip.startsWith("192.168.3.")) {
					return;
				}
				if (ip === "192.168.1.1" || ip === "192.168.3.1") {
					return;
				}

				totalHouseholdBytes += total;

				/* Resolve hostname: device unifier > hostHints > ip */
				var hint = hostHints[mac.toUpperCase()] || {};
				var hostname = macToDeviceName[mac] || hint.name || ip;
				var devId = macToDevId[mac] || "";

				/* Find matching group */
				var matchedGroup = null;
				for (var i = 0; i < groups.length; i++) {
					var g = groups[i];
					for (var m = 0; m < g.matches.length; m++) {
						var pattern = g.matches[m];
						if (pattern === ip || pattern === mac || (devId && pattern === devId.toLowerCase()) || (hostname && hostname.toLowerCase().indexOf(pattern) !== -1)) {
							matchedGroup = g;
							break;
						}
					}
					if (matchedGroup) break;
				}

				if (!matchedGroup) {
					matchedGroup = unassignedGroup;
				}

				matchedGroup.rx += rx;
				matchedGroup.tx += tx;
				matchedGroup.totalBytes += total;

				/* Merge by canonical Device ID if valid, otherwise MAC, otherwise IP */
				var isValidMac = mac && mac !== "00:00:00:00:00:00" && mac.indexOf(":") !== -1;
				var devKey = devId ? devId : (isValidMac ? mac : ip);

				if (!matchedGroup.devices[devKey]) {
					matchedGroup.devices[devKey] = {
						primaryIp: ip,
						ips: [ip],
						mac: isValidMac ? mac : "",
						hostname: hostname,
						rx: 0,
						tx: 0,
						total: 0,
						mergedCount: 1
					};
				} else {
					if (matchedGroup.devices[devKey].ips.indexOf(ip) === -1 && ip) {
						matchedGroup.devices[devKey].ips.push(ip);
					}
					if (!matchedGroup.devices[devKey].hostname || matchedGroup.devices[devKey].hostname === matchedGroup.devices[devKey].primaryIp) {
						if (hostname && hostname !== ip) {
							matchedGroup.devices[devKey].hostname = hostname;
						}
					}
					matchedGroup.devices[devKey].mergedCount = (matchedGroup.devices[devKey].mergedCount || 1) + 1;
				}
				matchedGroup.devices[devKey].rx += rx;
				matchedGroup.devices[devKey].tx += tx;
				matchedGroup.devices[devKey].total += total;
				matchedGroup.devices[devKey].total += total;
			});

			if (unassignedGroup.totalBytes > 0 || groups.length === 0) {
				groups.push(unassignedGroup);
			}

			/* Sort groups by consumption descending */
			groups.sort(function(a, b) { return b.totalBytes - a.totalBytes; });

			/* Total bill calculation */
			var totalBillAmount = 0;
			if (billingMode === "per_gb") {
				var totalGB = totalHouseholdBytes / 1000000000;
				totalBillAmount = totalGB * costPerGb;
			} else {
				totalBillAmount = monthlyBudget;
			}

			/* Calculate share and individual bills */
			groups.forEach(function(g) {
				g.share = totalHouseholdBytes > 0 ? (g.totalBytes / totalHouseholdBytes) : 0;
				if (billingMode === "per_gb") {
					g.bill = (g.totalBytes / 1000000000) * costPerGb;
				} else {
					g.bill = g.share * monthlyBudget;
				}
			});

			/* 1. Summary Cards */
			var topUser = groups.length > 0 && groups[0].totalBytes > 0 ? groups[0].name : _("None");
			var cardsGrid = E("div", {
				"style": "display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin-bottom: 1.5rem;"
			}, [
				E("div", { "class": "cbi-section", "style": "padding: 1.25rem; border-radius: 12px; margin: 0;" }, [
					E("div", { "style": "opacity: 0.7; font-size: 0.85rem; text-transform: uppercase;" }, _("Total Household Traffic")),
					E("div", { "style": "font-size: 1.75rem; font-weight: bold; margin-top: 0.25rem; color: #3b82f6;" }, formatBytes(totalHouseholdBytes))
				]),
				E("div", { "class": "cbi-section", "style": "padding: 1.25rem; border-radius: 12px; margin: 0;" }, [
					E("div", { "style": "opacity: 0.7; font-size: 0.85rem; text-transform: uppercase;" }, _("Total Internet Bill")),
					E("div", { "style": "font-size: 1.75rem; font-weight: bold; margin-top: 0.25rem; color: #10b981;" }, formatMoney(totalBillAmount, currency))
				]),
				E("div", { "class": "cbi-section", "style": "padding: 1.25rem; border-radius: 12px; margin: 0;" }, [
					E("div", { "style": "opacity: 0.7; font-size: 0.85rem; text-transform: uppercase;" }, _("Top Data Consumer")),
					E("div", { "style": "font-size: 1.5rem; font-weight: bold; margin-top: 0.25rem;" }, topUser)
				]),
				E("div", { "class": "cbi-section", "style": "padding: 1.25rem; border-radius: 12px; margin: 0;" }, [
					E("div", { "style": "opacity: 0.7; font-size: 0.85rem; text-transform: uppercase;" }, _("Pricing Formula")),
					E("div", { "style": "font-size: 1.1rem; font-weight: bold; margin-top: 0.35rem;" },
						billingMode === "per_gb" ? formatMoney(costPerGb, currency) + " / GB" : _("Split Total: ") + formatMoney(monthlyBudget, currency))
				])
			]);

			/* 2. Visual Chart & Legend Section */
			var chartAndLegend = E("div", {
				"class": "cbi-section",
				"style": "padding: 1.5rem; border-radius: 12px; display: flex; flex-wrap: wrap; align-items: center; justify-content: space-around; gap: 2rem; margin-bottom: 1.5rem;"
			}, [
				self.renderSVGDonut(groups, totalHouseholdBytes),
				E("div", { "style": "flex: 1; min-width: 250px; display: flex; flex-direction: column; gap: 0.75rem;" },
					groups.map(function(g) {
						var percentStr = (g.share * 100).toFixed(1) + "%";
						return E("div", {}, [
							E("div", { "style": "display: flex; justify-content: space-between; font-size: 0.9rem; margin-bottom: 0.2rem;" }, [
								E("span", { "style": "display: flex; align-items: center; gap: 0.5rem; font-weight: bold;" }, [
									E("span", { "style": "display: inline-block; width: 12px; height: 12px; border-radius: 50%; background: " + g.color + ";" }),
									g.name
								]),
								E("span", {}, formatBytes(g.totalBytes) + " (" + percentStr + ")")
							]),
							E("div", { "style": "width: 100%; height: 8px; background: rgba(150,150,150,0.2); border-radius: 4px; overflow: hidden;" }, [
								E("div", { "style": "width: " + percentStr + "; height: 100%; background: " + g.color + "; border-radius: 4px;" })
							])
						]);
					})
				)
			]);

			/* 3. Unassigned Alert Banner (if any) */
			var unassignedBanner = null;
			if (unassignedGroup.totalBytes > 0) {
				var unassignedDevCount = Object.keys(unassignedGroup.devices).length;
				unassignedBanner = E("div", {
					"class": "cbi-section",
					"style": "padding: 1rem 1.25rem; border-radius: 12px; margin-bottom: 1.5rem; background: rgba(245, 158, 11, 0.1); border: 1px solid rgba(245, 158, 11, 0.3); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;"
				}, [
					E("div", { "style": "display: flex; align-items: center; gap: 0.75rem;" }, [
						E("span", { "style": "font-size: 1.5rem;" }, "⚠️"),
						E("div", {}, [
							E("strong", { "style": "color: #f59e0b;" }, _("Unassigned Devices Detected: ") + unassignedDevCount + " " + _("device(s)")),
							E("div", { "style": "font-size: 0.85rem; opacity: 0.85; margin-top: 0.2rem;" },
								_("Unassigned traffic: ") + formatBytes(unassignedGroup.totalBytes) + _(". Assign them to a person in Users & Pricing."))
						])
					]),
					E("a", {
						"class": "btn cbi-button cbi-button-action",
						"href": L.url("admin/services/billing/config"),
						"style": "font-weight: bold;"
					}, "⚙️ " + _("Assign Devices Now"))
				]);
			}

			/* 4. Detailed Group Breakdown Table */
			var tableRows = [];
			groups.forEach(function(g) {
				var devCount = Object.keys(g.devices).length;
				var row = E("tr", { "class": "tr" }, [
					E("td", { "class": "td", "style": "font-weight: bold; display: flex; align-items: center; gap: 0.5rem;" }, [
						E("span", { "style": "display: inline-block; width: 10px; height: 10px; border-radius: 50%; background: " + g.color + ";" }),
						g.name
					]),
					E("td", { "class": "td" }, devCount + " " + _("device(s)")),
					E("td", { "class": "td" }, formatBytes(g.rx)),
					E("td", { "class": "td" }, formatBytes(g.tx)),
					E("td", { "class": "td", "style": "font-weight: bold;" }, formatBytes(g.totalBytes)),
					E("td", { "class": "td" }, (g.share * 100).toFixed(1) + "%"),
					E("td", { "class": "td", "style": "font-weight: bold; color: #10b981;" }, formatMoney(g.bill, currency))
				]);

				tableRows.push(row);

				/* Device details accordion rows */
				Object.keys(g.devices).forEach(function(k) {
					var dev = g.devices[k];
					var ipListStr = dev.ips.join(", ");
					var devTitle = dev.hostname && dev.hostname !== dev.primaryIp ? dev.hostname : (dev.mac ? "Device " + dev.mac : dev.primaryIp);
					if (dev.mergedCount > 1) {
						devTitle += " (" + dev.mergedCount + " MACs merged)";
					}
					var idDetails = ipListStr + (dev.mac ? " (" + dev.mac + ")" : "");

					var subRow = E("tr", { "class": "tr", "style": "font-size: 0.85rem; opacity: 0.85; background: rgba(125,125,125,0.05);" }, [
						E("td", { "class": "td", "style": "padding-left: 2.5rem;" }, "↳ " + devTitle),
						E("td", { "class": "td", "style": "font-family: monospace;" }, idDetails),
						E("td", { "class": "td" }, formatBytes(dev.rx)),
						E("td", { "class": "td" }, formatBytes(dev.tx)),
						E("td", { "class": "td" }, formatBytes(dev.total)),
						E("td", { "class": "td" }, totalHouseholdBytes > 0 ? (dev.total / totalHouseholdBytes * 100).toFixed(1) + "%" : "0%"),
						E("td", { "class": "td" }, "-")
					]);
					tableRows.push(subRow);
				});
			});

			var breakdownTable = E("div", { "class": "cbi-section", "style": "padding: 1.25rem; border-radius: 12px;" }, [
				E("h3", {}, _("Detailed Breakdown & Share")),
				E("table", { "class": "table", "style": "width: 100%; border-collapse: collapse;" }, [
					E("thead", {}, [
						E("tr", { "class": "tr cbi-section-table-titles" }, [
							E("th", { "class": "th" }, _("User / Group")),
							E("th", { "class": "th" }, _("Devices")),
							E("th", { "class": "th" }, _("Download")),
							E("th", { "class": "th" }, _("Upload")),
							E("th", { "class": "th" }, _("Total Data")),
							E("th", { "class": "th" }, _("Share")),
							E("th", { "class": "th" }, _("Amount to Pay"))
						])
					]),
					E("tbody", {}, tableRows)
				])
			]);

			if (ispBanner) {
				dynamicArea.appendChild(ispBanner);
			}
			dynamicArea.appendChild(cardsGrid);
			dynamicArea.appendChild(chartAndLegend);
			if (unassignedBanner) {
				dynamicArea.appendChild(unassignedBanner);
			}
			dynamicArea.appendChild(breakdownTable);
		});
	}
});
