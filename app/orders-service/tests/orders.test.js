'use strict';

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-for-orders-tests';
process.env.ORDERS_SERVICE_PORT = '3098';

const request = require('supertest');
const jwt = require('jsonwebtoken');
const { app, server } = require('../src/app');

const JWT_SECRET = 'test-secret-for-orders-tests';

function makeToken(payload = {}) {
  return jwt.sign(
    { userId: 'user-123', email: 'test@example.com', name: 'Test User', ...payload },
    JWT_SECRET,
    { expiresIn: '1h' }
  );
}

afterAll(() => {
  server.close();
});

describe('GET /health', () => {
  it('returns 200 with healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body.service).toBe('orders-service');
  });
});

describe('Auth middleware', () => {
  it('returns 401 when no Authorization header is provided', async () => {
    const res = await request(app).get('/api/orders');
    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/no token/i);
  });

  it('returns 401 for an invalid token', async () => {
    const res = await request(app)
      .get('/api/orders')
      .set('Authorization', 'Bearer invalid.token.here');
    expect(res.status).toBe(401);
  });
});

describe('Orders CRUD', () => {
  let token;
  let createdOrderId;

  const sampleItems = [
    { productId: 'prod-001', quantity: 2, price: 29.99 },
    { productId: 'prod-002', quantity: 1, price: 49.99 },
  ];

  beforeAll(() => {
    token = makeToken();
  });

  it('GET /api/orders returns empty list initially', async () => {
    const res = await request(app)
      .get('/api/orders')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.orders).toBeInstanceOf(Array);
  });

  it('POST /api/orders creates a new order', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({ items: sampleItems });
    expect(res.status).toBe(201);
    expect(res.body.order.id).toBeDefined();
    expect(res.body.order.status).toBe('pending');
    expect(res.body.order.totalAmount).toBeCloseTo(109.97, 1);
    createdOrderId = res.body.order.id;
  });

  it('POST /api/orders returns 400 for missing items', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('POST /api/orders returns 400 for empty items array', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({ items: [] });
    expect(res.status).toBe(400);
  });

  it('GET /api/orders/:id returns the created order', async () => {
    const res = await request(app)
      .get(`/api/orders/${createdOrderId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.order.id).toBe(createdOrderId);
  });

  it('GET /api/orders/:id returns 404 for unknown id', async () => {
    const res = await request(app)
      .get('/api/orders/nonexistent-id')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(404);
  });

  it('PUT /api/orders/:id updates the order status', async () => {
    const res = await request(app)
      .put(`/api/orders/${createdOrderId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'confirmed' });
    expect(res.status).toBe(200);
    expect(res.body.order.status).toBe('confirmed');
  });

  it('PUT /api/orders/:id returns 400 for invalid status', async () => {
    const res = await request(app)
      .put(`/api/orders/${createdOrderId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'flying' });
    expect(res.status).toBe(400);
  });

  it('GET /api/orders returns only the user\'s orders', async () => {
    const otherToken = makeToken({ userId: 'other-user-456' });
    const res = await request(app)
      .get('/api/orders')
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(200);
    expect(res.body.orders).toHaveLength(0);
  });

  it('GET /api/orders/:id returns 403 for another user\'s order', async () => {
    const otherToken = makeToken({ userId: 'other-user-456' });
    const res = await request(app)
      .get(`/api/orders/${createdOrderId}`)
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(403);
  });

  it('DELETE /api/orders/:id deletes the order', async () => {
    const res = await request(app)
      .delete(`/api/orders/${createdOrderId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/deleted/i);
  });

  it('GET /api/orders/:id returns 404 after deletion', async () => {
    const res = await request(app)
      .get(`/api/orders/${createdOrderId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(404);
  });
});
