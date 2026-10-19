'use strict';

process.env.JWT_SECRET = 'test-secret-for-auth-tests';
process.env.AUTH_SERVICE_PORT = '3099';

const request = require('supertest');
const { app, server } = require('../src/app');

afterAll(() => {
  server.close();
});

describe('GET /health', () => {
  it('returns 200 with healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body.service).toBe('auth-service');
  });
});

describe('POST /auth/register', () => {
  it('registers a new user successfully', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ email: 'test@example.com', password: 'password123', name: 'Test User' });
    expect(res.status).toBe(201);
    expect(res.body.user.email).toBe('test@example.com');
    expect(res.body.user.name).toBe('Test User');
    expect(res.body.user.password).toBeUndefined();
  });

  it('returns 409 for duplicate email', async () => {
    await request(app)
      .post('/auth/register')
      .send({ email: 'duplicate@example.com', password: 'password123', name: 'User One' });
    const res = await request(app)
      .post('/auth/register')
      .send({ email: 'duplicate@example.com', password: 'password456', name: 'User Two' });
    expect(res.status).toBe(409);
    expect(res.body.error).toMatch(/already exists/i);
  });

  it('returns 400 when fields are missing', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ email: 'missing@example.com' });
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });
});

describe('POST /auth/login', () => {
  const email = 'login-test@example.com';
  const password = 'securepassword';

  beforeAll(async () => {
    await request(app)
      .post('/auth/register')
      .send({ email, password, name: 'Login Test User' });
  });

  it('logs in successfully and returns a JWT', async () => {
    const res = await request(app)
      .post('/auth/login')
      .send({ email, password });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
    expect(typeof res.body.token).toBe('string');
    expect(res.body.user.email).toBe(email);
  });

  it('returns 401 for wrong password', async () => {
    const res = await request(app)
      .post('/auth/login')
      .send({ email, password: 'wrongpassword' });
    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/invalid credentials/i);
  });

  it('returns 401 for non-existent user', async () => {
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'ghost@example.com', password: 'password' });
    expect(res.status).toBe(401);
  });

  it('returns 400 when fields are missing', async () => {
    const res = await request(app)
      .post('/auth/login')
      .send({ email });
    expect(res.status).toBe(400);
  });
});

describe('GET /auth/verify', () => {
  let validToken;

  beforeAll(async () => {
    const registerRes = await request(app)
      .post('/auth/register')
      .send({ email: 'verify-test@example.com', password: 'password123', name: 'Verify User' });

    const loginRes = await request(app)
      .post('/auth/login')
      .send({ email: 'verify-test@example.com', password: 'password123' });
    validToken = loginRes.body.token;
  });

  it('verifies a valid token', async () => {
    const res = await request(app)
      .get('/auth/verify')
      .set('Authorization', `Bearer ${validToken}`);
    expect(res.status).toBe(200);
    expect(res.body.valid).toBe(true);
    expect(res.body.user.email).toBe('verify-test@example.com');
  });

  it('returns 401 for an invalid token', async () => {
    const res = await request(app)
      .get('/auth/verify')
      .set('Authorization', 'Bearer invalid.token.here');
    expect(res.status).toBe(401);
    expect(res.body.valid).toBe(false);
  });

  it('returns 401 when no token is provided', async () => {
    const res = await request(app).get('/auth/verify');
    expect(res.status).toBe(401);
  });

  it('returns 401 when Authorization header has wrong format', async () => {
    const res = await request(app)
      .get('/auth/verify')
      .set('Authorization', `Token ${validToken}`);
    expect(res.status).toBe(401);
  });
});
