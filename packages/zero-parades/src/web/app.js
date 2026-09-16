/**
 * Zero Parades Voiceover Player — Frontend Application
 */

const state = {
  page: 0,
  limit: 50,
  totalPages: 1,
  totalItems: 0,
  query: "",
  speaker: "",
  voOnly: true,
  currentItems: [],
  activeCardId: null,
  activeItem: null,
};

// DOM Elements
const searchInput = document.getElementById("search-input");
const clearSearchBtn = document.getElementById("clear-search");
const speakerSelect = document.getElementById("speaker-select");
const voOnlyCheck = document.getElementById("vo-only-check");
const dialogueTbody = document.getElementById("dialogue-tbody");
const audioElement = document.getElementById("audio-element");
const audioStatus = document.getElementById("audio-status");
const playingSpeaker = document.getElementById("playing-speaker");
const playingText = document.getElementById("playing-text");
const playingMeta = document.getElementById("playing-meta");
const playingCheck = document.getElementById("playing-check");
const headerStats = document.getElementById("header-stats");
const paginationInfo = document.getElementById("pagination-info");
const pageIndicator = document.getElementById("page-indicator");
const btnPrev = document.getElementById("btn-prev");
const btnNext = document.getElementById("btn-next");

// Initial Load
document.addEventListener("DOMContentLoaded", () => {
  loadStatus();
  loadSpeakers();
  loadDialogueLines();
  setupEventListeners();
});

