import mongoose from 'mongoose';

const SessionSchema = new mongoose.Schema({
  classId: { type: String, required: true },
  name: { type: String, required: true }, // nom de la séance (ex: Math, Python, etc.)
  startAt: { type: String, required: true }, // ISO strings for simplicity
  endAt: { type: String, required: true },
  code: { type: String }, // optional QR code or session code
}, { timestamps: true });

SessionSchema.index({ classId: 1 });
SessionSchema.index({ startAt: 1 });

export default mongoose.model('Session', SessionSchema);

