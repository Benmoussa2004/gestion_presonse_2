import express from 'express';
import Session from '../models/Session.js';

const router = express.Router();

router.get('/', async (req, res) => {
  const { classId } = req.query;
  const q = classId ? { classId } : {};
  const list = await Session.find(q).sort({ startAt: 1 }).limit(200);
  res.json(list.map(s => ({ id: s._id.toString(), classId: s.classId, name: s.name, startAt: s.startAt, endAt: s.endAt, code: s.code })));
});

router.post('/', async (req, res) => {
  const { classId, name, startAt, endAt, code } = req.body;
  const s = await Session.create({ classId, name, startAt, endAt, code });
  res.status(201).json({ id: s._id.toString() });
});

router.put('/:id', async (req, res) => {
  const { classId, name, startAt, endAt, code } = req.body;
  const s = await Session.findByIdAndUpdate(req.params.id, { classId, name, startAt, endAt, code }, { new: true });
  if (!s) return res.status(404).json({ error: 'Not found' });
  res.json({ id: s._id.toString(), classId: s.classId, name: s.name, startAt: s.startAt, endAt: s.endAt, code: s.code });
});

router.delete('/:id', async (req, res) => {
  await Session.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
});

export default router;

