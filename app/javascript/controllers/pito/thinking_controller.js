// Pito::ThinkingController
//
// Cycles a Braille spinner + a status word while a turn is being processed.
// The backend resolves the indicator by broadcasting a Turbo Stream replace
// when the turn completes, so this controller only handles the animation.
//
// Data attributes:
//   data-pito--thinking-frames-value        — JSON array of Braille chars
//   data-pito--thinking-doing-words-value   — JSON array of present-tense words
//   data-pito--thinking-done-words-value    — JSON array of past-tense words
//   data-pito--thinking-word-index-value    — fixed index into both arrays
//
// Targets:
//   braille  — the spinning Braille character span
//   word     — the cycling status word span

import { Controller } from "@hotwired/stimulus"

const BRAILLE_INTERVAL = 80    // ms between Braille frame changes
const WORD_INTERVAL    = 2000  // ms between word changes

export default class extends Controller {
  static targets = ["braille", "word"]
  static values = {
    frames:      Array,
    doingWords:  Array,
    doneWords:   Array,
    wordIndex:   Number
  }

  connect() {
    this.#startBraille()
    this.#startWords()
  }

  disconnect() {
    this.#stop()
  }

  // ── internals ──────────────────────────────────────────────────────────────

  #startBraille() {
    this.brailleIdx = 0
    this.brailleTimer = setInterval(() => {
      this.brailleIdx = (this.brailleIdx + 1) % this.framesValue.length
      this.brailleTarget.textContent = this.framesValue[this.brailleIdx]
    }, BRAILLE_INTERVAL)
  }

  #startWords() {
    this.wordIdx = this.wordIndexValue
    this.#updateWord()
    this.wordTimer = setInterval(() => {
      this.wordIdx = (this.wordIdx + 1) % this.doingWordsValue.length
      this.#updateWord()
    }, WORD_INTERVAL)
  }

  #updateWord() {
    this.wordTarget.textContent = this.doingWordsValue[this.wordIdx]
  }

  #stop() {
    clearInterval(this.brailleTimer)
    clearInterval(this.wordTimer)
  }
}
