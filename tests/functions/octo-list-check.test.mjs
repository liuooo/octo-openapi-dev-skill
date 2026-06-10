// Unit tests for octo-list-check.js
//
// Run with:
//   node tools/octo-api/functions/octo-list-check.test.mjs
//
// Verifies:
//   * 5 modes (forbidden / forbidden-segment / required-prefix /
//     required-suffix / required-substring) on happy + sad paths
//   * Returns undefined for invalid inputs (non-string, empty list,
//     missing mode, unknown mode) — never throws
//   * Custom message vs default message
//   * Edge cases: empty input string, repeated slashes in path,
//     trailing/leading slashes

import octoListCheck from '../../octo-api/assets/functions/octo-list-check.js';

let pass = 0;
let fail = 0;
const failures = [];

function assert(name, condition, detail) {
  if (condition) {
    pass++;
    console.log(`  ✅ ${name}`);
  } else {
    fail++;
    failures.push({ name, detail });
    console.log(`  ❌ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

function violates(input, opts) {
  const r = octoListCheck(input, opts);
  return Array.isArray(r) && r.length > 0;
}

function passes(input, opts) {
  return octoListCheck(input, opts) === undefined;
}

console.log('Testing octo-list-check.js...\n');

// ============================================================
// Mode: forbidden
// ============================================================
console.log('mode: forbidden');
assert('uid is in [uid, robot_id] → violation',
  violates('uid', { mode: 'forbidden', list: ['uid', 'robot_id'] }));
assert('user_id is NOT in [uid, robot_id] → pass',
  passes('user_id', { mode: 'forbidden', list: ['uid', 'robot_id'] }));
assert('case-sensitive: UID is NOT in [uid] → pass',
  passes('UID', { mode: 'forbidden', list: ['uid'] }));

// ============================================================
// Mode: forbidden-segment
// ============================================================
console.log('\nmode: forbidden-segment');
assert('/matter/{id} contains "matter" segment → violation',
  violates('/matter/{id}', { mode: 'forbidden-segment', list: ['matter'] }));
assert('/matters/{id} contains only "matters" → pass',
  passes('/matters/{id}', { mode: 'forbidden-segment', list: ['matter'] }));
assert('leading slash filtered: /matter → still hits',
  violates('/matter', { mode: 'forbidden-segment', list: ['matter'] }));
assert('substring not enough: /matter_extras → pass (segment must equal)',
  passes('/matter_extras', { mode: 'forbidden-segment', list: ['matter'] }));
assert('nested: /v1/group/{id}/member → "group" segment hits',
  violates('/v1/group/{id}/member', { mode: 'forbidden-segment', list: ['group'] }));
assert('plural-only path: /v1/groups/{id}/members → pass',
  passes('/v1/groups/{id}/members', { mode: 'forbidden-segment', list: ['group', 'member'] }));

// ============================================================
// Mode: required-prefix
// ============================================================
console.log('\nmode: required-prefix');
assert('is_active starts with is_ → pass',
  passes('is_active', { mode: 'required-prefix', list: ['is_', 'has_', 'can_'] }));
assert('active does not start with is_/has_/can_ → violation',
  violates('active', { mode: 'required-prefix', list: ['is_', 'has_', 'can_'] }));
assert('has_permission starts with has_ → pass',
  passes('has_permission', { mode: 'required-prefix', list: ['is_', 'has_', 'can_'] }));
assert('case-sensitive: Is_active → violation',
  violates('Is_active', { mode: 'required-prefix', list: ['is_'] }));

// ============================================================
// Mode: required-suffix
// ============================================================
console.log('\nmode: required-suffix');
assert('created_at ends with _at → pass',
  passes('created_at', { mode: 'required-suffix', list: ['_at', '_date'] }));
assert('created does not end with _at/_date → violation',
  violates('created', { mode: 'required-suffix', list: ['_at', '_date'] }));
assert('birth_date ends with _date → pass',
  passes('birth_date', { mode: 'required-suffix', list: ['_at', '_date'] }));
assert('case-sensitive: created_AT → violation',
  violates('created_AT', { mode: 'required-suffix', list: ['_at'] }));

// ============================================================
// Mode: required-substring
// ============================================================
console.log('\nmode: required-substring');
assert('#/components/schemas/UserEnvelope contains Envelope → pass',
  passes('#/components/schemas/UserEnvelope',
         { mode: 'required-substring', list: ['Envelope', 'Data', 'Error'] }));
assert('#/components/schemas/RawUser contains none of [Envelope, Data, Error] → violation',
  violates('#/components/schemas/RawUser',
           { mode: 'required-substring', list: ['Envelope', 'Data', 'Error'] }));
assert('#/components/schemas/ErrorResp contains Error → pass',
  passes('#/components/schemas/ErrorResp',
         { mode: 'required-substring', list: ['Envelope', 'Error'] }));

// ============================================================
// Invalid inputs — never throw, return undefined
// ============================================================
console.log('\ninvalid inputs');
assert('non-string input (number) → undefined',
  octoListCheck(42, { mode: 'forbidden', list: ['42'] }) === undefined);
assert('non-string input (null) → undefined',
  octoListCheck(null, { mode: 'forbidden', list: ['null'] }) === undefined);
assert('non-string input (undefined) → undefined',
  octoListCheck(undefined, { mode: 'forbidden', list: ['x'] }) === undefined);
assert('non-string input (array) → undefined',
  octoListCheck(['uid'], { mode: 'forbidden', list: ['uid'] }) === undefined);
assert('empty list → undefined',
  octoListCheck('uid', { mode: 'forbidden', list: [] }) === undefined);
assert('missing list → undefined',
  octoListCheck('uid', { mode: 'forbidden' }) === undefined);
assert('list is not array → undefined',
  octoListCheck('uid', { mode: 'forbidden', list: 'uid' }) === undefined);
assert('missing mode → undefined',
  octoListCheck('uid', { list: ['uid'] }) === undefined);
assert('unknown mode → undefined',
  octoListCheck('uid', { mode: 'magic', list: ['uid'] }) === undefined);
assert('null opts → undefined',
  octoListCheck('uid', null) === undefined);
assert('undefined opts → undefined',
  octoListCheck('uid', undefined) === undefined);

// ============================================================
// Edge: empty input string
// ============================================================
console.log('\nempty input');
assert('empty string + required-prefix [is_] → violation (empty does not match)',
  violates('', { mode: 'required-prefix', list: ['is_'] }));
assert('empty string + forbidden ["uid"] → pass (empty != uid)',
  passes('', { mode: 'forbidden', list: ['uid'] }));
assert('empty string + forbidden-segment ["matter"] → pass',
  passes('', { mode: 'forbidden-segment', list: ['matter'] }));

// ============================================================
// Message customization
// ============================================================
console.log('\nmessage customization');
const r1 = octoListCheck('uid', {
  mode: 'forbidden',
  list: ['uid'],
  message: 'custom violation',
});
assert('custom message returned',
  Array.isArray(r1) && r1[0].message === 'custom violation');

const r2 = octoListCheck('uid', { mode: 'forbidden', list: ['uid'] });
assert('default message contains value + mode',
  Array.isArray(r2) && r2[0].message.includes('uid') && r2[0].message.includes('forbidden'));


// ============================================================
// Mode: forbidden-suffix (new)
// ============================================================
console.log('\nmode: forbidden-suffix');
assert('start_time ends with _time → violation',
  violates('start_time', { mode: 'forbidden-suffix', list: ['_time', '_ts', '_timestamp'] }));
assert('login_ts ends with _ts → violation',
  violates('login_ts', { mode: 'forbidden-suffix', list: ['_time', '_ts', '_timestamp'] }));
assert('created_timestamp ends with _timestamp → violation',
  violates('created_timestamp', { mode: 'forbidden-suffix', list: ['_time', '_ts', '_timestamp'] }));
assert('created_at → pass',
  passes('created_at', { mode: 'forbidden-suffix', list: ['_time', '_ts', '_timestamp'] }));
assert('counts → pass (suffix match is literal, not segment)',
  passes('counts', { mode: 'forbidden-suffix', list: ['_ts'] }));

// ============================================================
// Mode: required-key-prefix (new, object input)
// ============================================================
console.log('\nmode: required-key-prefix');
assert('responses {200, 400} has a 2-prefixed key → pass',
  passes({ '200': {}, '400': {} }, { mode: 'required-key-prefix', list: ['2'] }));
assert('responses {201} → pass',
  passes({ '201': {} }, { mode: 'required-key-prefix', list: ['2'] }));
assert('responses {400, 500} lacks 2xx → violation',
  violates({ '400': {}, '500': {} }, { mode: 'required-key-prefix', list: ['2'] }));
assert('empty object → violation',
  violates({}, { mode: 'required-key-prefix', list: ['2'] }));
assert('string input with object-only mode → undefined',
  octoListCheck('200', { mode: 'required-key-prefix', list: ['2'] }) === undefined);
assert('array input → undefined (arrays are not key maps)',
  octoListCheck(['200'], { mode: 'required-key-prefix', list: ['2'] }) === undefined);
assert('object input with string-only mode → undefined',
  octoListCheck({ a: 1 }, { mode: 'forbidden', list: ['a'] }) === undefined);

// ============================================================
// Summary
// ============================================================
console.log(`\nTotal: ${pass + fail}   Pass: ${pass}   Fail: ${fail}`);
if (fail > 0) {
  process.exit(1);
}
