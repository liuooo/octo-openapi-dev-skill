// octo-list-check.js — Generic list-based assertion for spectral rules.
//
// Replaces several rule-specific regex strings with a declarative list +
// mode combination, so rule maintainers can edit a yaml list instead of
// crafting (or proof-reading) alternation regex.
//
// functionOptions:
//   list:    string[]            target list (required)
//   mode:    string              one of:
//     "forbidden"          value equals any list item → violation (blacklist)
//     "forbidden-segment"  value split by "/" has any segment in list → violation
//     "required-prefix"    value must start with one of list items
//     "required-suffix"    value must end with one of list items
//     "required-substring" value must contain one of list items
//   message: string              custom violation message (optional)
//
// Returns spectral-compatible array of {message} when the rule is violated;
// returns undefined (no array) when the input passes the check.

export default function octoListCheck(input, opts) {
  if (typeof input !== 'string') return;
  const { list = [], mode, message } = opts || {};
  if (!Array.isArray(list) || list.length === 0 || !mode) return;

  const checks = {
    'forbidden':          () => list.includes(input),
    'forbidden-segment':  () => input.split('/').filter(Boolean).some((s) => list.includes(s)),
    'required-prefix':    () => !list.some((p) => input.startsWith(p)),
    'required-suffix':    () => !list.some((s) => input.endsWith(s)),
    'required-substring': () => !list.some((t) => input.includes(t)),
  };

  const check = checks[mode];
  if (!check) return;

  if (check()) {
    return [{
      message: message || `value "${input}" violates ${mode} list rule`,
    }];
  }
}
