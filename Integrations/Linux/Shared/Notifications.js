// In-memory transitions only: never notify on startup, errors, or ambiguous accounts.

// Translation hook, matching Usage.js: the Qt desktop's QJSEngine installs a bridge, and
// plain-JS consumers such as the offline Node tests keep the English identity default.
var translate = function(text) {
    return typeof qsTranslate === "function" ? qsTranslate("Notifications", text) : text;
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

function transition(previous, entries, threshold) {
    var limit = Math.max(1, Math.min(99, Number(threshold) || 10));
    var counts = {};
    entries.forEach(function(row) { counts[row.provider] = (counts[row.provider] || 0) + 1; });
    var next = {};
    var events = [];
    entries.forEach(function(row) {
        if (counts[row.provider] !== 1 || row.failed) return;
        row.windows.forEach(function(window) {
            var key = row.provider + "/" + window.key;
            var old = previous[key];
            next[key] = {remaining: window.remaining, reset: window.resetsAt};
            if (!old) return;
            if (old.remaining > limit && window.remaining <= limit) {
                events.push({kind: "low", provider: row.provider,
                    message: format("%1: %2% quota remaining.", window.label, window.remaining)});
            } else if (old.reset && window.resetsAt && old.reset !== window.resetsAt && window.remaining > old.remaining) {
                events.push({kind: "reset", provider: row.provider,
                    message: format("%1 quota reset · %2% remaining.", window.label, window.remaining)});
            }
        });
        var level = row.statusLevel;
        if (["none", "minor", "major", "critical", "maintenance"].indexOf(level) !== -1) {
            var key = row.provider + "/status";
            var old = previous[key];
            next[key] = {level: level};
            if (old && old.level !== level) {
                if (level === "none") events.push({kind: "status", provider: row.provider,
                    message: translate("Service has recovered.")});
                else events.push({kind: "status", provider: row.provider,
                    message: format("Service status changed: %1.", level)});
            }
        }
    });
    return {state: next, events: events};
}

function summary(entries) {
    return entries.map(function(row) {
        var text = row.provider.toUpperCase();
        row.windows.forEach(function(window) {
            text += "\n" + format("%1: %2% remaining", window.label, window.remaining);
        });
        if (row.error) text += "\n" + row.error;
        return text;
    }).join("\n\n");
}
