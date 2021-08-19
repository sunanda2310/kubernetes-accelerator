const request = require('supertest');
const server = require('../src/app.js');

beforeAll(async () => {
 console.log('Jest starting!');
});

afterAll(() => {
 server.close();
});

describe('basic route tests', () => {
  test('get home route GET /', async () => {
    const response = await request(server).get('/');
    expect(response.status).toEqual(200);
    expect(response.text).toContain('Hello Routed World!');
  });
});

describe('marvel tests', () => {
  test('get all marvel  GET /marvel', async () => {
    const response = await request(server).get('/marvel');
    expect(response.status).toEqual(200);
    expect(response.text).toContain('Superhero landing!');
  });
});
