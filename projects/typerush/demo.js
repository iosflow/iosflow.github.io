const passages = [
  "the quick brown fox jumps over the lazy dog.",
  "typing tests help improve your speed and accuracy.",
  "JavaScript is a versatile and widely-used programming language.",
  "practice makes perfect, especially when learning to type faster.",
  "fullstack web development includes both frontend and backend skills.",
];

const passageDisplay = document.querySelector("#passage");
const typing = document.querySelector("#typing");
const time = document.querySelector("#time");
const speed = document.querySelector("#speed");
const accuracy = document.querySelector("#accuracy");
const result = document.querySelector("#result");
const reset = document.querySelector("#reset");

let passageIndex = Math.floor(Math.random() * passages.length);
let startedAt = null;
let timer;
let correctCharacters = 0;
let typedCharacters = 0;

function updateStats(now = performance.now()) {
  const elapsed = startedAt === null ? 0 : (now - startedAt) / 1000;
  const wpm = elapsed >= 1 ? Math.round((correctCharacters / 5) * (60 / elapsed)) : 0;
  const percentage = typedCharacters ? Math.round(correctCharacters / typedCharacters * 100) : 100;

  time.textContent = `${elapsed.toFixed(1)}s`;
  speed.textContent = `${wpm} WPM`;
  accuracy.textContent = `${percentage}%`;
}

function preparePassage() {
  clearInterval(timer);
  startedAt = null;
  correctCharacters = 0;
  typedCharacters = 0;
  passageDisplay.replaceChildren(...Array.from(passages[passageIndex], (character) => {
    const span = document.createElement("span");
    span.textContent = character;
    return span;
  }));
  typing.value = "";
  typing.disabled = false;
  typing.readOnly = false;
  result.textContent = "";
  updateStats();
}

typing.addEventListener("input", (event) => {
  if (event.isComposing) return;
  const input = typing.value;
  const now = performance.now();
  if (startedAt === null && input) {
    startedAt = now;
    timer = setInterval(updateStats, 200);
  }

  typedCharacters = input.length;
  correctCharacters = 0;
  Array.from(passageDisplay.children).forEach((character, index) => {
    const isCorrect = character.textContent === input[index];
    character.classList.toggle("correct", isCorrect);
    character.classList.toggle("incorrect", index < typedCharacters && !isCorrect);
    if (isCorrect) correctCharacters++;
  });
  updateStats(now);

  if (input === passages[passageIndex]) {
    clearInterval(timer);
    typing.readOnly = true;
    result.textContent = `Finished in ${time.textContent} at ${speed.textContent} with ${accuracy.textContent} accuracy.`;
  }
});

reset.addEventListener("click", () => {
  passageIndex = (passageIndex + 1) % passages.length;
  preparePassage();
  typing.focus();
});

preparePassage();
