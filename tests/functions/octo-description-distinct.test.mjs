// Unit tests for octo-description-distinct.js (R13)
//
// Covers: exact dup, normalized dup (case / trailing period / whitespace),
// distinct pass, missing fields pass, non-object inputs never throw.

import octoDescriptionDistinct from '../../octo-api/assets/functions/octo-description-distinct.js';

let pass = 0;
let fail = 0;

function assert(name, condition) {
  if (condition) {
    pass++;
    console.log(`  ✅ ${name}`);
  } else {
    fail++;
    console.log(`  ❌ ${name}`);
  }
}

function violates(input) {
  const r = octoDescriptionDistinct(input);
  return Array.isArray(r) && r.length > 0;
}

function passes(input) {
  return octoDescriptionDistinct(input) === undefined;
}

console.log('Testing octo-description-distinct.js...\n');

assert('exact duplicate → violation',
  violates({ summary: 'List matters', description: 'List matters' }));
assert('dup modulo trailing period → violation',
  violates({ summary: 'List matters', description: 'List matters.' }));
assert('dup modulo case → violation',
  violates({ summary: 'List Matters', description: 'list matters' }));
assert('dup modulo surrounding whitespace → violation',
  violates({ summary: '  List matters ', description: 'List matters' }));
assert('description adds info → pass',
  passes({ summary: 'Delete matter', description: 'Idempotent: returns 200 even if already deleted.' }));
assert('description extends summary text → pass (substring is not equality)',
  passes({ summary: 'List matters', description: 'List matters owned by the caller, newest first.' }));
assert('missing description → pass (presence is operation-description rule)',
  passes({ summary: 'List matters' }));
assert('missing summary → pass (presence is octo-summary-required rule)',
  passes({ description: 'Something.' }));
assert('empty strings → pass',
  passes({ summary: '', description: '' }));
assert('null input → undefined, no throw', octoDescriptionDistinct(null) === undefined);
assert('string input → undefined, no throw', octoDescriptionDistinct('x') === undefined);

console.log(`\nTotal: ${pass + fail}   Pass: ${pass}   Fail: ${fail}`);
if (fail > 0) {
  process.exit(1);
}
