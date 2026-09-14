import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const model = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../Linux/Shared/Usage.js', import.meta.url), 'utf8'), model);
test('quota is clamped, missing quota stays unknown', () => {
    assert.equal(model.remaining({usedPercent: 28}), 72);
    assert.equal(model.remaining({usedPercent: 150}), 0);
    assert.equal(model.remaining({usedPercent: -5}), 100);
    for (const value of [null, {}, {usedPercent: null}, {usedPercent: '12'}, {usedPercent: Infinity}])
        assert.equal(model.remaining(value), null);
});
test('partial provider failures preserve healthy rows without leaking raw errors or identity', () => {
    const rows = model.rows(JSON.stringify([
        {provider: 'codex', usage: {primary: {usedPercent: 28, windowMinutes: 300}, identity: {accountEmail: 'private@example.com'}}},
        {provider: 'claude', error: {message: 'secret upstream response'}}
    ]));
    assert.equal(model.summary(rows), 'CX 72%  ·  CL —');
    assert.equal(rows[0].windows[0].label, '5 hour');
    assert.ok(rows[1].error);
    assert.ok(!JSON.stringify(rows).includes('secret'));
    assert.ok(!JSON.stringify(rows).includes('private'));
});
test('malformed and unrecognized responses cannot replace the last good snapshot', () => {
    for (const value of ['', '[]', '{}', 'null', '[null]', 'oops'])
        assert.throws(() => model.rows(value));
});
test('reset countdown handles invalid and elapsed timestamps', () => {
    const now = Date.parse('2026-01-01T00:00:00Z');
    assert.equal(model.resetLabel('bad', now), 'Reset time unavailable');
    assert.equal(model.resetLabel('2025-12-31T23:00:00Z', now), 'Reset due · refresh to update');
    assert.equal(model.resetLabel('2026-01-01T01:30:00Z', now), 'Resets in 1h 30m');
});
test('account selection is scoped to a single provider and arguments never use a shell', () => {
    const command = model.command({provider: 'both', allAccounts: true, accountIndex: 2});
    assert.ok(!command.includes('--all-accounts'));
    assert.ok(!command.includes('--account-index'));
    assert.ok(!model.command({provider: 'enabled'}).includes('--provider'));
    const single = model.command({provider: 'codex', allAccounts: true, source: 'oauth', executable: '/a path/codexbar'});
    assert.ok(single.includes('--all-accounts'));
    assert.ok(single.includes('/a path/codexbar'));
    assert.ok(single.includes('oauth'));
    assert.ok(!model.command({accountIndex: '2;bad'}).includes('--account-index'));
});
test('identity is opt-in and stays within its provider row', () => {
    const input = JSON.stringify([{provider: 'codex', usage: {identity: {accountEmail: 'one@example.com', loginMethod: 'pro'}}},
        {provider: 'claude', usage: {}}]);
    assert.equal(model.rows(input)[0].accountLabel, '');
    assert.equal(model.rows(input, true)[0].accountLabel, 'one@example.com');
    assert.equal(model.rows(input, true)[1].accountLabel, '');
    assert.equal(model.rows(input, true)[1].plan, '');
});
test('cost history preserves unknown amounts and uses the actual calendar day', () => {
    const input = JSON.stringify([{provider: 'codex', sessionCostUSD: 99, last30DaysCostUSD: 5,
        historyCoverageIsEstablished: true, daily: [{date: '2026-01-01', totalCost: 5}, {date: '2026-01-02', totalCost: null}]}]);
    const row = model.costs(input, '2026-01-02')[0];
    assert.equal(row.today, null);
    assert.equal(row.month, 5);
    assert.equal(row.chart.points.length, 1);
    assert.equal(model.costs(input, '2026-01-03')[0].today, 0);
    assert.equal(model.money(null), 'Unavailable');
    assert.equal(model.money(0), '$0.00');
});
test('generic charts bound data and keep negative values', () => {
    const result = model.chart({kind: 'line', points: [{label: 'a', value: -4}, {label: 'b', value: null}, {label: 'c', value: Infinity}]});
    assert.equal(result.points.length, 1);
    assert.equal(result.points[0].value, -4);
    assert.equal(model.chart(null), null);
    assert.equal(model.count(5358220), '5,358,220');
    assert.equal(model.count(null), '—');
});
test('provider detail rows redact emails unless explicitly enabled', () => {
    const input = JSON.stringify({provider: 'codex', usage: {details: [{rows: [{label: 'Account', value: 'private@example.com'}]}]}});
    assert.equal(model.rows(input)[0].details[0].rows[0].value, '[hidden email]');
    assert.equal(model.rows(input, true)[0].details[0].rows[0].value, 'private@example.com');
});

