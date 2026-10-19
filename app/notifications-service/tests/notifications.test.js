'use strict';

process.env.NOTIFICATIONS_SERVICE_PORT = '3097';

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
    expect(res.body.service).toBe('notifications-service');
  });
});

describe('POST /notifications', () => {
  it('creates a notification for ORDER_CREATED event', async () => {
    const res = await request(app)
      .post('/notifications')
      .send({
        event: 'ORDER_CREATED',
        orderId: 'order-abc-123',
        userId: 'user-xyz-456',
        totalAmount: 109.97,
        items: [{ productId: 'prod-001', quantity: 2, price: 29.99 }],
      });
    expect(res.status).toBe(201);
    expect(res.body.notificationId).toBeDefined();
    expect(res.body.notification.event).toBe('ORDER_CREATED');
    expect(res.body.notification.orderId).toBe('order-abc-123');
    expect(res.body.notification.status).toBe('delivered');
  });

  it('returns 400 when event field is missing', async () => {
    const res = await request(app)
      .post('/notifications')
      .send({ orderId: 'some-order' });
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  it('accepts notifications with minimal body', async () => {
    const res = await request(app)
      .post('/notifications')
      .send({ event: 'SYSTEM_ALERT' });
    expect(res.status).toBe(201);
    expect(res.body.notification.event).toBe('SYSTEM_ALERT');
  });
});

describe('GET /notifications', () => {
  it('returns a list of all notifications', async () => {
    const res = await request(app).get('/notifications');
    expect(res.status).toBe(200);
    expect(res.body.notifications).toBeInstanceOf(Array);
    expect(res.body.count).toBeGreaterThanOrEqual(0);
  });

  it('includes previously created notifications', async () => {
    await request(app)
      .post('/notifications')
      .send({ event: 'TEST_EVENT', orderId: 'order-list-test' });

    const res = await request(app).get('/notifications');
    expect(res.status).toBe(200);
    const found = res.body.notifications.find(n => n.orderId === 'order-list-test');
    expect(found).toBeDefined();
  });
});

describe('GET /notifications/:id', () => {
  let createdId;

  beforeAll(async () => {
    const res = await request(app)
      .post('/notifications')
      .send({ event: 'ORDER_SHIPPED', orderId: 'order-get-by-id' });
    createdId = res.body.notificationId;
  });

  it('returns the notification by id', async () => {
    const res = await request(app).get(`/notifications/${createdId}`);
    expect(res.status).toBe(200);
    expect(res.body.notification.id).toBe(createdId);
    expect(res.body.notification.event).toBe('ORDER_SHIPPED');
  });

  it('returns 404 for non-existent id', async () => {
    const res = await request(app).get('/notifications/does-not-exist');
    expect(res.status).toBe(404);
    expect(res.body.error).toMatch(/not found/i);
  });
});
