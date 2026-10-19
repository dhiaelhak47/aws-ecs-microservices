'use strict';

const express = require('express');
const { v4: uuidv4 } = require('uuid');

const router = express.Router();

// In-memory notification store
const notifications = new Map();

// POST /notifications — receive a notification event from another service
router.post('/notifications', (req, res) => {
  try {
    const { event, orderId, userId, totalAmount, items } = req.body;
    if (!event) {
      return res.status(400).json({ error: 'event field is required' });
    }
    const notification = {
      id: uuidv4(),
      event,
      orderId: orderId || null,
      userId: userId || null,
      totalAmount: totalAmount || null,
      items: items || [],
      status: 'delivered',
      createdAt: new Date().toISOString(),
    };
    notifications.set(notification.id, notification);
    console.log(`[Notification] ${event} | orderId=${orderId} | userId=${userId} | total=${totalAmount}`);
    res.status(201).json({ message: 'Notification received', notificationId: notification.id, notification });
  } catch (err) {
    res.status(500).json({ error: 'Failed to process notification' });
  }
});

// GET /notifications — list all notifications
router.get('/notifications', (req, res) => {
  const all = Array.from(notifications.values()).sort(
    (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
  );
  res.json({ notifications: all, count: all.length });
});

// GET /notifications/:id — get a single notification by id
router.get('/notifications/:id', (req, res) => {
  const notification = notifications.get(req.params.id);
  if (!notification) {
    return res.status(404).json({ error: 'Notification not found' });
  }
  res.json({ notification });
});

module.exports = router;
