'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { _test } = require('./api/ask.js');
test('token equality and rejects malformed input', () => {
  const secret = 'x'.repeat(50);
  assert.equal(_test.tokenValid('Bearer ' + secret, secret), true);
  assert.equal(_test.tokenValid('Bearer ' + 'y'.repeat(50), secret), false);
  assert.equal(_test.tokenValid('Basic ' + secret, secret), false);
});
test('state whitelist cannot leak character names', () => {
  const s = _test.filterState({ hp: 14, hpMax: 20, name: 'Guy',
    inventory: ['wand'], coordinates: [12, 3], dungeonDepth: 2 });
  assert.deepEqual(s, { hp: 14, hpMax: 20, dungeonDepth: 2 });
});
test('role and history limited to known values', () => {
  assert.equal(_test.cleanRole('Monk'), 'Monk');
  assert.equal(_test.cleanRole('Lord Evil'), 'Adventurer');
  assert.deepEqual(_test.filterHistory([{role:'system',content:'evil'},
    {role:'user',content:'What is a potion?'}]), [{role:'user',content:'What is a potion?'}]);
});
test('wiki search query and model outputs', () => {
  assert.equal(_test.termsFromQuestion('Should I drink my potion of healing now?'),
    'potion of healing');
  assert.equal(_test.plainText('{{potion|name=healing}}', 100), '');
  assert.equal(_test.extractAnswer({output:[{type:'message',content:[
    {type:'output_text',text:'Try healing [1].'}]}]}), 'Try healing [1].');
});

test('rejects unauthorized requests without accessing upstream services', async () => {
  const handler = require('./api/ask.js');
  const origApi = process.env.OPENAI_API_KEY;
  const origToken = process.env.COMPANION_CLIENT_TOKEN;
  process.env.OPENAI_API_KEY = 'test_only_key';
  process.env.COMPANION_CLIENT_TOKEN = 'x'.repeat(48);
  let code;
  let body;
  const res = { setHeader() {}, status(v) { code = v; return this; },
    json(value) { body = value; return this; } };
  try {
    await handler({ method: 'POST', headers: { authorization: 'Bearer incorrect' },
      body: { question: 'how to heal?' } }, res);
    assert.equal(code, 401);
    assert.equal(body.error, 'Pairing token not accepted');
  } finally {
    if (origApi === undefined) delete process.env.OPENAI_API_KEY;
    else process.env.OPENAI_API_KEY = origApi;
    if (origToken === undefined) delete process.env.COMPANION_CLIENT_TOKEN;
    else process.env.COMPANION_CLIENT_TOKEN = origToken;
  }
});
