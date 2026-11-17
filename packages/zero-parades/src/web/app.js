/**
Zero Parades Voiceover Player — Frontend Application
*/

const state = {
  activeCardId: null,
  activeItem: null,
  currentItems: [],
  limit: 50,
  page: 0,
  query: "",
  speaker: "",
  totalItems: 0,
  totalPages: 1,
  voOnly: true,
};

// DOM Elements
const searchInput = document.querySelector("#search-input");
const clearSearchButton = document.querySelector("#clear-search");
const speakerSelect = document.querySelector("#speaker-select");
const voOnlyCheck = document.querySelector("#vo-only-check");
const dialogueTbody = document.querySelector("#dialogue-tbody");
const audioElement = document.querySelector("#audio-element");
const audioStatus = document.querySelector("#audio-status");
const playingSpeaker = document.querySelector("#playing-speaker");
const playingText = document.querySelector("#playing-text");
const playingMeta = document.querySelector("#playing-meta");
const playingCheck = document.querySelector("#playing-check");
const headerStats = document.querySelector("#header-stats");
const paginationInfo = document.querySelector("#pagination-info");
const pageIndicator = document.querySelector("#page-indicator");
const buttonPrevious = document.querySelector("#btn-prev");
const buttonNext = document.querySelector("#btn-next");

// Initial Load
document.addEventListener("DOMContentLoaded", () => {
  loadStatus();
  loadSpeakers();
  loadDialogueLines();
  setupEventListeners();
});

function escapeHtml(string_) {
  return string_
    ? String(string_)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;")
    : "";
}

async function loadDialogueLines() {
  dialogueTbody.innerHTML = `<tr><td colspan="5" class="empty-state">Loading dialogue lines...</td></tr>`;

  const parameters = new URLSearchParams({
    limit: state.limit,
    page: state.page,
    q: state.query,
    speaker: state.speaker,
    vo_only: state.voOnly ? "1" : "0",
  });

  try {
    const response = await fetch(`/api/lines?${parameters.toString()}`);
    const data = await response.json();

    state.currentItems = data.items;
    state.totalItems = data.total;
    state.totalPages = data.pages;

    renderDialogueTable(data.items);
    renderPagination(data);
  } catch (error) {
    console.error("Failed loading lines:", error);
    dialogueTbody.innerHTML = `<tr><td colspan="5" class="empty-state" style="color: var(--accent-red)">Error loading dialogue lines. Check server logs.</td></tr>`;
  }
}

async function loadSpeakers() {
  try {
    const response = await fetch("/api/speakers");
    state.speakersData = await response.json();
    renderSpeakerOptions();
  } catch (error) {
    console.error("Failed loading speakers:", error);
  }
}

async function loadStatus() {
  try {
    const response = await fetch("/api/status");
    const data = await response.json();
    const voicedString =
      data.voiced_lines == null
        ? ""
        : ` (${data.voiced_lines.toLocaleString()} voiced)`;
    headerStats.textContent = `${data.total_lines.toLocaleString()} lines${voicedString} • ${data.soundbanks_available} voiceover banks ready`;
  } catch (error) {
    console.error("Failed loading status:", error);
  }
}

function navigateDelta(delta) {
  if (!state.currentItems || state.currentItems.length === 0) return;
  const currentIndex = state.currentItems.findIndex(
    (item) => item.card_id === state.activeCardId,
  );
  const nextIndex = currentIndex === -1 ? 0 : currentIndex + delta;
  if (nextIndex < 0 || nextIndex >= state.currentItems.length) return;
  playLine(state.currentItems[nextIndex]);
  const row = document.querySelector(
    `.dialogue-row[data-card-id="${CSS.escape(state.currentItems[nextIndex].card_id)}"]`,
  );
  if (row) row.scrollIntoView({ behavior: "smooth", block: "nearest" });
}