test('display preferences keep underlying quota and reset data intact', () => {
    assert.equal(model.quotaValue(60, 'used'), 40);
    assert.equal(model.quotaValue(60, 'remaining'), 60);
    assert.equal(model.resetText('invalid', 0, 'absolute'), 'Reset time unavailable');
    const time = '2030-01-01T00:00:00Z';
    assert.ok(model.resetText(time, 0, 'absolute').startsWith('Resets '));
    assert.ok(model.resetText(time, 0, 'both').includes(' · '));
});

test('tray lines stay compact and follow the quota display preference', () => {
    const now = Date.parse('2026-09-14T05:35:00Z');
    const claude = {provider: 'claude', windows: [
        {shortLabel: '5H', remaining: 53, resetsAt: '2026-09-14T09:00:00Z'},
        {shortLabel: '1W', remaining: 91, resetsAt: '2026-09-19T03:00:00Z'}]};
    assert.equal(model.trayLine(claude, 'remaining', now),
        'Claude: 53% (5H:3H 25M)/91% (1W:4D 21H)');
    assert.equal(model.trayLine(claude, 'used', now),
        'Claude: 47% (5H:3H 25M)/9% (1W:4D 21H)');
    // A provider with nothing to report must not render a bare "Codex: ".
    assert.equal(model.trayLine({provider: 'codex', windows: []}, 'remaining', now), 'Codex: —');
    // An unparsable reset drops the countdown rather than the whole window.
    assert.equal(model.trayLine({provider: 'codex', windows: [{shortLabel: '1W', remaining: 89, resetsAt: ''}]},
        'remaining', now), 'Codex: 89% (1W)');
});

test('compact window labels prefer the largest exact unit', () => {
    assert.equal(model.windowShort(10080), '1W');
    assert.equal(model.windowShort(20160), '2W');
    assert.equal(model.windowShort(1440), '1D');
    assert.equal(model.windowShort(300), '5H');
    assert.equal(model.windowShort(45), '45M');
    assert.equal(model.windowShort(0), '');
    assert.equal(model.windowShort(undefined), '');
});

test('short resets round up and never go negative', () => {
    const now = Date.parse('2026-09-14T00:00:00Z');
    assert.equal(model.shortReset('2026-09-14T00:30:00Z', now), '30M');
    assert.equal(model.shortReset('2026-09-14T03:29:00Z', now), '3H 29M');
    assert.equal(model.shortReset('2026-09-20T03:00:00Z', now), '6D 3H');
    assert.equal(model.shortReset('2026-09-13T00:00:00Z', now), '0M');
    assert.equal(model.shortReset('nonsense', now), '');
});

test('pace text translates known segments and passes the rest through', () => {
    // Identity translator: the English source must survive the round trip unchanged.
    assert.equal(model.paceText('On pace | Expected 12% used | Lasts until reset'),
        'On pace | Expected 12% used | Lasts until reset');
    assert.equal(model.paceText('22% in deficit | Expected 33% used | Projected empty in 1h 22m'),
        '22% in deficit | Expected 33% used | Projected empty in 1h 22m');
    assert.equal(model.paceText('21% in reserve | Runs out in 3d 4h'),
        '21% in reserve | Runs out in 3d 4h');
    // An unrecognised segment is preserved rather than dropped.
    assert.equal(model.paceText('On pace | Burning slowly'), 'On pace | Burning slowly');
    assert.equal(model.paceText(''), '');
    assert.equal(model.paceText(undefined), '');
});

test('pace segments translate through the installed translator', () => {
    model.setTranslator(text => ({
        'On pace': '정상 속도',
        'Expected %1% used': '예상 사용량 %1%',
        'Projected empty in %1': '%1 후 소진 예상',
        '%1h': '%1시간',
        '%1m': '%1분',
        'Partially Degraded Service': '부분 성능 저하',
    }[text] || text));
    assert.equal(model.paceText('On pace | Expected 12% used'), '정상 속도 | 예상 사용량 12%');
    assert.equal(model.paceText('Projected empty in 1h 22m'), '1시간 22분 후 소진 예상');
    assert.equal(model.statusText('Partially Degraded Service'), '부분 성능 저하');
    assert.equal(model.statusText('Something New'), 'Something New');
    model.setTranslator(null);
    assert.equal(model.paceText('On pace'), 'On pace');
});
