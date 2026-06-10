// Unit tests for octo-pagination-check.js (R5)
//
// Covers:
//   * shape mode: cursor ok / cursor+total anti-pattern / offset ok /
//     unknown shape / partial offset / non-object inputs never throw
//   * params mode: cursor response needs `cursor` param, offset response
//     needs `page` param, both happy + sad paths, ops without pagination pass

import octoPaginationCheck from '../../octo-api/assets/functions/octo-pagination-check.js';

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

function violates(input, mode) {
  const r = octoPaginationCheck(input, { mode });
  return Array.isArray(r) && r.length > 0;
}

function passes(input, mode) {
  return octoPaginationCheck(input, { mode }) === undefined;
}

console.log('Testing octo-pagination-check.js...\n');

// ============================================================
// Mode: shape
// ============================================================
console.log('mode: shape');
const cursorShape = { type: 'object', properties: { has_more: { type: 'boolean' }, next_cursor: { type: 'string' } } };
const cursorMinimal = { type: 'object', properties: { has_more: { type: 'boolean' } } };
const offsetShape = { type: 'object', properties: { total: { type: 'integer' }, page: { type: 'integer' }, page_size: { type: 'integer' } } };
const cursorWithTotal = { type: 'object', properties: { has_more: { type: 'boolean' }, next_cursor: { type: 'string' }, total: { type: 'integer' } } };
const unknownShape = { type: 'object', properties: { next_offset: { type: 'integer' } } };
const partialOffset = { type: 'object', properties: { total: { type: 'integer' }, page: { type: 'integer' } } };

assert('cursor {has_more, next_cursor} → pass', passes(cursorShape, 'shape'));
assert('cursor {has_more} only → pass (next_cursor optional)', passes(cursorMinimal, 'shape'));
assert('offset {total, page, page_size} → pass', passes(offsetShape, 'shape'));
assert('cursor + total → violation (anti-pattern)', violates(cursorWithTotal, 'shape'));
assert('unknown {next_offset} → violation', violates(unknownShape, 'shape'));
assert('partial offset {total, page} → violation', violates(partialOffset, 'shape'));
assert('schema without properties → pass (cannot judge)', passes({ type: 'object' }, 'shape'));
assert('null input → undefined, no throw', octoPaginationCheck(null, { mode: 'shape' }) === undefined);
assert('string input → undefined, no throw', octoPaginationCheck('x', { mode: 'shape' }) === undefined);

// ============================================================
// Mode: params
// ============================================================
console.log('\nmode: params');

function op(paginationProps, params) {
  return {
    parameters: params,
    responses: {
      '200': {
        content: {
          'application/json': {
            schema: {
              type: 'object',
              properties: {
                data: { type: 'array', items: {} },
                pagination: { type: 'object', properties: paginationProps },
              },
            },
          },
        },
      },
    },
  };
}

const cursorProps = { has_more: { type: 'boolean' }, next_cursor: { type: 'string' } };
const offsetProps = { total: { type: 'integer' }, page: { type: 'integer' }, page_size: { type: 'integer' } };

assert('cursor response + cursor param → pass',
  passes(op(cursorProps, [{ name: 'cursor', in: 'query' }]), 'params'));
assert('cursor response, no params → violation',
  violates(op(cursorProps, undefined), 'params'));
assert('cursor response, only page_size param → violation',
  violates(op(cursorProps, [{ name: 'page_size', in: 'query' }]), 'params'));
assert('cursor param in path (not query) → violation',
  violates(op(cursorProps, [{ name: 'cursor', in: 'path' }]), 'params'));
assert('offset response + page param → pass',
  passes(op(offsetProps, [{ name: 'page', in: 'query' }]), 'params'));
assert('offset response, no page param → violation',
  violates(op(offsetProps, [{ name: 'page_size', in: 'query' }]), 'params'));
assert('non-paginated response → pass',
  passes({ responses: { '200': { content: { 'application/json': { schema: { type: 'object', properties: { data: {} } } } } } } }, 'params'));
assert('op without responses → pass', passes({}, 'params'));
assert('4xx-only pagination ignored → pass',
  passes({ responses: { '400': { content: { 'application/json': { schema: { type: 'object', properties: { pagination: { properties: cursorProps } } } } } } } }, 'params'));
assert('null input → undefined, no throw', octoPaginationCheck(null, { mode: 'params' }) === undefined);

// ============================================================
// Unknown / missing mode
// ============================================================
console.log('\nmode handling');
assert('unknown mode → undefined', octoPaginationCheck(cursorShape, { mode: 'magic' }) === undefined);
assert('missing opts → undefined', octoPaginationCheck(cursorShape) === undefined);

console.log(`\nTotal: ${pass + fail}   Pass: ${pass}   Fail: ${fail}`);
if (fail > 0) {
  process.exit(1);
}
