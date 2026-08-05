// - Features grant proficiency with the skill object, e.g. `skill.acrobatics`.
// - `skill-list` keeps the canonical sheet order.

#let skill = (
  acrobatics: (kind: "skill", id: "acrobatics", name: "Acrobatics", ability: "dex"),
  animal-handling: (kind: "skill", id: "animal-handling", name: "Animal Handling", ability: "wis"),
  arcana: (kind: "skill", id: "arcana", name: "Arcana", ability: "int"),
  athletics: (kind: "skill", id: "athletics", name: "Athletics", ability: "str"),
  deception: (kind: "skill", id: "deception", name: "Deception", ability: "cha"),
  history: (kind: "skill", id: "history", name: "History", ability: "int"),
  insight: (kind: "skill", id: "insight", name: "Insight", ability: "wis"),
  intimidation: (kind: "skill", id: "intimidation", name: "Intimidation", ability: "cha"),
  investigation: (kind: "skill", id: "investigation", name: "Investigation", ability: "int"),
  medicine: (kind: "skill", id: "medicine", name: "Medicine", ability: "wis"),
  nature: (kind: "skill", id: "nature", name: "Nature", ability: "int"),
  perception: (kind: "skill", id: "perception", name: "Perception", ability: "wis"),
  performance: (kind: "skill", id: "performance", name: "Performance", ability: "cha"),
  persuasion: (kind: "skill", id: "persuasion", name: "Persuasion", ability: "cha"),
  religion: (kind: "skill", id: "religion", name: "Religion", ability: "int"),
  sleight-of-hand: (kind: "skill", id: "sleight-of-hand", name: "Sleight of Hand", ability: "dex"),
  stealth: (kind: "skill", id: "stealth", name: "Stealth", ability: "dex"),
  survival: (kind: "skill", id: "survival", name: "Survival", ability: "wis"),
)

#let skill-list = skill.values()
#let skill-ids = skill.keys()
