(function () {
  function applyLanguage(message) {
    var strings = message.strings;
    document.documentElement.lang = message.lang;
    document.title = strings.app_title;
    document.querySelectorAll('[data-i18n]').forEach(function (node) {
      var key = node.dataset.i18n;
      if (strings[key]) node.textContent = strings[key];
    });
    document.querySelectorAll('.navbar-toggler,.navbar-toggle').forEach(function (node) { node.setAttribute('aria-label', strings.navigation); var hint=node.querySelector('.visually-hidden'); if(hint) hint.textContent=strings.navigation; });
    document.querySelectorAll('#ta_dates input').forEach(function (node) {
      node.setAttribute('aria-label',strings['Date range']);
      node.title=(message.lang==='vi' ? 'dd/mm/yyyy' : 'dd/mm/yyyy');
      var picker = window.jQuery(node).data('datepicker');
      if (picker) { picker.o.language = message.lang; picker.fill(); }
    });
    document.querySelectorAll('.leaflet-control-zoom-in').forEach(function (node) {node.title = strings.zoom_in;node.setAttribute('aria-label', strings.zoom_in);});
    document.querySelectorAll('.leaflet-control-zoom-out').forEach(function (node) {node.title = strings.zoom_out;node.setAttribute('aria-label', strings.zoom_out);});
  }
  Shiny.addCustomMessageHandler('dashboard-language', applyLanguage);
})();
