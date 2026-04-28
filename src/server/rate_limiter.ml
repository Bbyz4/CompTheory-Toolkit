type rule = { max_requests : int; window_seconds : float }

type bucket = { mutable started_at : float; mutable count : int }

type decision = {
  allowed : bool;
  limit : int;
  remaining : int;
  reset_at : float;
}

type t = {
  clock : Clock.t;
  auth_rule : rule;
  default_rule : rule;
  buckets : (string, bucket) Hashtbl.t;
}

let make ~clock ~auth_rule ~default_rule =
  { clock; auth_rule; default_rule; buckets = Hashtbl.create 128 }

let rule_for_path t path =
  if Util.starts_with ~prefix:"/api/v1/auth/" path then t.auth_rule
  else t.default_rule

let check t ~key ~path =
  let rule = rule_for_path t path in
  let now = t.clock.now () in
  let full_key = key ^ ":" ^ path in
  let bucket =
    match Hashtbl.find_opt t.buckets full_key with
    | Some bucket -> bucket
    | None ->
        let bucket = { started_at = now; count = 0 } in
        Hashtbl.add t.buckets full_key bucket;
        bucket
  in
  if now -. bucket.started_at >= rule.window_seconds then (
    bucket.started_at <- now;
    bucket.count <- 0);
  if bucket.count >= rule.max_requests then
    {
      allowed = false;
      limit = rule.max_requests;
      remaining = 0;
      reset_at = bucket.started_at +. rule.window_seconds;
    }
  else (
    bucket.count <- bucket.count + 1;
    {
      allowed = true;
      limit = rule.max_requests;
      remaining = rule.max_requests - bucket.count;
      reset_at = bucket.started_at +. rule.window_seconds;
    })

