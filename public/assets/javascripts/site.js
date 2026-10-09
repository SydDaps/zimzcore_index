// Homepage showcase: one browser window that cycles through the projects in
// the picker. Each picker button carries its project's screenshot, address bar
// text and anchor as data attributes, so adding a project is one button in the
// HTML and nothing here. Auto advance stops for good once someone picks one,
// and never starts under prefers-reduced-motion.
(() => {
  const picker = document.getElementById('picker');
  if (!picker) return;

  const img = document.getElementById('show-img');
  const url = document.getElementById('show-url');
  const link = document.getElementById('show-link');
  const buttons = [...picker.querySelectorAll('.pick')];
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const DWELL = 5000;
  let current = 0;
  let auto = !reduce;
  let timer;

  // Warm the cache so the first swap to each project does not flash.
  buttons.forEach(b => { new Image().src = b.dataset.img; });

  function show(index) {
    current = (index + buttons.length) % buttons.length;
    const b = buttons[current];

    buttons.forEach((other, n) => {
      other.setAttribute('aria-pressed', n === current);
      const bar = other.querySelector('i');
      bar.getAnimations().forEach(a => a.cancel());
      if (n === current && auto) {
        bar.animate([{ width: '0%' }, { width: '100%' }], { duration: DWELL, easing: 'linear', fill: 'forwards' });
      }
    });

    if (img.getAttribute('src') !== b.dataset.img) {
      img.classList.add('out');
      setTimeout(() => {
        img.src = b.dataset.img;
        img.alt = b.dataset.alt;
        img.classList.remove('out');
      }, reduce ? 0 : 220);
    }
    url.textContent = b.dataset.url;
    link.href = '#' + b.dataset.id;
    link.setAttribute('aria-label', b.querySelector('b').textContent + ', see details');

    // Keep the active button in view without scrolling the page itself.
    if (b.offsetLeft < picker.scrollLeft || b.offsetLeft + b.offsetWidth > picker.scrollLeft + picker.clientWidth) {
      picker.scrollTo({ left: b.offsetLeft, behavior: reduce ? 'auto' : 'smooth' });
    }
  }

  buttons.forEach((b, n) => b.addEventListener('click', () => {
    auto = false;
    clearInterval(timer);
    show(n);
  }));

  show(0);
  if (auto) timer = setInterval(() => show(current + 1), DWELL);
})();
