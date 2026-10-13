const { execFileSync } = require("node:child_process")

// Reset the throwaway user (nothing bought, no own items), also after a failed run.
module.exports = () => {
  execFileSync("bin/rails", ["runner", "e2e/seed.rb"], { stdio: "inherit" })
}
