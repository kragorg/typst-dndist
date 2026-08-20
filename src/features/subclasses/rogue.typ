// - Rogue subclasses.
// - `phantom` is a function: Whispers of the Dead grants a chosen proficiency.
// - `assassin` is a plain value: it offers no choice.

#import "../../model.typ": eff-prof, eff-limited-use, id-of
#import "../../data/skills.typ": skill
#import "../../data/tools.typ": tool
#import "common.typ": sub-feature as _sub-feature, subclass as _subclass

// `gained` is the chosen Whispers of the Dead proficiency, as a skill object or an id.
#let phantom(gained: skill.investigation) = _subclass("Phantom", level => {
  let fs = ()
  if level >= 3 {
    // Fall back to the bare id when `gained` is not a catalog skill.
    let gained-name = skill.at(id-of(gained), default: (name: id-of(gained))).name
    fs.push(_sub-feature(
      "Whispers of the Dead", "Phantom",
      effects: (eff-prof("skill", gained),),
      desc: [Whenever you finish a Short or Long Rest, choose one skill or tool proficiency you lack and gain it (currently #gained-name). You lose it when you use this again to choose a different one.],
    ))
    // Wails dice = half the Sneak Attack dice, rounded up.
    let wail-dice = calc.ceil(calc.ceil(level / 2) / 2)
    fs.push(_sub-feature(
      "Wails from the Grave", "Phantom",
      effects: (eff-limited-use("Wails from the Grave", ctx => calc.max(1, ctx.ability-mods.dex), uses-label: "DEX mod", source: "Phantom"),),
      desc: [Up to your Dexterity modifier (min 1) times per Long Rest, immediately after you deal Sneak Attack damage on your turn, deal $#{str(wail-dice)}d 6$ Necrotic damage to a second creature you can see within 30 ft of the first.],
      notes: ctx => {
        let n = calc.max(1, ctx.ability-mods.dex);
        [$+#{str(wail-dice)}d 6$ Necrotic to a 2nd creature within 30 ft of 1st after Sneak Attack (#n/Long Rest).]
      },
    ))
  }
  fs
})

// - Assassinate's extra damage equals the Rogue level, thus `desc` and `notes` read the closure's level.
// - It carries no `activation`: it rides an attack you already make, like Cunning Strike.
#let assassin = _subclass("Assassin", level => {
  let fs = ()
  if level >= 3 {
    fs.push(_sub-feature(
      "Assassinate", "Assassin",
      desc: [You have Advantage on Initiative rolls. During the first round of each combat, you have Advantage on attack rolls against any creature that has not yet taken a turn. If your Sneak Attack hits a target during that round, the target takes extra damage of the weapon's type equal to your Rogue level (#{str(level)}).],
      notes: [Advantage on Initiative. Round 1: Advantage against creatures yet to act; a Sneak Attack hit adds $#{str(level)}$ damage.],
    ))
    fs.push(_sub-feature(
      "Assassin’s Tools", "Assassin",
      effects: (eff-prof("tool", tool.disguise-kit), eff-prof("tool", tool.poisoners-kit)),
      desc: [You gain a Disguise Kit and a Poisoner's Kit, and you have proficiency with them.],
    ))
  }
  fs
})
