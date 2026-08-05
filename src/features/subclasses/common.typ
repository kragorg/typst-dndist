// - A subclass is a `(kind: "subclass", name, features)` dict.
// - `features` is a function of class level that returns the active sub-features.
// - A sub-feature is a `feature(kind: "subclass-feature")` with the subclass as its `source`.
// - The other feature fields (desc, effects, activation, notes) pass through named.

#import "../../model.typ": feature

#let sub-feature(name, source, ..rest) = feature(
  name, kind: "subclass-feature", source: source, ..rest.named(),
)

#let subclass(name, features) = (
  kind: "subclass", name: name, features: features,
)
