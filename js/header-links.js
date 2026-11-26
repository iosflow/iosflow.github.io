const headerLinks = document.querySelector(".header-links");
const mobileHeader = window.matchMedia("(max-width: 768px)");

function fitHeaderLinks() {
  headerLinks.classList.remove("header-links-compact");
  if (mobileHeader.matches) return;

  const gap = parseFloat(getComputedStyle(headerLinks).columnGap);
  const links = Array.from(headerLinks.children);
  const requiredWidth = links.reduce(
    (width, link) => width + link.getBoundingClientRect().width,
    gap * (links.length - 1),
  );
  headerLinks.classList.toggle(
    "header-links-compact",
    requiredWidth > headerLinks.getBoundingClientRect().width,
  );
}

fitHeaderLinks();
new ResizeObserver(fitHeaderLinks).observe(headerLinks);
mobileHeader.addEventListener("change", fitHeaderLinks);
document.fonts.ready.then(fitHeaderLinks);
