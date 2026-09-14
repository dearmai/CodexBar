// Pure model shared by the QML frontend and offline Node tests.

// Translation hook. Under QML the default resolves through the engine's own catalogs,
// which works inside a binding; the Qt desktop's QJSEngine has no qsTranslate and installs
// a bridge instead. Plain-JS consumers such as the offline Node tests keep English.
var translate = function(text) {
    return typeof qsTranslate === "function" ? qsTranslate("Usage", text) : text;
};

function setTranslator(fn) {
    translate = typeof fn === "function" ? fn : function(text) { return text; };
}

// Translate then substitute, so a translation may reorder its placeholders.
function format(text, first, second) {
    return translate(text)
        .replace(/%1/g, function() { return String(first); })
        .replace(/%2/g, function() { return String(second); });
}

function remaining(window) {
    if (!window || typeof window.usedPercent !== "number" || !isFinite(window.usedPercent)) return null;
    return Math.round(Math.max(0, Math.min(100, 100 - window.usedPercent)));
}

function rows(text, showIdentity) {
    var decoded = JSON.parse(text);
    var entries = Array.isArray(decoded) ? decoded : [decoded];
    if (!entries.length || entries.some(function(e) { return !e || typeof e.provider !== "string"; }))
        throw new Error("Invalid usage response");
    return entries.map(function(entry, entryIndex) {
        var usage = entry.usage || {};
        var identity = usage.identity || {};
        var windows = [];
        ["primary", "secondary", "tertiary"].forEach(function(key, index) {
            var window = usage[key];
            var left = remaining(window);
            if (left === null) return;
            var minutes = window.windowMinutes;
            var label = minutes >= 1440 ? format("%1 day", minutes / 1440) :
                minutes > 0 ? format("%1 hour", minutes / 60) :
                [translate("Session"), translate("Weekly"), translate("Additional")][index];
            windows.push({key: key, label: label, shortLabel: windowShort(minutes), remaining: left,
                resetsAt: window.resetsAt || "",
                pace: entry.pace && entry.pace[key] ? paceText(entry.pace[key].summary) : ""});
        });
        return {
            provider: entry.provider,
            failed: !!entry.error,
            accountLabel: showIdentity ? String(identity.accountEmail || usage.accountEmail || "") : "",
            accountNumber: entryIndex + 1,
            plan: String(identity.loginMethod || usage.loginMethod || ""),
            status: entry.status ? statusText(entry.status.description || entry.status.indicator) || translate("Unknown") : "",
            statusLevel: entry.status ? String(entry.status.indicator || "unknown") : "unknown",
            details: Array.isArray(usage.details) ? usage.details.slice(0, 8).map(function(section) {
                return {title: String(section.title || ""), rows: (section.rows || []).slice(0, 24).map(function(row) {
                    return {label: String(row.label || ""), value: displayText(row.value, showIdentity),
                        secondaryValue: displayText(row.secondaryValue, showIdentity)};
                }), chart: chart(section.chart)};
            }) : [],
            source: entry.source || "",
            windows: windows,
            updatedAt: usage.updatedAt || "",
            credits: entry.credits && typeof entry.credits.remaining === "number" ? entry.credits.remaining : null,
            error: entry.error ? translate("Usage unavailable. Check this provider’s CodexBar login/configuration.") :
                windows.length ? "" : translate("No quota windows reported.")
        };
    });
}

function command(settings) {
    var provider = String(settings.provider || "codex");
    var args = ["timeout", "--kill-after=5", "60", String(settings.executable || "codexbar"),
        "usage", "--format", "json", "--json-only"];
    if (provider !== "enabled") args.push("--provider", provider);
    var source = String(settings.source || "auto");
    if (source !== "auto") args.push("--source", source);
    if (settings.showStatus !== false) args.push("--status");
    if (["enabled", "all", "both"].indexOf(provider) === -1) {
        if (settings.allAccounts === true) args.push("--all-accounts");
        else if (Number.isInteger(Number(settings.accountIndex)) && Number(settings.accountIndex) > 0)
            args.push("--account-index", String(settings.accountIndex));
    }
    return args;
}

function paceDuration(text) {
    return String(text).replace(/(\d+)\s*([dhms])\b/g, function(whole, value, unit) {
        var key = {d: "%1d", h: "%1h", m: "%1m", s: "%1s"}[unit];
        return key ? format(key, value) : whole;
    });
}

function paceSegment(segment) {
    var text = String(segment).trim();
    var match;
    if (text === "On pace") return translate("On pace");
    if ((match = /^(\d+)% in deficit$/.exec(text))) return format("%1% in deficit", match[1]);
    if ((match = /^(\d+)% in reserve$/.exec(text))) return format("%1% in reserve", match[1]);
    if ((match = /^Expected (\d+)% used$/.exec(text))) return format("Expected %1% used", match[1]);
    if (text === "Lasts until reset") return translate("Lasts until reset");
    if (text === "Projected empty now") return translate("Projected empty now");
    if ((match = /^Projected empty in (.+)$/.exec(text))) return format("Projected empty in %1", paceDuration(match[1]));
    if (text === "Runs out now") return translate("Runs out now");
    if ((match = /^Runs out in (.+)$/.exec(text))) return format("Runs out in %1", paceDuration(match[1]));
    return text;
}

function paceText(summary) {
    if (!summary) return "";
    return String(summary).split(" | ").map(paceSegment).join(" | ");
}

// Provider status pages report these in English; anything unrecognised passes through.
function statusText(description) {
    var text = String(description || "");
    return text ? translate(text) : text;
}

function displayText(value, showIdentity) {
    var text = String(value || "").slice(0, 500);
    return showIdentity ? text : text.replace(/[^\s@]+@[^\s@]+/g, translate("[hidden email]"));
}

