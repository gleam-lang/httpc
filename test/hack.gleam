import gleam/dynamic.{Dynamic}

// TODO: remove this once this is implemented
// https://github.com/gleam-lang/gleam/issues/650
pub type ApplicationName {
  GleamHttpc
  Ssl
  Inets
}

pub external fn ensure_all_started(ApplicationName) -> Result(Dynamic, Dynamic) =
  "application" "ensure_all_started"
