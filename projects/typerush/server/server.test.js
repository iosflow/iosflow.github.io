const assert = require("node:assert/strict");
const { once } = require("node:events");
const { randomBytes } = require("node:crypto");
const { test } = require("node:test");
const mongoose = require("mongoose");
const app = require("./server");

test("shared scores persist, sort, and only their creator can change them", async t => {
  await mongoose.connect(process.env.MONGODB_URI, {
    dbName: `typerush_test_${randomBytes(8).toString("hex")}`,
  });
  t.after(async () => {
    try {
      await mongoose.connection.dropDatabase();
    } finally {
      await mongoose.disconnect();
    }
  });

  const server = app.listen(0, "127.0.0.1");
  t.after(() => new Promise(resolve => server.close(resolve)));
  await once(server, "listening");
  const base = `http://127.0.0.1:${server.address().port}/scores`;
  const owner = randomBytes(32).toString("hex");
  const other = randomBytes(32).toString("hex");
  const id = randomBytes(12).toString("hex");

  function request(method, path = "", token, body) {
    const headers = {};
    if (token) headers.Authorization = `Bearer ${token}`;
    if (body) headers["Content-Type"] = "application/json";
    return fetch(base + path, { method, headers, body: JSON.stringify(body) });
  }

  const run = { id, name: "Scott", wpm: 81, accuracy: 96 };
  assert.equal((await request("POST", "", owner, { ...run, wpm: -1 })).status, 400);
  assert.equal((await request("POST", "", owner, run)).status, 201);
  assert.equal((await request("POST", "", owner, run)).status, 201);
  assert.equal((await request("POST", "", other, {
    ...run, id: randomBytes(12).toString("hex"), name: "Alex", wpm: 90,
  })).status, 201);

  const leaders = await (await request("GET")).json();
  assert.deepEqual(leaders.map(score => score.name), ["Alex", "Scott"]);
  assert.equal(leaders[1].ownerHash, undefined);
  const mine = await (await request("GET", "/mine", owner)).json();
  assert.deepEqual(mine.map(score => score._id), [id]);

  assert.equal((await request("PATCH", `/${id}`, other, { name: "Other" })).status, 404);
  assert.equal((await request("DELETE", `/${id}`, other)).status, 404);
  const renamed = await request("PATCH", `/${id}`, owner, { name: "Renamed" });
  assert.equal(renamed.status, 200);
  assert.equal((await renamed.json()).name, "Renamed");
  assert.equal((await request("DELETE", `/${id}`, owner)).status, 204);
  assert.deepEqual(await (await request("GET", "/mine", owner)).json(), []);
});