function chart(value) {
    if (!value || !Array.isArray(value.points)) return null;
    var points = value.points.slice(0, 120).filter(function(point) {
        return point && typeof point.value === "number" && isFinite(point.value);
    }).map(function(point) { return {label: String(point.label || ""), value: point.value}; });
    return {title: String(value.title || ""), unit: String(value.unit || ""),
        kind: value.kind === "line" ? "line" : "bars", points: points};
}

function number(value) { return typeof value === "number" && isFinite(value) ? value : null; }

function money(value) { return number(value) === null ? translate("Unavailable") : "$" + value.toFixed(2); }

function count(value) {
    return number(value) === null ? "—" : Math.round(value).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function provenance(value) {
    return {listPriceEstimate: translate("List-price estimate"), actual: translate("Reported cost"),
        unknown: translate("Cost source unavailable")}[value] || value;
}

function costs(text, today) {
    if (!today) {
        var now = new Date();
        today = now.getFullYear() + "-" + String(now.getMonth() + 1).padStart(2, "0") + "-" + String(now.getDate()).padStart(2, "0");
    }
    var decoded = JSON.parse(text);
    if (!Array.isArray(decoded) || decoded.some(function(row) { return !row || typeof row.provider !== "string"; }))
        throw new Error("Invalid cost response");
    return decoded.map(function(row) {
        var totals = row.totals || {};
        var daily = Array.isArray(row.daily) ? row.daily.slice(-30) : [];
        var todayRow = daily.find(function(day) { return day.date === today; });
        return {provider: row.provider, today: todayRow ? number(todayRow.totalCost) :
                row.historyCoverageIsEstablished === true && !row.error ? 0 : null, month: number(row.last30DaysCostUSD),
            tokens: number(row.last30DaysTokens), input: number(totals.inputTokens), output: number(totals.outputTokens),
            cached: number(totals.cacheReadTokens), provenance: String(row.provenance || "unknown"),
            coverage: row.historyCoverageIsEstablished === true ? translate("Local history")
                : translate("History may be incomplete"),
            error: row.error ? translate("Local cost history unavailable") : "",
            chart: chart({title: translate("Recorded daily cost · USD"), unit: "USD", kind: "bars",
                points: daily.map(function(day) { return {label: day.date, value: day.totalCost}; })})};
    });
}

function summary(entries, mode) {
    var label = entries.slice(0, 2).map(function(entry) {
        var label = entry.provider === "codex" ? "CX" : entry.provider === "claude" ? "CL" : entry.provider;
        return label + " " + (entry.windows.length ? quotaValue(entry.windows[0].remaining, mode) + "%" : "—");
    }).join("  ·  ");
    return label + (entries.length > 2 ? "  +" + (entries.length - 2) : "");
}

function resetLabel(value, now) {
    var timestamp = Date.parse(value);
    if (!isFinite(timestamp)) return translate("Reset time unavailable");
    var minutes = Math.ceil((timestamp - now) / 60000);
    if (minutes <= 0) return translate("Reset due · refresh to update");
    if (minutes < 60) return format("Resets in %1m", minutes);
    if (minutes < 1440) return format("Resets in %1h %2m", Math.floor(minutes / 60), minutes % 60);
    return format("Resets in %1d %2h", Math.floor(minutes / 1440), Math.floor(minutes % 1440 / 60));
}

function providerName(id) {
    var names = {codex: "Codex", claude: "Claude", copilot: "GitHub Copilot", gemini: "Gemini",
        cursor: "Cursor", antigravity: "Antigravity", openrouter: "OpenRouter", kiro: "Kiro"};
    return names[id] || (id ? id.charAt(0).toUpperCase() + id.slice(1) : translate("Unknown provider"));
}

function quotaValue(remaining, mode) { return mode === "used" ? 100 - remaining : remaining; }

// Compact, locale-independent forms for the tray, where width is scarce: "5H", "1W", "6D 3H".
function windowShort(minutes) {
    if (!(minutes > 0)) return "";
    if (minutes % 10080 === 0) return (minutes / 10080) + "W";
    if (minutes % 1440 === 0) return (minutes / 1440) + "D";
    if (minutes % 60 === 0) return (minutes / 60) + "H";
    return minutes + "M";
}

function shortReset(value, now) {
    var timestamp = Date.parse(value);
    if (!isFinite(timestamp)) return "";
    var minutes = Math.ceil((timestamp - now) / 60000);
    if (minutes <= 0) return "0M";
    if (minutes < 60) return minutes + "M";
    if (minutes < 1440) return Math.floor(minutes / 60) + "H " + minutes % 60 + "M";
    return Math.floor(minutes / 1440) + "D " + Math.floor(minutes % 1440 / 60) + "H";
}

// One line per provider: "Claude: 53% (5H:3H 29M)/91% (1W:4D 21H)". The percentage follows the
// quota display preference, so this reads the same way as the windows do.
function trayLine(entry, mode, now) {
    var windows = (entry.windows || []).map(function(window) {
        var detail = [window.shortLabel, shortReset(window.resetsAt, now)].filter(function(piece) {
            return piece;
        });
        return quotaValue(window.remaining, mode) + "%" + (detail.length ? " (" + detail.join(":") + ")" : "");
    });
    return providerName(entry.provider) + ": " + (windows.length ? windows.join("/") : "\u2014");
}

function resetText(timestamp, now, mode) {
    var date = new Date(timestamp);
    if (!timestamp || !isFinite(date.getTime())) return translate("Reset time unavailable");
    var absolute = date.toLocaleString();
    if (mode === "absolute") return format("Resets %1", absolute);
    if (mode === "both") return resetLabel(timestamp, now) + " · " + absolute;
    return resetLabel(timestamp, now);
}
