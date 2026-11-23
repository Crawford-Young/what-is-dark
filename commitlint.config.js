// Dependabot writes "chore: Bump x from a to b": a capitalised subject that
// config-conventional's subject-case rejects, and dependabot.yml has no option
// to lower-case it. Skip only its own commits (prefix plus its sign-off), so a
// hand-written "Bump ..." is still linted.
const isDependabot = (message) =>
  /^chore(\([^)]*\))?: Bump /.test(message) &&
  /^Signed-off-by: dependabot\[bot\] /m.test(message);

export default {
  extends: ['@commitlint/config-conventional'],
  ignores: [isDependabot],
};
