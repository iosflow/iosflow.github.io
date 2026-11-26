const root = document.querySelector("#leaderboard");
const status = root.querySelector("[role=status]");
const configuredApi = document.querySelector('meta[name="typerush-api"]').content.trim();
const localPreview = ["localhost", "127.0.0.1"].includes(location.hostname);
const api = configuredApi || (localPreview ? "http://127.0.0.1:5050" : "");

// Keep the latest result even if the leaderboard libraries are still loading.
let score = null;
const listeners = new Set();
document.addEventListener("typerush:run", event => {
  score = event.detail;
  listeners.forEach(listener => listener());
});

if (api) {
  import("./leaderboard.js")
    .then(({ mountLeaderboard }) => {
      mountLeaderboard(root, api, {
        getSnapshot: () => score,
        subscribe(listener) {
          listeners.add(listener);
          return () => listeners.delete(listener);
        },
      });
    })
    .catch(() => {
      status.textContent = "The leaderboard could not load. The typing test is still available.";
    });
} else {
  status.textContent = "The shared leaderboard is currently unavailable.";
}
