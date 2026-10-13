const { execFileSync } = require("node:child_process")

// Fresh throwaway user + diet + plans + shopping list (idempotent, touches only that user).
module.exports = () => {
  execFileSync("bin/rails", ["runner", "e2e/seed.rb"], { stdio: "inherit" })
}
