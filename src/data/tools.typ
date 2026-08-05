// Features grant proficiency with the tool object, e.g. `tool.musical-instrument`.

#import "constants.typ": artisans-tools, other-tools

// - Make a kebab id from a display name.
// - Drop each apostrophe: "Calligrapher’s Supplies" gives "calligraphers-supplies".
// - Replace each run of other non-alphanumeric characters with one hyphen.
// - Remove the leading and trailing hyphens.
// - Do not show an id to the user: get the name from the `tool` catalog, which keeps
//   the apostrophe.
#let _id(name) = lower(name).replace(regex("['’]"), "").replace(regex("[^a-z0-9]+"), "-").trim("-")
#let _mk(name, category) = (kind: "tool", id: _id(name), name: name, category: category)

#let tool = {
  let d = (:)
  for n in artisans-tools { d.insert(_id(n), _mk(n, "artisan")) }
  for n in other-tools { d.insert(_id(n), _mk(n, "other")) }
  d
}

#let tool-list = tool.values()
