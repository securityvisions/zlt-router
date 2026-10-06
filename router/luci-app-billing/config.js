"use strict";
"require view";
"require form";
"require uci";
"require rpc";

var callHostHints = rpc.declare({
	object: "luci-rpc",
	method: "getHostHints",
	expect: { "": {} }
});

return view.extend({
	load: function() {
		return Promise.all([
			uci.load("billing"),
			callHostHints()
		]);
	},

	render: function(data) {
		var hostHints = data[1] || {};
		var m, s, o;

		m = new form.Map("billing", _("Usage & Billing Configuration"),
			_("Group household devices into user profiles, set data pricing or shared monthly budget, and calculate fair bills automatically."));

		s = m.section(form.NamedSection, "main", "settings", _("Pricing & Currency Settings"));
		s.anonymous = false;

		o = s.option(form.ListValue, "billing_mode", _("Billing Calculation Mode"));
		o.value("per_gb", _("Pay-as-you-go: Cost per GB"));
		o.value("share_total", _("Shared Monthly Internet Bill (Split by % usage)"));
		o.default = "per_gb";

		o = s.option(form.Value, "cost_per_gb", _("Cost per GB"));
		o.datatype = "uinteger";
		o.default = "15000";
		o.description = _("Amount charged for each Gigabyte consumed.");
		o.depends("billing_mode", "per_gb");

		o = s.option(form.Value, "monthly_budget", _("Total Monthly ISP Bill"));
		o.datatype = "uinteger";
		o.default = "500000";
		o.description = _("Total internet invoice amount to be split proportionally across users according to their data percentage.");
		o.depends("billing_mode", "share_total");

		o = s.option(form.Value, "currency", _("Currency Symbol / Unit"));
		o.default = "Toman";
		o.description = _("e.g. Toman, IRR, USD, EUR, etc.");

		/* User Groups Section */
		s = m.section(form.GridSection, "group", _("User & Device Groups"),
			_("Create profiles for household members. Choose from the suggested discovered devices or type custom IP/MAC/Hostname."));
		s.addremove = true;
		s.anonymous = true;
		s.sortable = true;

		o = s.option(form.Value, "name", _("User / Group Name"));
		o.rmempty = false;
		o.placeholder = "e.g. Parsa, Dad, Living Room TV";

		o = s.option(form.DynamicList, "match", _("Assigned Devices"));
		o.rmempty = true;
		o.placeholder = _("Select a discovered device or enter IP/MAC");
		o.description = _("Click the field or dropdown to select from detected network devices.");

		/* Collect all detected network devices from host hints */
		var ignoreMacs = ["90:FB:5D:9D:1C:34", "92:FB:5D:9D:1C:36", "00:00:00:00:00:00"];
		var detectedDevices = [];

		Object.keys(hostHints).forEach(function(macUpper) {
			if (ignoreMacs.indexOf(macUpper) !== -1) return;
			var hint = hostHints[macUpper] || {};
			var name = hint.name || "";
			var ipaddrs = hint.ipaddrs || [];
			var macLower = macUpper.toLowerCase();

			if (ipaddrs.length > 0) {
				ipaddrs.forEach(function(ip) {
					if ((!ip.startsWith("192.168.1.") && !ip.startsWith("192.168.3.")) || ip === "192.168.1.1" || ip === "192.168.3.1") return;
					var label = (name ? name + " — " : "") + ip + " (" + macLower + ")";
					detectedDevices.push({
						val: ip,
						label: label
					});
					detectedDevices.push({
						val: macLower,
						label: label + " [by MAC]"
					});
					if (name) {
						detectedDevices.push({
							val: name,
							label: label + " [by Hostname]"
						});
					}
				});
			} else {
				var label = (name ? name + " — " : "") + macLower;
				detectedDevices.push({
					val: macLower,
					label: label
				});
			}
		});

		/* Populate dropdown options */
		detectedDevices.forEach(function(d) {
			o.value(d.val, d.label);
		});

		return m.render();
	}
});
