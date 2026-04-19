document.addEventListener("DOMContentLoaded", () => {
  const flashMessages = document.querySelectorAll(".flashes .flash");
  flashMessages.forEach((message) => {
    message.setAttribute("role", "status");
  });
});
