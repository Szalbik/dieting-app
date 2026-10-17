document.addEventListener("DOMContentLoaded", () => {
  const flashMessages = document.querySelectorAll(".flashes .flash");
  flashMessages.forEach((message) => {
    message.setAttribute("role", "status");
  });
});

// No rails-ujs here: ask before submitting forms that carry data-confirm (e.g. user delete).
document.addEventListener("submit", (event) => {
  const message = event.target.dataset?.confirm;
  if (message && !window.confirm(message)) event.preventDefault();
});
