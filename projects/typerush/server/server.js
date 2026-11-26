const { createHash } = require("node:crypto");
const cors = require("cors");
const express = require("express");
const mongoose = require("mongoose");

const scoreSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 40 },
  wpm: { type: Number, required: true, min: 1, max: 400 },
  accuracy: { type: Number, required: true, min: 0, max: 100 },
  timestamp: { type: Date, default: Date.now },
  ownerHash: { type: String, select: false },
});
scoreSchema.index({ wpm: -1, accuracy: -1, timestamp: 1, _id: 1 });
const Score = mongoose.model("Score", scoreSchema);
const publicFields = "name wpm accuracy timestamp";
const app = express();

const origins = (process.env.CLIENT_ORIGINS || "http://127.0.0.1:8000,http://localhost:8000")
  .split(",").map(origin => origin.trim());
app.use(cors({ origin: origins }));
app.use(express.json({ limit: "2kb" }));
app.use("/scores", (req, res, next) => {
  res.set("Cache-Control", "no-store");
  next();
});

function ownerFilter(req, res) {
  const token = req.get("authorization")?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
  if (!token) {
    res.status(401).json({ message: "A score ownership token is required." });
    return null;
  }
  return { ownerHash: createHash("sha256").update(token).digest("hex") };
}

function scoreName(req) {
  const name = typeof req.body?.name === "string" ? req.body.name.trim() : "";
  return name.length <= 40 ? name : "";
}

app.get("/scores", async (req, res) => {
  const scores = await Score.find().select(publicFields)
    .sort({ wpm: -1, accuracy: -1, timestamp: 1, _id: 1 }).limit(10).lean();
  res.json(scores);
});

app.get("/scores/mine", async (req, res) => {
  const filter = ownerFilter(req, res);
  if (!filter) return;
  const scores = await Score.find(filter).select(publicFields)
    .sort({ timestamp: -1, _id: -1 }).limit(25).lean();
  res.json(scores);
});

app.post("/scores", async (req, res) => {
  const owner = ownerFilter(req, res);
  if (!owner) return;
  const { id, wpm, accuracy } = req.body || {};
  const name = scoreName(req);
  if (!mongoose.isObjectIdOrHexString(id) || !name ||
      !Number.isInteger(wpm) || wpm < 1 || wpm > 400 ||
      !Number.isInteger(accuracy) || accuracy < 0 || accuracy > 100) {
    return res.status(400).json({ message: "Enter a valid name and finish a typing test before saving." });
  }
  // The browser reuses the run ID if a submission needs to be retried.
  const score = await Score.findOneAndUpdate(
    { _id: id, ...owner },
    { $setOnInsert: { name, wpm, accuracy, ...owner } },
    { upsert: true, new: true, runValidators: true }
  ).select(publicFields).lean();
  res.status(201).json(score);
});

app.param("id", (req, res, next, id) => {
  if (!mongoose.isObjectIdOrHexString(id)) {
    return res.status(404).json({ message: "Score not found." });
  }
  next();
});

app.patch("/scores/:id", async (req, res) => {
  const owner = ownerFilter(req, res);
  if (!owner) return;
  const name = scoreName(req);
  if (!name) return res.status(400).json({ message: "Enter a display name of 1–40 characters." });
  const score = await Score.findOneAndUpdate(
    { _id: req.params.id, ...owner }, { name }, { new: true, runValidators: true }
  ).select(publicFields).lean();
  if (!score) return res.status(404).json({ message: "Score not found." });
  res.json(score);
});

app.delete("/scores/:id", async (req, res) => {
  const owner = ownerFilter(req, res);
  if (!owner) return;
  const { deletedCount } = await Score.deleteOne({ _id: req.params.id, ...owner });
  if (!deletedCount) return res.status(404).json({ message: "Score not found." });
  res.sendStatus(204);
});

app.use((error, req, res, next) => {
  if (res.headersSent) return next(error);
  if (error.code === 11000) return res.status(409).json({ message: "That score ID is already in use." });
  if (error.status === 400 || error.status === 413) {
    return res.status(error.status).json({ message: "Invalid score request." });
  }
  console.error("TypeRush request failed", error.name);
  res.status(500).json({ message: "The leaderboard is unavailable. Try again shortly." });
});

if (require.main === module) {
  if (!process.env.MONGODB_URI) throw new Error("MONGODB_URI must be set.");
  mongoose.connect(process.env.MONGODB_URI)
    .then(() => app.listen(process.env.PORT || 5050, "0.0.0.0"))
    .catch(error => {
      console.error("TypeRush could not connect to MongoDB", error.name);
      process.exitCode = 1;
    });
}

module.exports = app;
