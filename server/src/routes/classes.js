import express from 'express';
import ClassModel from '../models/Class.js';

const router = express.Router();

router.get('/', async (req, res) => {
  const { teacherId, studentId } = req.query;
  let q = {};
  if (teacherId) {
    q = { teacherId };
  } else if (studentId) {
    q = { studentIds: { $in: [studentId] } };
  }
  const list = await ClassModel.find(q).sort({ createdAt: -1 }).limit(200);
  res.json(list.map(c => ({ id: c._id.toString(), name: c.name, teacherId: c.teacherId, studentIds: c.studentIds, createdAt: c.createdAt })));
});

router.post('/', async (req, res) => {
  const { name, teacherId, studentIds, createdAt } = req.body;
  const c = await ClassModel.create({ name, teacherId, studentIds: studentIds || [], createdAt: createdAt ? new Date(createdAt) : new Date() });
  res.status(201).json({ id: c._id.toString() });
});

router.put('/:id', async (req, res) => {
  const { name, teacherId, studentIds } = req.body;
  const c = await ClassModel.findByIdAndUpdate(req.params.id, { name, teacherId, studentIds }, { new: true });
  if (!c) return res.status(404).json({ error: 'Not found' });
  res.json({ id: c._id.toString(), name: c.name, teacherId: c.teacherId, studentIds: c.studentIds });
});

router.delete('/:id', async (req, res) => {
  await ClassModel.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
});

export default router;

