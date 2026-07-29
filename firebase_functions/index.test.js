'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {previousUtcWeek} = require('./index.js').__test;

test('previousUtcWeek returns the complete previous Monday-to-Monday window', () => {
  const result = previousUtcWeek(new Date('2026-07-29T18:30:00.000Z'));
  assert.equal(result.weekId, '2026-07-20');
  assert.equal(result.start.toISOString(), '2026-07-20T00:00:00.000Z');
  assert.equal(result.end.toISOString(), '2026-07-27T00:00:00.000Z');
});

test('previousUtcWeek is stable when called on a Monday', () => {
  const result = previousUtcWeek(new Date('2026-07-27T00:05:00.000Z'));
  assert.equal(result.weekId, '2026-07-20');
  assert.equal(result.end.toISOString(), '2026-07-27T00:00:00.000Z');
});
