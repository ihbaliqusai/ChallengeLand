/**
 * CHALLENGELAND TV & LAPTOP ARENA
 * Realtime WebSocket Game Controller & Audio Synthesizer
 */

(function () {
  'use strict';

  // --- 1. FIREBASE INITIALIZATION ---
  const firebaseConfig = {
    apiKey: 'AIzaSyDTrjbMXzLDHheBDGZorLvLbtlfpQYzqq0',
    authDomain: 'challengeland.firebaseapp.com',
    databaseURL: 'https://challengeland-default-rtdb.firebaseio.com',
    projectId: 'challengeland',
    storageBucket: 'challengeland.firebasestorage.app'
  };

  if (!firebase.apps.length) {
    firebase.initializeApp(firebaseConfig);
  }
  const db = firebase.database();

  // --- 2. AUDIO SYNTHESIZER (Web Audio API) ---
  let audioCtx = null;
  let soundEnabled = true;

  function initAudio() {
    if (!audioCtx) {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (AudioContext) audioCtx = new AudioContext();
    }
    if (audioCtx && audioCtx.state === 'suspended') {
      audioCtx.resume();
    }
  }

  function playTone(freq, type = 'sine', duration = 0.15, gainVal = 0.2) {
    if (!soundEnabled || !audioCtx) return;
    try {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = type;
      osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
      gain.gain.setValueAtTime(gainVal, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + duration);
    } catch (_) {}
  }

  function playTick() {
    playTone(800, 'triangle', 0.05, 0.12);
  }

  function playCorrect() {
    if (!soundEnabled || !audioCtx) return;
    try {
      const now = audioCtx.currentTime;
      [523.25, 659.25, 783.99, 1046.5].forEach((freq, idx) => {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(freq, now + idx * 0.08);
        gain.gain.setValueAtTime(0.2, now + idx * 0.08);
        gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.08 + 0.35);
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.start(now + idx * 0.08);
        osc.stop(now + idx * 0.08 + 0.35);
      });
    } catch (_) {}
  }

  function playWrong() {
    if (!soundEnabled || !audioCtx) return;
    try {
      const now = audioCtx.currentTime;
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(160, now);
      osc.frequency.linearRampToValueAtTime(90, now + 0.35);
      gain.gain.setValueAtTime(0.25, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.4);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(now);
      osc.stop(now + 0.4);
    } catch (_) {}
  }

  function playSteal() {
    if (!soundEnabled || !audioCtx) return;
    try {
      const now = audioCtx.currentTime;
      [440, 554.37, 659.25].forEach((freq, idx) => {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, now + idx * 0.06);
        gain.gain.setValueAtTime(0.25, now + idx * 0.06);
        gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.06 + 0.25);
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.start(now + idx * 0.06);
        osc.stop(now + idx * 0.06 + 0.25);
      });
    } catch (_) {}
  }

  let drumAudio = null;
  function playDrum() {
    if (!soundEnabled) return;
    try {
      if (!drumAudio) {
        drumAudio = new Audio('/sounds/drum1.mp3');
        drumAudio.loop = true;
      }
      drumAudio.currentTime = 0;
      drumAudio.play().catch(() => {});
    } catch (_) {}
  }

  function stopDrum() {
    try {
      if (drumAudio) {
        drumAudio.pause();
        drumAudio.currentTime = 0;
      }
    } catch (_) {}
  }

  function getAnswerRevealDrumDelayMs(pts) {
    const val = Number(pts) || 200;
    if (val <= 200) return 3000;
    if (val <= 400) return 6000;
    return 9000;
  }

  function playVictory() {
    if (!soundEnabled || !audioCtx) return;
    try {
      const notes = [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5];
      const now = audioCtx.currentTime;
      notes.forEach((freq, idx) => {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, now + idx * 0.12);
        gain.gain.setValueAtTime(0.25, now + idx * 0.12);
        gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.12 + 0.4);
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.start(now + idx * 0.12);
        osc.stop(now + idx * 0.12 + 0.4);
      });
    } catch (_) {}
  }

  // --- 3. STATE MANAGEMENT ---
  let currentPin = '';
  let activeMatchRef = null;
  let matchData = null;

  // Active question runtime
  let currentQCol = -1;
  let currentQRow = -1;
  let currentQuestion = null;
  let currentAwardValue = 200;
  let originalTurnSlot = 0;
  let currentAnsweringSlot = 0;
  let stealModeActive = false;
  let questionTimer = null;
  let questionSecondsRemaining = 60;

  // --- 4. DOM ELEMENTS ---
  const screens = {
    connect: document.getElementById('screen-connect'),
    arena: document.getElementById('screen-arena')
  };

  const connectionChip = document.getElementById('connection-chip');
  const connectionText = document.getElementById('connection-text');
  const btnSound = document.getElementById('btn-sound');
  const btnFullscreen = document.getElementById('btn-fullscreen');

  // Connect screen
  const pinSlots = [
    document.getElementById('slot-0'),
    document.getElementById('slot-1'),
    document.getElementById('slot-2'),
    document.getElementById('slot-3')
  ];
  const btnConnect = document.getElementById('btn-connect');
  const connectError = document.getElementById('connect-error');

  // Arena screen
  const teamACard = document.getElementById('team-a-card');
  const teamBCard = document.getElementById('team-b-card');
  const teamAName = document.getElementById('team-a-name');
  const teamBName = document.getElementById('team-b-name');
  const teamAScore = document.getElementById('team-a-score');
  const teamBScore = document.getElementById('team-b-score');
  const turnIndicator = document.getElementById('turn-indicator');
  const activeTvCode = document.getElementById('active-tv-code');
  const categoriesGrid = document.getElementById('categories-grid');
  const cellsRemainingCount = document.getElementById('cells-remaining-count');
  const btnDisconnect = document.getElementById('btn-disconnect');

  // Question Modal
  const questionModal = document.getElementById('question-modal');
  const qCategoryChip = document.getElementById('q-category-chip');
  const qValueChip = document.getElementById('q-value-chip');
  const qTurnChip = document.getElementById('q-turn-chip');
  const stealBanner = document.getElementById('steal-banner');
  const stealText = document.getElementById('steal-text');
  const qText = document.getElementById('q-text');
  const timerBar = document.getElementById('timer-bar');
  const timerNumber = document.getElementById('timer-number');
  const optionsGrid = document.getElementById('options-grid');
  const optionBtns = Array.from(document.querySelectorAll('.option-btn'));
  const stealActions = document.getElementById('steal-actions');
  const btnConcedeSteal = document.getElementById('btn-concede-steal');

  // Podium Modal
  const podiumModal = document.getElementById('podium-modal');
  const winnerName = document.getElementById('winner-name');
  const podiumNameA = document.getElementById('podium-name-a');
  const podiumScoreA = document.getElementById('podium-score-a');
  const podiumNameB = document.getElementById('podium-name-b');
  const podiumScoreB = document.getElementById('podium-score-b');
  const btnExitPodium = document.getElementById('btn-exit-podium');

  // --- 5. PIN ENTRY CONTROLLER ---
  let pinBuffer = '';

  function updatePinDisplay() {
    for (let i = 0; i < 4; i++) {
      const slot = pinSlots[i];
      if (i < pinBuffer.length) {
        slot.textContent = pinBuffer[i];
        slot.classList.add('filled');
        slot.classList.remove('active');
      } else if (i === pinBuffer.length) {
        slot.textContent = '-';
        slot.classList.remove('filled');
        slot.classList.add('active');
      } else {
        slot.textContent = '-';
        slot.classList.remove('filled', 'active');
      }
    }
    btnConnect.disabled = pinBuffer.length !== 4;
    connectError.classList.add('hidden');
  }

  function handleKeyInput(key) {
    initAudio();
    if (key === 'clear') {
      pinBuffer = '';
      playTone(300, 'sine', 0.08);
    } else if (key === 'backspace') {
      pinBuffer = pinBuffer.slice(0, -1);
      playTone(400, 'sine', 0.05);
    } else if (/^[0-9]$/.test(key)) {
      if (pinBuffer.length < 4) {
        pinBuffer += key;
        playTone(500 + pinBuffer.length * 80, 'sine', 0.08);
        if (pinBuffer.length === 4) {
          // Auto connect when 4th digit entered
          connectToMatch(pinBuffer);
        }
      }
    }
    updatePinDisplay();
  }

  // Keypad button listeners
  document.querySelectorAll('.key-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      handleKeyInput(btn.dataset.key);
    });
  });

  // Physical keyboard support
  window.addEventListener('keydown', (e) => {
    if (screens.connect.classList.contains('active')) {
      if (e.key >= '0' && e.key <= '9') {
        handleKeyInput(e.key);
      } else if (e.key === 'Backspace') {
        handleKeyInput('backspace');
      } else if (e.key === 'Escape') {
        handleKeyInput('clear');
      } else if (e.key === 'Enter' && pinBuffer.length === 4) {
        connectToMatch(pinBuffer);
      }
    } else if (e.key === 'F11') {
      toggleFullscreen();
    }
  });

  btnConnect.addEventListener('click', () => {
    if (pinBuffer.length === 4) {
      connectToMatch(pinBuffer);
    }
  });

  // --- 6. MATCH CONNECTION & REALTIME SYNC ---
  function connectToMatch(pin) {
    initAudio();
    connectError.classList.add('hidden');
    connectionChip.className = 'status-chip offline';
    connectionText.textContent = 'جاري الاتصال...';

    if (activeMatchRef) {
      activeMatchRef.off();
    }

    currentPin = pin.trim();
    activeMatchRef = db.ref('TvMatches/' + currentPin);

    activeMatchRef.on('value', (snapshot) => {
      if (!snapshot.exists()) {
        connectError.textContent = 'لم يتم العثور على مباراة بهذا الرمز (« ' + currentPin + ' »). تأكد من الرمز من تطبيق الهاتف.';
        connectError.classList.remove('hidden');
        connectionChip.className = 'status-chip offline';
        connectionText.textContent = 'غير متصل';
        btnConnect.disabled = false;
        return;
      }

      matchData = snapshot.val();
      onMatchUpdated(matchData);
    }, (error) => {
      connectError.textContent = 'خطأ في الاتصال بالسحابة: ' + error.message;
      connectError.classList.remove('hidden');
      connectionChip.className = 'status-chip offline';
      connectionText.textContent = 'فشل الاتصال';
    });
  }

  function onMatchUpdated(data) {
    if (!data) return;

    // Switch screen to arena if on connect
    if (!screens.arena.classList.contains('active')) {
      screens.connect.classList.remove('active');
      screens.arena.classList.add('active');
    }

    // Update connection chip
    connectionChip.className = 'status-chip online';
    connectionText.textContent = 'متصل بالشاشة ⚡';
    activeTvCode.textContent = currentPin;

    // Team Names & Scores
    const nameA = data.teamAName || 'الفريق الأول';
    const nameB = data.teamBName || 'الفريق الثاني';
    const scoreA = data.scoreA || 0;
    const scoreB = data.scoreB || 0;

    teamAName.textContent = nameA;
    teamBName.textContent = nameB;
    teamAScore.textContent = scoreA;
    teamBScore.textContent = scoreB;

    // Active Turn
    const state = data.state || {};
    const pickerSlot = (state.pickerSlot === 1) ? 1 : 0;

    if (pickerSlot === 0) {
      teamACard.classList.add('active-turn');
      teamBCard.classList.remove('active-turn');
      turnIndicator.textContent = '⚔️ دور ' + nameA + ' (الفريق الأول)';
      turnIndicator.className = 'turn-text';
    } else {
      teamBCard.classList.add('active-turn');
      teamACard.classList.remove('active-turn');
      turnIndicator.textContent = '⚔️ دور ' + nameB + ' (الفريق الثاني)';
      turnIndicator.className = 'turn-text cyan';
    }

    // Render 6-Category Grid
    renderCategoriesGrid(state);

    // Check if match finished
    if (data.status === 'finished') {
      showPodium(data);
    }
  }

  // --- 7. RENDER CATEGORIES GRID ---
  function renderCategoriesGrid(state) {
    categoriesGrid.innerHTML = '';
    const categories = state.selectedCategories || ['فئة 1', 'فئة 2', 'فئة 3', 'فئة 4', 'فئة 5', 'فئة 6'];
    const cells = state.cells || [];
    const values = [200, 400, 600];

    let remaining = 0;

    for (let col = 0; col < categories.length; col++) {
      const catName = categories[col] || ('فئة ' + (col + 1));
      const colDiv = document.createElement('div');
      colDiv.className = 'category-col';

      // Header card
      const headerCard = document.createElement('div');
      headerCard.className = 'category-header-card';
      headerCard.innerHTML = `<span class="category-title">${catName}</span>`;
      colDiv.appendChild(headerCard);

      // 3 Value Tiles
      for (let row = 0; row < 3; row++) {
        const val = values[row];
        const cellData = (cells[col] && cells[col][row]) ? cells[col][row] : null;
        const consumed = cellData ? !!cellData.consumed : false;

        if (!consumed) remaining++;

        const tile = document.createElement('button');
        tile.className = 'cell-tile' + (consumed ? ' consumed' : '');
        tile.innerHTML = `
          <span class="cell-points">${val}</span>
          <span class="cell-sub">${consumed ? 'مُجاب' : 'نقطة'}</span>
        `;

        if (!consumed && cellData && cellData.question) {
          tile.addEventListener('click', () => {
            openQuestionModal(col, row, catName, val, cellData.question);
          });
        }

        colDiv.appendChild(tile);
      }

      categoriesGrid.appendChild(colDiv);
    }

    cellsRemainingCount.textContent = remaining;

    if (remaining === 0 && matchData && matchData.status !== 'finished') {
      finishMatch();
    }
  }

  function showWebObservationModal(imageUrl, onFinished) {
    const overlay = document.createElement('div');
    overlay.style.position = 'fixed';
    overlay.style.inset = '0';
    overlay.style.background = 'rgba(3, 7, 18, 0.95)';
    overlay.style.backdropFilter = 'blur(12px)';
    overlay.style.zIndex = '999999';
    overlay.style.display = 'flex';
    overlay.style.flexDirection = 'column';
    overlay.style.alignItems = 'center';
    overlay.style.justifyContent = 'center';
    overlay.style.padding = '20px';

    const card = document.createElement('div');
    card.style.background = 'linear-gradient(180deg, #0d1e44 0%, #071129 100%)';
    card.style.border = '2px solid rgba(56, 189, 248, 0.6)';
    card.style.borderRadius = '24px';
    card.style.boxShadow = '0 25px 60px rgba(0,0,0,0.9), 0 0 35px rgba(56,189,248,0.3)';
    card.style.padding = '20px';
    card.style.maxWidth = '800px';
    card.style.width = '90%';
    card.style.display = 'flex';
    card.style.flexDirection = 'column';
    card.style.alignItems = 'center';

    const header = document.createElement('div');
    header.style.display = 'flex';
    header.style.justifyContent = 'space-between';
    header.style.alignItems = 'center';
    header.style.width = '100%';
    header.style.marginBottom = '14px';

    const title = document.createElement('div');
    title.textContent = '👁️ دقة ملاحظة';
    title.style.color = '#38bdf8';
    title.style.fontSize = '22px';
    title.style.fontWeight = 'bold';

    const badge = document.createElement('div');
    badge.textContent = 'تحميل الصورة..';
    badge.style.background = 'rgba(239, 68, 68, 0.2)';
    badge.style.color = '#f87171';
    badge.style.border = '1px solid #ef4444';
    badge.style.borderRadius = '20px';
    badge.style.padding = '6px 16px';
    badge.style.fontSize = '18px';
    badge.style.fontWeight = 'bold';

    header.appendChild(title);
    header.appendChild(badge);
    card.appendChild(header);

    const img = document.createElement('img');
    img.style.maxWidth = '100%';
    img.style.maxHeight = '65vh';
    img.style.borderRadius = '16px';
    img.style.objectFit = 'contain';
    img.style.display = 'none';

    const spinner = document.createElement('div');
    spinner.textContent = '⏳ جاري تحميل الصورة...';
    spinner.style.color = '#94a3b8';
    spinner.style.fontSize = '18px';
    spinner.style.margin = '40px 0';

    card.appendChild(spinner);
    card.appendChild(img);
    overlay.appendChild(card);
    document.body.appendChild(overlay);

    let timer = null;
    let finished = false;
    const cleanup = () => {
      if (finished) return;
      finished = true;
      if (timer) clearInterval(timer);
      if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
      if (onFinished) onFinished();
    };

    img.onload = () => {
      spinner.style.display = 'none';
      img.style.display = 'block';
      badge.style.background = 'rgba(14, 165, 233, 0.2)';
      badge.style.color = '#38bdf8';
      badge.style.border = '1px solid #0284c7';
      let sec = 5;
      badge.textContent = sec + ' ثوانٍ';
      timer = setInterval(() => {
        sec--;
        if (sec <= 0) {
          cleanup();
        } else {
          badge.textContent = sec + ' ثوانٍ';
        }
      }, 1000);
    };

    img.onerror = () => {
      cleanup();
    };

    img.src = imageUrl;
  }

  // --- 8. QUESTION MODAL CONTROLLER ---
  function openQuestionModal(col, row, categoryName, pointValue, questionObj) {
    initAudio();
    currentQCol = col;
    currentQRow = row;
    currentQuestion = questionObj;
    currentAwardValue = pointValue;
    originalTurnSlot = (matchData.state && matchData.state.pickerSlot === 1) ? 1 : 0;
    currentAnsweringSlot = originalTurnSlot;
    stealModeActive = false;

    // Meta chips
    qCategoryChip.textContent = 'فئة: ' + categoryName;
    qValueChip.textContent = pointValue + ' نقطة';
    updateQuestionTurnChip();

    stealBanner.classList.add('hidden');
    stealActions.classList.add('hidden');

    // Shuffle 4 options
    const rawOptions = [
      { text: questionObj.R || '', isCorrect: true },
      { text: questionObj.W1 || '', isCorrect: false },
      { text: questionObj.W2 || '', isCorrect: false },
      { text: questionObj.W3 || '', isCorrect: false }
    ];

    // Fisher-Yates Shuffle
    for (let i = rawOptions.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [rawOptions[i], rawOptions[j]] = [rawOptions[j], rawOptions[i]];
    }

    // Bind options to buttons
    optionBtns.forEach((btn, idx) => {
      btn.className = 'option-btn';
      btn.disabled = false;
      const optData = rawOptions[idx] || { text: '', isCorrect: false };
      const textSpan = btn.querySelector('.opt-text');
      textSpan.textContent = optData.text;
      btn.dataset.correct = optData.isCorrect ? 'true' : 'false';

      btn.onclick = () => onOptionSelected(btn, optData.isCorrect);
    });

    // Show modal
    questionModal.classList.remove('hidden');

    if (questionObj.Img && questionObj.Img.trim()) {
      optionBtns.forEach(btn => btn.style.visibility = 'hidden');
      qText.innerHTML = '<button id="btnWebArenaObservation" style="background: linear-gradient(135deg, #0284c7, #0369a1); color: #fff; border: 2px solid #38bdf8; border-radius: 14px; padding: 14px 28px; font-size: 22px; font-weight: bold; cursor: pointer; box-shadow: 0 4px 20px rgba(2,132,199,0.5);">اضغط لترى الصورة 👁️</button>';
      let obsOpened = false;
      const openObs = () => {
        if (obsOpened) return;
        obsOpened = true;
        showWebObservationModal(questionObj.Img, () => {
          qText.textContent = questionObj.Q || 'نص السؤال';
          optionBtns.forEach(btn => btn.style.visibility = 'visible');
          startQuestionTimer(60);
        });
      };
      const btnObs = document.getElementById('btnWebArenaObservation');
      if (btnObs) btnObs.onclick = openObs;
      setTimeout(openObs, 4000);
    } else {
      qText.textContent = questionObj.Q || 'نص السؤال';
      optionBtns.forEach(btn => btn.style.visibility = 'visible');
      startQuestionTimer(60);
    }
  }

  function updateQuestionTurnChip() {
    const currentName = currentAnsweringSlot === 0
      ? (matchData.teamAName || 'الفريق الأول')
      : (matchData.teamBName || 'الفريق الثاني');
    qTurnChip.textContent = (stealModeActive ? '⚡ خطف: دور ' : '⚔️ دور ') + currentName;
    qTurnChip.className = 'chip ' + (currentAnsweringSlot === 0 ? 'gold-chip' : 'blue-chip');
  }

  function startQuestionTimer(seconds) {
    clearInterval(questionTimer);
    questionSecondsRemaining = seconds;
    updateTimerUI();

    questionTimer = setInterval(() => {
      questionSecondsRemaining--;
      updateTimerUI();

      if (questionSecondsRemaining <= 5 && questionSecondsRemaining > 0) {
        playTick();
      }

      if (questionSecondsRemaining <= 0) {
        clearInterval(questionTimer);
        onTimerExpired();
      }
    }, 1000);
  }

  function updateTimerUI() {
    timerNumber.textContent = questionSecondsRemaining;
    const pct = Math.max(0, (questionSecondsRemaining / 60) * 100);
    timerBar.style.width = pct + '%';

    if (questionSecondsRemaining <= 5) {
      timerBar.className = 'timer-bar-fill danger';
    } else if (questionSecondsRemaining <= 10) {
      timerBar.className = 'timer-bar-fill warning';
    } else {
      timerBar.className = 'timer-bar-fill';
    }
  }

  function onOptionSelected(clickedBtn, isCorrect) {
    clearInterval(questionTimer);

    // Disable all options during result
    optionBtns.forEach(btn => btn.disabled = true);

    clickedBtn.classList.add('suspense');
    playDrum();

    const delayMs = getAnswerRevealDrumDelayMs(currentAwardValue);

    setTimeout(() => {
      stopDrum();
      clickedBtn.classList.remove('suspense');

      if (isCorrect) {
        // --- CORRECT ANSWER ---
        clickedBtn.classList.add('correct');
        playCorrect();

        // Award points to the current answering team
        awardPointsAndClose(currentAnsweringSlot, currentAwardValue);
      } else {
        // --- WRONG ANSWER ---
        clickedBtn.classList.add('wrong');
        playWrong();

        if (!stealModeActive) {
          // Trigger Steal mode for the other team
          setTimeout(() => {
            activateStealMode();
          }, 1200);
        } else {
          // Steal also failed -> Reveal correct answer & consume cell with 0 points
          revealCorrectOption();
          setTimeout(() => {
            awardPointsAndClose(-1, 0);
          }, 2200);
        }
      }
    }, delayMs);
  }

  function activateStealMode() {
    stealModeActive = true;
    currentAnsweringSlot = 1 - originalTurnSlot;
    updateQuestionTurnChip();

    const stealTeamName = currentAnsweringSlot === 0
      ? (matchData.teamAName || 'الفريق الأول')
      : (matchData.teamBName || 'الفريق الثاني');

    stealText.textContent = '⚡ فرصة خطف السؤال لفريق ' + stealTeamName + '!';
    stealBanner.classList.remove('hidden');
    stealActions.classList.remove('hidden');
    playSteal();

    // Re-enable remaining non-wrong options
    optionBtns.forEach(btn => {
      if (!btn.classList.contains('wrong')) {
        btn.disabled = false;
      }
    });

    btnConcedeSteal.onclick = () => {
      clearInterval(questionTimer);
      revealCorrectOption();
      setTimeout(() => {
        awardPointsAndClose(-1, 0);
      }, 1500);
    };

    // 15 seconds for steal
    startQuestionTimer(15);
  }

  function onTimerExpired() {
    playWrong();
    if (!stealModeActive) {
      activateStealMode();
    } else {
      revealCorrectOption();
      setTimeout(() => {
        awardPointsAndClose(-1, 0);
      }, 2000);
    }
  }

  function revealCorrectOption() {
    optionBtns.forEach(btn => {
      if (btn.dataset.correct === 'true') {
        btn.classList.add('correct');
      }
    });
  }

  // --- 9. RESOLVE QUESTION & SYNC TO FIREBASE ---
  function awardPointsAndClose(winningSlot, points) {
    if (!matchData || !activeMatchRef) return;

    let scoreA = matchData.scoreA || 0;
    let scoreB = matchData.scoreB || 0;

    if (winningSlot === 0) {
      scoreA += points;
    } else if (winningSlot === 1) {
      scoreB += points;
    }

    // Mark cell consumed in local state copy
    const state = matchData.state || {};
    if (state.cells && state.cells[currentQCol] && state.cells[currentQCol][currentQRow]) {
      state.cells[currentQCol][currentQRow].consumed = true;
    }

    // Advance regular turn
    const nextTurnIndex = (matchData.turnIndex || 0) + 1;
    const nextPickerSlot = 1 - originalTurnSlot;
    state.pickerSlot = nextPickerSlot;
    state.turnIndex = nextTurnIndex;

    const updates = {
      scoreA: scoreA,
      scoreB: scoreB,
      turnIndex: nextTurnIndex,
      updatedAt: Date.now(),
      state: state
    };

    activeMatchRef.update(updates).then(() => {
      setTimeout(() => {
        questionModal.classList.add('hidden');
      }, 1400);
    }).catch(err => {
      console.error('Firebase update failed:', err);
      questionModal.classList.add('hidden');
    });
  }

  // --- 10. CHAMPIONSHIP FINISH & PODIUM ---
  function finishMatch() {
    if (!activeMatchRef || !matchData) return;

    const scoreA = matchData.scoreA || 0;
    const scoreB = matchData.scoreB || 0;
    let winnerSlot = -2;
    let winnerNameStr = 'تعادل';

    if (scoreA > scoreB) {
      winnerSlot = 0;
      winnerNameStr = matchData.teamAName || 'الفريق الأول';
    } else if (scoreB > scoreA) {
      winnerSlot = 1;
      winnerNameStr = matchData.teamBName || 'الفريق الثاني';
    }

    activeMatchRef.update({
      status: 'finished',
      winnerSlot: winnerSlot,
      winnerName: winnerNameStr,
      updatedAt: Date.now()
    });
  }

  function showPodium(data) {
    const scoreA = data.scoreA || 0;
    const scoreB = data.scoreB || 0;
    const nameA = data.teamAName || 'الفريق الأول';
    const nameB = data.teamBName || 'الفريق الثاني';
    const winner = data.winnerName || (scoreA > scoreB ? nameA : nameB);

    winnerName.textContent = winner;
    podiumNameA.textContent = nameA;
    podiumScoreA.textContent = scoreA + ' نقطة';
    podiumNameB.textContent = nameB;
    podiumScoreB.textContent = scoreB + ' نقطة';

    playVictory();
    podiumModal.classList.remove('hidden');
  }

  btnExitPodium.addEventListener('click', () => {
    podiumModal.classList.add('hidden');
    disconnectMatch();
  });

  // --- 11. UTILITY ACTIONS ---
  function disconnectMatch() {
    if (activeMatchRef) {
      activeMatchRef.off();
      activeMatchRef = null;
    }
    matchData = null;
    pinBuffer = '';
    updatePinDisplay();
    screens.arena.classList.remove('active');
    screens.connect.classList.add('active');
    connectionChip.className = 'status-chip offline';
    connectionText.textContent = 'بانتظار الاتصال';
  }

  btnDisconnect.addEventListener('click', disconnectMatch);

  btnSound.addEventListener('click', () => {
    initAudio();
    soundEnabled = !soundEnabled;
    btnSound.textContent = soundEnabled ? '🔊' : '🔇';
  });

  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(() => {});
    } else {
      if (document.exitFullscreen) document.exitFullscreen();
    }
  }

  btnFullscreen.addEventListener('click', toggleFullscreen);

  // --- 12. AUTO-CONNECT FROM URL PARAMETERS ---
  window.addEventListener('DOMContentLoaded', () => {
    const params = new URLSearchParams(window.location.search);
    const pin = params.get('pin') || params.get('code');
    if (pin && /^[0-9]{4}$/.test(pin.trim())) {
      pinBuffer = pin.trim();
      updatePinDisplay();
      connectToMatch(pinBuffer);
    } else {
      updatePinDisplay();
    }
  });

})();
