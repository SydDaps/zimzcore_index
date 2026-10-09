// Homepage showcase: one browser window that cycles through the projects in
// the picker. Each picker button carries its project's screenshot, address bar
// text and anchor as data attributes, so adding a project is one button in the
// HTML and nothing here.
//
// The gold progress bar under the active button IS the timer: when its
// animation finishes, the next project shows. Pausing the bar pauses the cycle,
// which keeps the two from ever drifting apart. It pauses while the pointer or
// keyboard focus is on the showcase, while the tab is hidden, and while the
// showcase is scrolled out of view. Picking a project stops the cycle for good.
// Under prefers-reduced-motion it never starts.
(() => {
  const picker = document.getElementById('picker');
  if (!picker) return;

  const showcase = picker.closest('.showcase');
  const screen = showcase.querySelector('.screen');
  const url = document.getElementById('show-url');
  const link = document.getElementById('show-link');
  const buttons = [...picker.querySelectorAll('.pick')];
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const DWELL = 5000;

  let current = 0;
  let auto = !reduce;
  let progress = null;
  const holds = new Set(); // reasons the cycle is paused right now

  // Warm the cache so the first swap to each project is instant.
  buttons.forEach(b => { new Image().src = b.dataset.img; });

  function swapImage(src, alt) {
    const top = screen.lastElementChild;
    if (top && top.getAttribute('src') === src) return;

    const next = new Image();
    next.src = src;
    next.alt = alt;
    next.className = 'incoming';
    // Decode before showing, so the fade never starts on a blank frame.
    const ready = next.decode ? next.decode().catch(() => {}) : Promise.resolve();
    ready.then(() => {
      screen.appendChild(next);
      requestAnimationFrame(() => requestAnimationFrame(() => next.classList.remove('incoming')));
      // Once it is fully in, drop everything underneath it. Clicking fast just
      // retargets the transition, and the stack never grows past a few images.
      next.addEventListener('transitionend', () => {
        while (screen.firstElementChild !== next) screen.firstElementChild.remove();
      }, { once: true });
      if (reduce) while (screen.firstElementChild !== next) screen.firstElementChild.remove();
    });
  }

  function startProgress(b) {
    if (progress) progress.cancel();
    progress = null;
    if (!auto) return;
    progress = b.querySelector('i').animate(
      [{ transform: 'scaleX(0)' }, { transform: 'scaleX(1)' }],
      { duration: DWELL, easing: 'linear' }
    );
    if (holds.size) progress.pause();
    progress.onfinish = () => { if (auto) show(current + 1); };
  }

  function show(index) {
    current = (index + buttons.length) % buttons.length;
    const b = buttons[current];

    buttons.forEach((other, n) => other.setAttribute('aria-pressed', n === current));
    swapImage(b.dataset.img, b.dataset.alt);
    url.textContent = b.dataset.url;
    link.href = '#' + b.dataset.id;
    link.setAttribute('aria-label', b.querySelector('b').textContent + ', see details');
    startProgress(b);

    // Keep the active button in view without scrolling the page itself.
    if (b.offsetLeft < picker.scrollLeft || b.offsetLeft + b.offsetWidth > picker.scrollLeft + picker.clientWidth) {
      picker.scrollTo({ left: b.offsetLeft, behavior: reduce ? 'auto' : 'smooth' });
    }
  }

  function hold(reason, on) {
    on ? holds.add(reason) : holds.delete(reason);
    if (!progress) return;
    holds.size ? progress.pause() : progress.play();
  }

  buttons.forEach((b, n) => b.addEventListener('click', () => {
    auto = false;
    show(n);
  }));

  showcase.addEventListener('pointerenter', () => hold('pointer', true));
  showcase.addEventListener('pointerleave', () => hold('pointer', false));
  showcase.addEventListener('focusin', () => hold('focus', true));
  showcase.addEventListener('focusout', e => { if (!showcase.contains(e.relatedTarget)) hold('focus', false); });
  document.addEventListener('visibilitychange', () => hold('hidden', document.hidden));
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(([entry]) => hold('offscreen', !entry.isIntersecting)).observe(showcase);
  }

  show(0);
})();
