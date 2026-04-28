type t = { now : unit -> float }

let system = { now = Unix.gettimeofday }

let make now = { now }

