'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { validateIssue } = require('../.github/scripts/validate-issue.cjs');
const body = (fields) => Object.entries(fields).map(([k, v]) => `### ${k}\n\n${v}\n`).join('\n');
const bugFields = {
  'Bug summary': 'Notes frame will not open',
  'Steps to reproduce': 'Open the notes window and click the button',
  'Expected behavior': 'The notes window opens',
  'Support ID': '12345678-1234-4123-8123-123456789abc',
  'Technical log': 'Addon: Character Notes\nVersion: 1.13.4\nError: example\nStacktrace: ...',
};
test('valid bug report passes', () => {
  assert.equal(validateIssue({ title: '[Bug] Notes fail', labels: [{name:'bug'}], body: body(bugFields) }).valid, true);
});
test('missing technical log fails', () => {
  const fields = {...bugFields}; delete fields['Technical log'];
  const result = validateIssue({title:'[Bug] Notes fail',labels:['bug'],body:body(fields)});
  assert.equal(result.valid, false);
  assert.match(result.errors.join(' '), /Technical log/);
});
test('empty and placeholder fields fail', () => {
  const result = validateIssue({title:'[Bug] Notes fail', labels:['bug'],body:body({...bugFields, 'Support ID':'_No response_'})});
  assert.equal(result.valid, false);
});
test('feature request passes without optional addon log', () => {
  assert.equal(validateIssue({title:'[Feature] Add search',labels:['feature-request'],body:body({
    'Feature summary':'Search', 'Problem or motivation':'Too many notes',
    'Proposed behavior':'Add a search field', 'Support ID':'abcdef',
  })}).valid, true);
});
test('feedback passes without optional addon log', () => {
  assert.equal(validateIssue({title:'[Feedback] Great tool',labels:['feedback'],body:body({
    'Feedback topic':'UI', 'Your feedback':'Simple and useful', 'Support ID':'abcdef',
  })}).valid, true);
});
test('missing or ambiguous labels fail', () => {
  for (const labels of [[],['bug','feedback']]) {
    assert.equal(validateIssue({title:'[Bug] Test',labels,body:body(bugFields)}).valid, false);
  }
});
test('prefix without description fails', () => {
  assert.equal(validateIssue({title:'[Bug] ',labels:['bug'],body:body(bugFields)}).valid, false);
});
