import React, { useEffect, useState, useSyncExternalStore } from "https://esm.sh/react@19.1.0";
import { createRoot } from "https://esm.sh/react-dom@19.1.0/client?deps=react@19.1.0";
import axios from "https://esm.sh/axios@1.10.0";

const h = React.createElement;

function randomHex(bytes) {
  return Array.from(crypto.getRandomValues(new Uint8Array(bytes)),
    byte => byte.toString(16).padStart(2, "0")).join("");
}

function getOwnerToken() {
  const key = "typerush:owner";
  const stored = localStorage.getItem(key);
  if (/^[a-f0-9]{64}$/.test(stored)) return stored;
  const token = randomHex(32);
  localStorage.setItem(key, token);
  return token;
}

function ScoreList({ scores, children, ordered = false }) {
  return h(ordered ? "ol" : "ul", { className: "score-list" }, scores.map(score =>
    h("li", { key: score._id },
      h("span", null, `${score.name} · ${score.wpm} WPM · ${score.accuracy}% accuracy`),
      children?.(score)
    )
  ));
}

function Leaderboard({ client, token, runs }) {
  const run = useSyncExternalStore(runs.subscribe, runs.getSnapshot);
  const [leaders, setLeaders] = useState(null);
  const [mine, setMine] = useState(null);
  const [savedRun, setSavedRun] = useState(null);
  const [pendingRun, setPendingRun] = useState(null);
  const [name, setName] = useState("");
  const [editing, setEditing] = useState(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const owner = token ? { headers: { Authorization: `Bearer ${token}` } } : null;

  function showError(error) {
    setMessage(error.response?.data?.message || "Could not reach the leaderboard. Try refreshing the scores.");
  }

  async function refresh() {
    const [publicScores, ownedScores] = await Promise.allSettled([
      client.get("/scores"),
      owner && client.get("/scores/mine", owner),
    ]);
    if (publicScores.status === "fulfilled") setLeaders(publicScores.value.data);
    if (ownedScores.status === "fulfilled" && ownedScores.value) setMine(ownedScores.value.data);
    if (publicScores.status === "rejected") showError(publicScores.reason);
    else if (ownedScores.status === "rejected") showError(ownedScores.reason);
  }

  async function perform(action) {
    setBusy(true);
    setMessage("");
    try {
      await action();
    } catch (error) {
      showError(error);
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    void perform(refresh);
  }, []);

  function save(event) {
    event.preventDefault();
    const id = pendingRun?.run === run ? pendingRun.id : randomHex(12);
    setPendingRun({ run, id });
    void perform(async () => {
      await client.post("/scores", { ...run, name, id }, owner);
      setSavedRun(run);
      setName("");
      setMessage("Score saved.");
      await refresh();
    });
  }

  function rename(event) {
    event.preventDefault();
    void perform(async () => {
      await client.patch(`/scores/${editing.id}`, { name: editing.name }, owner);
      setEditing(null);
      setMessage("Display name updated.");
      await refresh();
    });
  }

  function remove(score) {
    if (!window.confirm(`Delete the ${score.wpm} WPM score for ${score.name}?`)) return;
    void perform(async () => {
      try {
        await client.delete(`/scores/${score._id}`, owner);
      } catch (error) {
        if (error.response?.status !== 404) throw error;
      }
      if (editing?.id === score._id) setEditing(null);
      setMessage("Score deleted.");
      await refresh();
    });
  }

  const canSave = run && run.wpm >= 1 && run.wpm <= 400 && run !== savedRun;
  return h(React.Fragment, null,
    h("button", { type: "button", disabled: busy, onClick: () => void perform(refresh) }, "Refresh scores"),
    h("p", { role: "status" }, message || (busy ? "Loading scores…" : "")),
    leaders?.length
      ? h(ScoreList, { scores: leaders, ordered: true })
      : h("p", null, leaders ? "No scores yet." : "No leaderboard data loaded."),
    h("h3", null, "Save your score"),
    !token ? h("p", null, "Enable browser storage to save and manage your scores.")
      : canSave ? h("form", { className: "score-form", onSubmit: save },
        h("label", { htmlFor: "score-name" }, "Display name"),
        h("input", {
          id: "score-name", value: name, maxLength: 40, required: true, disabled: busy,
          onChange: event => setName(event.target.value),
        }),
        h("button", { disabled: busy || !name.trim() }, "Save score")
      ) : h("p", null, run && run === savedRun ? "This run has been saved."
        : run ? "Finish a run between 1 and 400 WPM to save a score."
          : "Finish a typing test to submit a score."),
    token && h(React.Fragment, null,
      h("h3", null, "Your recent scores"),
      h("p", null, "You can rename or delete scores saved from this browser."),
      mine?.length ? h(ScoreList, { scores: mine }, score =>
        editing?.id === score._id ? h("form", { className: "score-form", onSubmit: rename },
          h("label", { htmlFor: "edit-score-name" }, "New display name"),
          h("input", {
            id: "edit-score-name", value: editing.name, maxLength: 40, required: true,
            disabled: busy, onChange: event => setEditing({ id: score._id, name: event.target.value }),
          }),
          h("button", { disabled: busy || !editing.name.trim() }, "Update name"),
          h("button", { type: "button", disabled: busy, onClick: () => setEditing(null) }, "Cancel")
        ) : h("div", { className: "score-actions" },
          h("button", {
            type: "button", disabled: busy, onClick: () => setEditing({ id: score._id, name: score.name }),
          }, "Rename"),
          h("button", { type: "button", disabled: busy, onClick: () => remove(score) }, "Delete")
        )
      ) : h("p", null, mine ? "You have no saved scores." : "No personal scores loaded.")
    )
  );
}

export function mountLeaderboard(root, api, runs) {
  let token = null;
  try {
    token = getOwnerToken();
  } catch {
    // The public leaderboard is still available if storage is blocked.
  }
  const client = axios.create({ baseURL: api, timeout: 15000 });
  createRoot(root).render(h(Leaderboard, { client, token, runs }));
}
