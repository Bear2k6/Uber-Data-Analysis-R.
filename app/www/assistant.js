(function () {
  // Send the exact visible text atomically; text-input debounce must not drop a fast submit.
  document.addEventListener('click', function (event) {
    if (!event.target.closest('#da_send')) return;
    var field = document.getElementById('da_question');
    if (field && window.Shiny) Shiny.setInputValue('da_submit', {question: field.value, nonce: Date.now()}, {priority: 'event'});
  });
  // Scroll only the local transcript after new or translated chat output is rendered.
  window.jQuery(document).on('shiny:value', function (event) {
    if (event.name !== 'da_chat') return;
    window.requestAnimationFrame(function () {
      var transcript = document.getElementById('assistant-transcript');
      if (transcript) transcript.scrollTop = transcript.scrollHeight;
    });
  });
})();
