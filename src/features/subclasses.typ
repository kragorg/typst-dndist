// - Each class gets its own module, so a namespace can hold plain values and functions:
//     subclass.bard.glamour
//     subclass.bard.lore(skill.arcana, skill.history, skill.nature)
// - A subclass is an object: a name plus level-gated sub-features.
// - The class folds the subclass into its own nested features.
// - Import aliased: `... as subclass`.

#import "subclasses/bard.typ" as bard
#import "subclasses/cleric.typ" as cleric
#import "subclasses/druid.typ" as druid
#import "subclasses/rogue.typ" as rogue
#import "subclasses/warlock.typ" as warlock