async function playLine(item) {
  state.activeCardId = item.card_id;
  state.activeItem = item;

  // Update active row class
  for (const row of document.querySelectorAll(".dialogue-row")) {
    row.classList.toggle("active", row.dataset.cardId === item.card_id);
  }

  const hasVo = Boolean(item.has_vo ?? item.has_bank);
  const isProtagonist = (item.speaker || "").toLowerCase() === "herschel";

  // Update now-playing bar
  playingSpeaker.textContent = item.speaker || "Unknown";
  playingText.textContent = item.text || "";
  const unvoicedLabel = isProtagonist
    ? " (SILENT PROTAGONIST)"
    : " (TEXT ONLY)";
  playingMeta.textContent = `[${item.chunk_name || ""}] flow: ${item.flow_id} • card: ${item.card_id}${hasVo ? "" : unvoicedLabel}`;

  if (item.threshold) {
    playingCheck.textContent = `CHECK DC ${item.threshold}`;
    playingCheck.className = "check-tag check-passive";
    playingCheck.style.display = "inline-block";
  } else {
    playingCheck.style.display = "none";
  }

  if (!hasVo) {
    const statusMessage = isProtagonist
      ? "SILENT PROTAGONIST (NO VO)"
      : "TEXT-ONLY (NO VO RECORDED)";
    setStatus(statusMessage, "");
    audioElement.removeAttribute("src");
    audioElement.load();
    return;
  }

  // Stream audio from server
  setStatus("STREAMING VO...", "loading");
  const audioUrl = `/api/audio?flow=${encodeURIComponent(item.flow_id)}&card=${encodeURIComponent(item.card_id)}`;
  audioElement.src = audioUrl;
  try {
    await audioElement.play();
  } catch (error) {
    console.warn("Autoplay blocked or audio failed:", error);
    setStatus("CLICK TO PLAY", "");
  }
}

function renderDialogueTable(items) {
  if (!items || items.length === 0) {
    dialogueTbody.innerHTML = `<tr><td colspan="5" class="empty-state">No matching dialogue lines found.</td></tr>`;
    return;
  }

  dialogueTbody.replaceChildren();
  const frag = document.createDocumentFragment();

  for (const item of items) {
    const tr = document.createElement("tr");
    tr.className = "dialogue-row";
    tr.dataset.cardId = item.card_id;
    tr.dataset.flowId = item.flow_id;
    if (item.card_id === state.activeCardId) {
      tr.classList.add("active");
    }

    const speakerLower = (item.speaker || "").toLowerCase();
    let speakerClass = "td-speaker-name";
    if (speakerLower === "herschel") speakerClass += " speaker-herschel";
    else if (speakerLower === "narrator") speakerClass += " speaker-narrator";
    else speakerClass += " speaker-faculty";

    const hasVo = Boolean(item.has_vo ?? item.has_bank);
    const isProtagonist = speakerLower === "herschel";
    let voBadge = `<span class="td-check-badge badge-vo" title="Recorded voiceover available">VO</span>`;
    if (!hasVo) {
      voBadge = isProtagonist
        ? `<span class="td-check-badge badge-text-only" title="Silent protagonist player choice">PLAYER CHOICE</span>`
        : `<span class="td-check-badge badge-text-only" title="Unvoiced in game">TEXT ONLY</span>`;
    }

    const buttonIcon = hasVo ? "▶" : isProtagonist ? "👤" : "💬";
    const buttonTitle = hasVo
      ? "Play voiceover"
      : isProtagonist
        ? "Silent protagonist dialogue choice (text only)"
        : "Unvoiced line (text only)";

    const checkBadge = item.threshold
      ? `<span class="td-check-badge check-passive">DC ${item.threshold}</span> `
      : "";
    const cardTypeBadge = `<span class="td-check-badge" style="background: var(--bg-tertiary); color: var(--text-dim)">${escapeHtml(item.card_type || "line")}</span>`;

    tr.innerHTML = `
      <td class="th-action">
        <button class="td-play-btn" title="${buttonTitle}">${buttonIcon}</button>
      </td>
      <td class="th-speaker">
        <span class="${speakerClass}">${escapeHtml(item.speaker || "Unknown")}</span>
      </td>
      <td class="th-text">
        <div class="td-text">${escapeHtml(item.text || "")}</div>
      </td>
      <td class="th-check">
        ${voBadge} ${checkBadge}${cardTypeBadge}
      </td>
      <td class="th-ids">
        <div>${escapeHtml(item.card_id || "")}</div>
        <div style="font-size: 0.68rem; color: var(--text-dim)">${escapeHtml(item.flow_id || "")}</div>
      </td>
    `;

    tr.addEventListener("click", () => {
      playLine(item);
    });

    frag.append(tr);
  }

  dialogueTbody.append(frag);
}

