// Two rules, both blocking: reviewable size and Conventional Commits titles.
// The drift bot's PR is exempt, but only when it comes from this repo
// (a fork could name its branch the same).
const { danger, fail, markdown } = require("danger");

const pr = danger.github.pr;
const isDriftPr = pr.head.ref === "drift/auto-detected" && pr.head.repo.full_name === pr.base.repo.full_name;

if (!isDriftPr) {
  const size = pr.additions + pr.deletions;
  if (size > 5000) {
    fail(`Big PR: ${size} changed lines.`);
    markdown("Split this into reviewable pieces. Generated files and lockfiles can go in their own PR.");
  }

  const conventional = /^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([\w\-.]+\))?!?:\s.+/;
  if (!conventional.test(pr.title)) {
    fail("PR title must follow Conventional Commits, e.g. `feat(eks): upgrade nonprod to 1.37`.");
  }
}
