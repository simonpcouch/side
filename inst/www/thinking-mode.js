(function () {
  let indicatorEl = null
  let indicatorTextEl = null
  let fadeTimer = null
  let textareaEl = null
  let lastIndicatorState = null
  let thinkingHidden = false
  const thinkingStreams = new Map()
  let assistantCounter = 0

  function sendToggle(source) {
    if (!window.Shiny) return
    if (thinkingHidden) return
    window.Shiny.setInputValue(
      'thinking_toggle',
      { source, ts: Date.now() },
      { priority: 'event' },
    )
  }

  function onKeyDown(event) {
    if (event.defaultPrevented) return
    if (thinkingHidden) return

    const isCtrlT =
      (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 't'

    if (isCtrlT) {
      event.preventDefault()
      sendToggle('ctrl')
    }
  }

  function ensureIndicator(chatInput) {
    if (!indicatorEl || !indicatorEl.isConnected) {
      indicatorEl = document.createElement('div')
      indicatorEl.className = 'side-thinking-indicator'
      indicatorEl.setAttribute('role', 'status')
      indicatorEl.setAttribute('aria-live', 'polite')
      chatInput.appendChild(indicatorEl)
      indicatorTextEl = null
    }

    if (!indicatorTextEl || !indicatorTextEl.isConnected) {
      indicatorTextEl = document.createElement('span')
      indicatorTextEl.className = 'side-thinking-text'
      indicatorEl.appendChild(indicatorTextEl)
    }

    return indicatorEl
  }

  function markAssistantMessages() {
    const messages = document.querySelectorAll('shiny-chat-message[data-role="assistant"]')
    messages.forEach((msg) => {
      if (!msg.dataset.sideAssistantIndex) {
        assistantCounter += 1
        msg.dataset.sideAssistantIndex = assistantCounter
      }
    })
  }

  function applyIndicatorState(state) {
    if (!state) return

    if (state.hidden) {
      thinkingHidden = true
      if (indicatorEl) {
        indicatorEl.classList.remove('side-thinking-visible')
      }
      return
    }

    thinkingHidden = false
    const { enabled, animate = true } = state
    const chatInput = document.querySelector('shiny-chat-input')
    if (!chatInput) return

    const indicator = ensureIndicator(chatInput)
    const textTarget = indicatorTextEl || indicator
    indicator.classList.add('side-thinking-visible')
    indicator.classList.toggle('side-thinking-indicator--on', !!enabled)
    indicator.classList.remove('side-thinking-indicator--muted')
    textTarget.textContent = enabled ? 'Thinking on' : 'Thinking off'

    if (fadeTimer) {
      clearTimeout(fadeTimer)
      fadeTimer = null
    }

    if (animate) {
      fadeTimer = setTimeout(() => {
        indicator.classList.add('side-thinking-indicator--muted')
        textTarget.textContent =
          (enabled ? 'Thinking on' : 'Thinking off') + ' (Ctrl+T)'
      }, 2500)
    } else {
      indicator.classList.add('side-thinking-indicator--muted')
      textTarget.textContent =
        (enabled ? 'Thinking on' : 'Thinking off') + ' (Ctrl+T)'
    }
  }

  function setIndicatorState(state) {
    lastIndicatorState = state
    applyIndicatorState(state)
  }

  function attachListeners() {
    const chatInput = document.querySelector('shiny-chat-input')
    if (!chatInput) return
    const textarea = chatInput.querySelector('textarea')
    if (!textarea) return

    if (textareaEl === textarea) return

    textareaEl = textarea
    if (lastIndicatorState && !thinkingHidden) {
      ensureIndicator(chatInput)
      applyIndicatorState(lastIndicatorState)
    }
  }

  function findAssistantMessage(order, mode) {
    const messagesRoot = document.querySelector('shiny-chat-messages')
    if (!messagesRoot) return null

    if (mode === 'live') {
      const streaming = messagesRoot.querySelector('shiny-chat-message[streaming]')
      if (streaming) return streaming
    }

    if (order) {
      const selector = `shiny-chat-message[data-side-assistant-index="${order}"]`
      const targeted = messagesRoot.querySelector(selector)
      if (targeted) return targeted
    }

    const assistant = messagesRoot.querySelector('shiny-chat-message[data-role="assistant"]:last-of-type')
    if (assistant) return assistant

    const fallback = messagesRoot.querySelector('shiny-chat-message:last-of-type')
    return fallback
  }

  function updateThinkingPreview(parts) {
    if (!parts || !parts.preview) return
    const fullText = parts.fullText || ''
    const displayText = fullText.trim() ? fullText : 'Thinking…'
    parts.preview.textContent = displayText
  }

  function createThinkingContainer(payload) {
    const message = findAssistantMessage(payload.order, payload.mode)
    if (!message) return null

    let wrapper = message.querySelector(`.side-thinking-collapse[data-id=\"${payload.id}\"]`)
    if (wrapper) {
      return {
        wrapper,
        button: wrapper.querySelector('button'),
        preview: wrapper.querySelector('.side-thinking-preview'),
        caret: wrapper.querySelector('.side-thinking-caret'),
        fullText: wrapper.dataset.fullText || '',
      }
    }

    wrapper = document.createElement('div')
    wrapper.className = 'side-thinking-collapse'
    wrapper.dataset.id = payload.id
    wrapper.dataset.fullText = ''
    wrapper.setAttribute('data-open', 'false')

    const button = document.createElement('button')
    button.type = 'button'
    button.setAttribute('aria-expanded', 'false')

    const preview = document.createElement('div')
    preview.className = 'side-thinking-preview side-thinking-shimmer'
    preview.textContent = 'Thinking…'

    const caret = document.createElement('span')
    caret.className = 'side-thinking-caret'
    caret.textContent = '▾'

    button.appendChild(preview)
    button.appendChild(caret)
    button.addEventListener('click', () => {
      const isOpen = wrapper.getAttribute('data-open') === 'true'
      wrapper.setAttribute('data-open', (!isOpen).toString())
      button.setAttribute('aria-expanded', (!isOpen).toString())
    })

    wrapper.appendChild(button)

    const existingThinking = message.querySelectorAll('.side-thinking-collapse')
    if (existingThinking.length > 0) {
      const lastThinking = existingThinking[existingThinking.length - 1]
      lastThinking.insertAdjacentElement('afterend', wrapper)
    } else {
      const anchor = message.querySelector(`.side-thinking-anchor[data-id="${payload.id}"]`)
      if (anchor) {
        anchor.replaceWith(wrapper)
      } else {
        if ((payload._retries || 0) < 20) {
          return null
        }

        const container =
          message.querySelector(':scope > div:not(.message-icon):not(.side-thinking-collapse)') ||
          message.querySelector('shiny-markdown-stream, shiny-user-message')

        if (container && container.parentNode === message) {
          container.insertAdjacentElement('afterbegin', wrapper)
        } else if (container && container !== message) {
          container.insertAdjacentElement('afterbegin', wrapper)
        } else {
          message.appendChild(wrapper)
        }
      }
    }

    return { wrapper, button, preview, caret, fullText: '' }
  }

  function scheduleThinkingRetry(payload) {
    const tries = payload._retries || 0
    if (tries > 20) return
    const nextPayload = { ...payload, _retries: tries + 1 }
    setTimeout(() => handleThinkingStream(nextPayload), 100)
  }

  function handleThinkingStream(payload) {
    const { id, text = '', done = false, mode = 'live' } = payload
    let parts = thinkingStreams.get(id)
    if (!parts) {
      parts = createThinkingContainer(payload)
      if (!parts) {
        scheduleThinkingRetry(payload)
        return
      }
      thinkingStreams.set(id, parts)
    }

    if (text) {
      parts.fullText = (parts.fullText || '') + text
      parts.fullText = parts.fullText.trimStart()
      parts.fullText = parts.fullText.replace(/^\s+/,'')
      if (parts.wrapper) {
        parts.wrapper.dataset.fullText = parts.fullText
      }
      updateThinkingPreview(parts)
    }

    if (mode === 'live' && !done) {
      parts.preview.classList.add('side-thinking-shimmer')
    } else {
      parts.preview.classList.remove('side-thinking-shimmer')
    }
    
    // We don't delete the stream info on done anymore, because we might need
    // to re-inject the wrapper if shinychat/markdown-stream re-renders the DOM.
    // if (done) {
    //   thinkingStreams.delete(id)
    // }
    
    processAnchors()
  }

  function processAnchors() {
    const anchors = document.querySelectorAll('.side-thinking-anchor')
    anchors.forEach(anchor => {
      const id = anchor.dataset.id
      if (thinkingStreams.has(id)) {
        const parts = thinkingStreams.get(id)
        // If the wrapper is not currently connected (or we just found a new anchor),
        // replace the anchor with the wrapper.
        if (anchor.isConnected && parts.wrapper) {
          anchor.replaceWith(parts.wrapper)
        }
      }
    })
  }

  function init() {
    attachListeners()
    markAssistantMessages()
    processAnchors()
  }

  const observer = new MutationObserver(() => {
    attachListeners()
    markAssistantMessages()
    processAnchors()
  })

  document.addEventListener('DOMContentLoaded', () => {
    init()
    document.addEventListener('keydown', onKeyDown)
    observer.observe(document.body, { childList: true, subtree: true })
  })

  function registerThinkingHandlers() {
    if (!window.Shiny) return
    Shiny.addCustomMessageHandler('side-thinking-state', setIndicatorState)
    Shiny.addCustomMessageHandler('side-thinking-stream', handleThinkingStream)
  }

  if (window.Shiny) {
    registerThinkingHandlers()
  } else {
    document.addEventListener('shiny:connected', registerThinkingHandlers)
  }
})()
