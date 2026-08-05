// - The DSL accepts an ability object, e.g. `ability.cha`, wherever an ability is named.
// - `ability-ids` keeps the canonical order.

#let ability = (
  str: (kind: "ability", id: "str", abbr: "STR", name: "Strength"),
  dex: (kind: "ability", id: "dex", abbr: "DEX", name: "Dexterity"),
  con: (kind: "ability", id: "con", abbr: "CON", name: "Constitution"),
  int: (kind: "ability", id: "int", abbr: "INT", name: "Intelligence"),
  wis: (kind: "ability", id: "wis", abbr: "WIS", name: "Wisdom"),
  cha: (kind: "ability", id: "cha", abbr: "CHA", name: "Charisma"),
)

#let ability-list = ability.values()
#let ability-ids = ability.keys()
#let ability-names = {
  let d = (:)
  for a in ability-list { d.insert(a.id, a.name) }
  d
}
