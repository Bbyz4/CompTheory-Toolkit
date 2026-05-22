open Trafficd_types

let all_operations = [ List_tasks; View_task; Login; Submit ]

let operation_name = function
  | List_tasks -> "list_tasks"
  | View_task -> "view_task"
  | Login -> "login"
  | Submit -> "submit"

let operation_of_string = function
  | "list_tasks" | "list-tasks" -> Some List_tasks
  | "view_task" | "view-task" | "open_task" | "open-task" -> Some View_task
  | "login" -> Some Login
  | "submit" -> Some Submit
  | _ -> None

let default_weights =
  [
    (List_tasks, 0.45);
    (View_task, 0.25);
    (Login, 0.15);
    (Submit, 0.15);
  ]

let has_prefix ~prefix value =
  let prefix_len = String.length prefix in
  String.length value >= prefix_len
  && String.sub value 0 prefix_len = prefix

let rate_ref state = function
  | List_tasks -> state.list_tasks_rate
  | View_task -> state.view_task_rate
  | Login -> state.login_rate
  | Submit -> state.submit_rate

let current_rate state operation = !(rate_ref state operation)

let set_rate state operation value = rate_ref state operation := value

let total_rate state =
  List.fold_left
    (fun total operation -> total +. current_rate state operation)
    0.0 all_operations

let rates_summary state =
  all_operations
  |> List.map (fun operation ->
         Printf.sprintf "%s=%.3f" (operation_name operation)
           (current_rate state operation))
  |> String.concat " "

let pick_random list =
  match list with
  | [] -> None
  | _ -> Some (List.nth list (Random.int (List.length list)))

let sample_exponential ~rate =
  if rate <= 0.0 then
    0.5
  else
    let u = max 1e-9 (1.0 -. Random.float 1.0) in
    -.log u /. rate

let is_auth_error message =
  has_prefix ~prefix:"HTTP 401" message || has_prefix ~prefix:"HTTP 403" message

let active_session_count state =
  List.fold_left
    (fun count user -> match user.session with Some _ -> count + 1 | None -> count)
    0 !(state.users)

let status_line state =
  Printf.sprintf
    "ok state %s total_rate %.3f users %d sessions %d cached_tasks %d ops %d \
     next_index %d rates %s"
    (if !(state.running) then "running" else "paused")
    (total_rate state) (List.length !(state.users))
    (active_session_count state) (List.length !(state.cached_tasks))
    !(state.ops_count) !(state.next_index) (rates_summary state)