function setupEventListeners() {
  if (voOnlyCheck) {
    voOnlyCheck.addEventListener("change", (e) => {
      state.voOnly = e.target.checked;
      state.page = 0;
      renderSpeakerOptions();
      loadDialogueLines();
    });
  }
  // Search input with debounce
  let searchTimeout = null;
  searchInput.addEventListener("input", (e) => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      state.query = e.target.value.trim();
      state.page = 0;
      loadDialogueLines();
    }, 280);
  });

  clearSearchBtn.addEventListener("click", () => {
    searchInput.value = "";
    state.query = "";
    state.page = 0;
    loadDialogueLines();
  });

  // Speaker select
  speakerSelect.addEventListener("change", (e) => {
    state.speaker = e.target.value;
    state.page = 0;
    loadDialogueLines();
  });

  // Pagination buttons
  btnPrev.addEventListener("click", () => {
    if (state.page > 0) {
      state.page--;
      loadDialogueLines();
    }
  });

  btnNext.addEventListener("click", () => {
    if (state.page < state.totalPages - 1) {
      state.page++;
      loadDialogueLines();
    }
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
  window.addEventListener("keydown", (e) => {
    if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT") return;

    if (e.code === "Space") {
      e.preventDefault();
      if (audioElement.paused) audioElement.play();
      else audioElement.pause();
    } else if (e.code === "ArrowDown") {
      e.preventDefault();
      navigateDelta(1);
    } else if (e.code === "ArrowUp") {
      e.preventDefault();
      navigateDelta(-1);
    }
  });
}

function setStatus(text, className) {
  audioStatus.textContent = text;
  audioStatus.className = `status-indicator ${className}`;
}

async function loadStatus() {
  try {
    const res = await fetch("/api/status");
    const data = await res.json();
    const voicedStr = data.voiced_lines != null ? ` (${data.voiced_lines.toLocaleString()} voiced)` : "";
    headerStats.textContent = `${data.total_lines.toLocaleString()} lines${voicedStr} • ${data.soundbanks_available} voiceover banks ready`;
  } catch (err) {
    console.error("Failed loading status:", err);
  }
}

async function loadSpeakers() {
  try {
    const res = await fetch("/api/speakers");
    state.speakersData = await res.json();
    renderSpeakerOptions();
  } catch (err) {
    console.error("Failed loading speakers:", err);
  }
}

function renderSpeakerOptions() {
  if (!state.speakersData) return;
  const currentVal = speakerSelect.value;
  speakerSelect.innerHTML = `<option value="">All Speakers (${state.speakersData.length})</option>`;
  for (const spk of state.speakersData) {
    const count = state.voOnly ? (spk.voiced_count || 0) : spk.count;
    if (state.voOnly && count === 0) continue;
    const opt = document.createElement("option");
    opt.value = spk.name;
    opt.textContent = `${spk.name} (${count.toLocaleString()})`;
    speakerSelect.appendChild(opt);
  }
  speakerSelect.value = currentVal;
}

async function loadDialogueLines() {
  dialogueTbody.innerHTML = `<tr><td colspan="5" class="empty-state">Loading dialogue lines...</td></tr>`;

  const params = new URLSearchParams({
    page: state.page,
    limit: state.limit,
    q: state.query,
    speaker: state.speaker,
    vo_only: state.voOnly ? "1" : "0",
  });

  try {
    const res = await fetch(`/api/lines?${params.toString()}`);
    const data = await res.json();

    state.currentItems = data.items;
    state.totalItems = data.total;
    state.totalPages = data.pages;

    renderDialogueTable(data.items);
    renderPagination(data);
  } catch (err) {
    console.error("Failed loading lines:", err);
    dialogueTbody.innerHTML = `<tr><td colspan="5" class="empty-state" style="color: var(--accent-red)">Error loading dialogue lines. Check server logs.</td></tr>`;
  }
}

function renderDialogueTable(items) {
  if (!items || items.length === 0) {
    dialogueTbody.innerHTML = `<tr><td colspan="5" class="empty-state">No matching dialogue lines found.</td></tr>`;
    return;
  }

  dialogueTbody.innerHTML = "";
  const frag = document.createDocumentFragment();

  items.forEach((item, idx) => {
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

    const btnIcon = hasVo ? "▶" : (isProtagonist ? "👤" : "💬");
    const btnTitle = hasVo ? "Play voiceover" : (isProtagonist ? "Silent protagonist dialogue choice (text only)" : "Unvoiced line (text only)");

    let checkBadge = "";
    if (item.threshold) {
      checkBadge = `<span class="td-check-badge check-passive">DC ${item.threshold}</span> `;
    }
    const cardTypeBadge = `<span class="td-check-badge" style="background: var(--bg-tertiary); color: var(--text-dim)">${escapeHtml(item.card_type || "line")}</span>`;

    tr.innerHTML = `
      <td class="th-action">
        <button class="td-play-btn" title="${btnTitle}">${btnIcon}</button>
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

    frag.appendChild(tr);
  });

  dialogueTbody.appendChild(frag);
}

function renderPagination(data) {
  const start = data.page * data.limit + 1;
  const end = Math.min((data.page + 1) * data.limit, data.total);
  paginationInfo.textContent = data.total > 0
    ? `Showing ${start.toLocaleString()} - ${end.toLocaleString()} of ${data.total.toLocaleString()} lines`
    : "No lines";

  pageIndicator.textContent = `Page ${data.page + 1} of ${Math.max(1, data.pages)}`;
  btnPrev.disabled = data.page <= 0;
  btnNext.disabled = data.page >= data.pages - 1;
}

function playLine(item) {
  state.activeCardId = item.card_id;
  state.activeItem = item;

  // Update active row class
  document.querySelectorAll(".dialogue-row").forEach(row => {
    row.classList.toggle("active", row.dataset.cardId === item.card_id);
  });

  const hasVo = Boolean(item.has_vo ?? item.has_bank);
  const isProtagonist = (item.speaker || "").toLowerCase() === "herschel";

  // Update now-playing bar
  playingSpeaker.textContent = item.speaker || "Unknown";
  playingText.textContent = item.text || "";
  const unvoicedLabel = isProtagonist ? " (SILENT PROTAGONIST)" : " (TEXT ONLY)";
  playingMeta.textContent = `[${item.chunk_name || ""}] flow: ${item.flow_id} • card: ${item.card_id}${hasVo ? "" : unvoicedLabel}`;

  if (item.threshold) {
    playingCheck.textContent = `CHECK DC ${item.threshold}`;
    playingCheck.className = "check-tag check-passive";
    playingCheck.style.display = "inline-block";
  } else {
    playingCheck.style.display = "none";
  }

  if (!hasVo) {
    const statusMsg = isProtagonist ? "SILENT PROTAGONIST (NO VO)" : "TEXT-ONLY (NO VO RECORDED)";
    setStatus(statusMsg, "");
    audioElement.removeAttribute("src");
    audioElement.load();
    return;
  }

  // Stream audio from server
  setStatus("STREAMING VO...", "loading");
  const audioUrl = `/api/audio?flow=${encodeURIComponent(item.flow_id)}&card=${encodeURIComponent(item.card_id)}`;
  audioElement.src = audioUrl;
  audioElement.play().catch(err => {
    console.warn("Autoplay blocked or audio failed:", err);
    setStatus("CLICK TO PLAY", "");
  });
}

function navigateDelta(delta) {
  if (!state.currentItems || state.currentItems.length === 0) return;
  const currentIndex = state.currentItems.findIndex(i => i.card_id === state.activeCardId);
  let nextIndex = currentIndex + delta;
  if (currentIndex === -1) nextIndex = 0;
  if (nextIndex >= 0 && nextIndex < state.currentItems.length) {
    playLine(state.currentItems[nextIndex]);
    const row = document.querySelector(`.dialogue-row[data-card-id="${state.currentItems[nextIndex].card_id}"]`);
    if (row) row.scrollIntoView({ block: "nearest", behavior: "smooth" });
  }
}

function escapeHtml(str) {
  if (!str) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