function renderPagination(data) {
  const start = data.page * data.limit + 1;
  const end = Math.min((data.page + 1) * data.limit, data.total);
  paginationInfo.textContent =
    data.total > 0
      ? `Showing ${start.toLocaleString()} - ${end.toLocaleString()} of ${data.total.toLocaleString()} lines`
      : "No lines";

  pageIndicator.textContent = `Page ${data.page + 1} of ${Math.max(1, data.pages)}`;
  buttonPrevious.disabled = data.page <= 0;
  buttonNext.disabled = data.page >= data.pages - 1;
}

function renderSpeakerOptions() {
  if (!state.speakersData) return;
  const currentValue = speakerSelect.value;
  speakerSelect.innerHTML = `<option value="">All Speakers (${state.speakersData.length})</option>`;
  for (const spk of state.speakersData) {
    const count = state.voOnly ? spk.voiced_count || 0 : spk.count;
    if (count === 0 && state.voOnly) continue;
    const opt = document.createElement("option");
    opt.value = spk.name;
    opt.textContent = `${spk.name} (${count.toLocaleString()})`;
    speakerSelect.append(opt);
  }
  speakerSelect.value = currentValue;
}

function setStatus(text, className) {
  audioStatus.textContent = text;
  audioStatus.className = `status-indicator ${className}`;
}

function setupEventListeners() {
  if (voOnlyCheck) {
    voOnlyCheck.addEventListener("change", (event_) => {
      state.voOnly = event_.target.checked;
      state.page = 0;
      renderSpeakerOptions();
      loadDialogueLines();
    });
  }
  // Search input with debounce
  let searchTimeout = null;
  searchInput.addEventListener("input", (event_) => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      state.query = event_.target.value.trim();
      state.page = 0;
      loadDialogueLines();
    }, 280);
  });

  clearSearchButton.addEventListener("click", () => {
    searchInput.value = "";
    state.query = "";
    state.page = 0;
    loadDialogueLines();
  });

  // Speaker select
  speakerSelect.addEventListener("change", (event_) => {
    state.speaker = event_.target.value;
    state.page = 0;
    loadDialogueLines();
  });

  // Pagination buttons
  buttonPrevious.addEventListener("click", () => {
    if (!(state.page > 0)) {
      return;
    }

    state.page--;
    loadDialogueLines();
  });

  buttonNext.addEventListener("click", () => {
    if (!(state.page < state.totalPages - 1)) {
      return;
    }

    state.page++;
    loadDialogueLines();
  });

  // Audio status updates
  audioElement.addEventListener("playing", () => {
    setStatus("PLAYING", "playing");
  });

  audioElement.addEventListener("pause", () => {
    if (audioElement.currentTime < audioElement.duration) {
      setStatus("PAUSED", "");
    }
  });

  audioElement.addEventListener("ended", () => {
    setStatus("DONE", "");
  });

  audioElement.addEventListener("waiting", () => {
    setStatus("STREAMING", "loading");
  });

  audioElement.addEventListener("error", () => {
    setStatus("VO UNAVAILABLE", "error");
  });

  // Keyboard navigation
  addEventListener("keydown", (event_) => {
    if (event_.target.tagName === "INPUT" || event_.target.tagName === "SELECT")
      return;

    switch (event_.code) {
      case "ArrowDown": {
        event_.preventDefault();
        navigateDelta(1);
        break;
      }
      case "ArrowUp": {
        event_.preventDefault();
        navigateDelta(-1);
        break;
      }
      case "Space": {
        event_.preventDefault();
        if (audioElement.paused) audioElement.play();
        else audioElement.pause();
        break;
      }
    }
  });
}
