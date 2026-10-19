'use strict';

const express = require('express');
const axios = require('axios');
const { v4: uuidv4 } = require('uuid');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// In-memory order store (simulates DynamoDB in local dev)
const orders = new Map();

const NOTIFICATIONS_SERVICE_URL = process.env.NOTIFICATIONS_SERVICE_URL || 'http://notifications-service:3003';

function calculateTotal(items) {
  if (!Array.isArray(items)) return 0;
  return items.reduce((sum, item) => sum + (item.price || 0) * (item.quantity || 1), 0);
}

async function notifyOrderEvent(event, order) {
  try {
    await axios.post(`${NOTIFICATIONS_SERVICE_URL}/notifications`, {
      event,
      orderId: order.id,
      userId: order.userId,
      totalAmount: order.totalAmount,
      items: order.items,
    }, { timeout: 3000 });
  } catch (err) {
    // Fire-and-forget: log but do not fail the request
    console.warn(`Failed to send notification for order ${order.id}:`, err.message);
  }
}

// GET /api/orders — list orders for authenticated user
router.get('/api/orders', authMiddleware, (req, res) => {
  const userOrders = Array.from(orders.values()).filter(o => o.userId === req.user.userId);
  res.json({ orders: userOrders, count: userOrders.length });
});

// POST /api/orders — create a new order
router.post('/api/orders', authMiddleware, async (req, res) => {
  try {
    const { items } = req.body;
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items array is required and must not be empty' });
    }
    for (const item of items) {
      if (!item.productId || item.quantity == null || item.price == null) {
        return res.status(400).json({ error: 'Each item requires productId, quantity, and price' });
      }
    }
    const order = {
      id: uuidv4(),
      userId: req.user.userId,
      items,
      status: 'pending',
      totalAmount: calculateTotal(items),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    orders.set(order.id, order);
    notifyOrderEvent('ORDER_CREATED', order);
    res.status(201).json({ message: 'Order created', order });
  } catch (err) {
    res.status(500).json({ error: 'Failed to create order' });
  }
});

// GET /api/orders/:id — get a single order
router.get('/api/orders/:id', authMiddleware, (req, res) => {
  const order = orders.get(req.params.id);
  if (!order) {
    return res.status(404).json({ error: 'Order not found' });
  }
  if (order.userId !== req.user.userId) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  res.json({ order });
});

// PUT /api/orders/:id — update order status
router.put('/api/orders/:id', authMiddleware, (req, res) => {
  const order = orders.get(req.params.id);
  if (!order) {
    return res.status(404).json({ error: 'Order not found' });
  }
  if (order.userId !== req.user.userId) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  const { status } = req.body;
  const validStatuses = ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled'];
  if (!status || !validStatuses.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${validStatuses.join(', ')}` });
  }
  order.status = status;
  order.updatedAt = new Date().toISOString();
  orders.set(order.id, order);
  res.json({ message: 'Order updated', order });
});

// DELETE /api/orders/:id — delete an order
router.delete('/api/orders/:id', authMiddleware, (req, res) => {
  const order = orders.get(req.params.id);
  if (!order) {
    return res.status(404).json({ error: 'Order not found' });
  }
  if (order.userId !== req.user.userId) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  orders.delete(req.params.id);
  res.json({ message: 'Order deleted' });
});

module.exports = router;
