let ( let* ) = Lwt.bind

let get_rate_response state operation_name_or_none =
  match operation_name_or_none with
  | None ->
      Printf.sprintf "ok total_rate %.3f" (Trafficd_helpers.total_rate state)
  | Some name -> (
      match Trafficd_helpers.operation_of_string name with
      | None -> "error unknown operation"
      | Some operation ->
          Printf.sprintf "ok rate %s %.3f"
            (Trafficd_helpers.operation_name operation)
            (Trafficd_helpers.current_rate state operation))

let get_rates_response state =
  Printf.sprintf "ok total_rate %.3f %s"
    (Trafficd_helpers.total_rate state)
    (Trafficd_helpers.rates_summary state)

let handle_command state command =
  let parts =
    String.split_on_char ' ' (String.trim command)
    |> List.filter (fun part -> part <> "")
  in
  match parts with
  | [] -> Lwt.return "error empty command"
  | [ "status" ] -> Lwt.return (Trafficd_helpers.status_line state)
  | [ "get-rate" ] | [ "rate" ] -> Lwt.return (get_rate_response state None)
  | [ "get-rate"; name ] | [ "rate"; name ] ->
      Lwt.return (get_rate_response state (Some name))
  | [ "get-rates" ] -> Lwt.return (get_rates_response state)
  | [ "set-rate"; name; value ] | [ "rate"; name; value ] -> (
      match Trafficd_helpers.operation_of_string name, float_of_string_opt value with
      | None, _ -> Lwt.return "error unknown operation"
      | _, None -> Lwt.return "error rate must be a float"
      | Some _, Some parsed when parsed < 0.0 ->
          Lwt.return "error rate must be non-negative"
      | Some operation, Some parsed ->
          Trafficd_helpers.set_rate state operation parsed;
          Lwt.return (get_rates_response state))
  | [ "start" ] ->
      state.Trafficd_types.running := true;
      Lwt.return (Trafficd_helpers.status_line state)
  | [ "pause" ] ->
      state.Trafficd_types.running := false;
      Lwt.return (Trafficd_helpers.status_line state)
  | [ "add-users"; value ] -> (
      match int_of_string_opt value with
      | None -> Lwt.return "error add-users count must be an integer"
      | Some count -> Trafficd_users.add_users state count)
  | [ "add-tasks"; value ] -> (
      match int_of_string_opt value with
      | None -> Lwt.return "error add-tasks count must be an integer"
      | Some count -> Trafficd_tasks.add_tasks state count)
  | [ "remove-users"; value ] -> (
      match int_of_string_opt value with
      | None -> Lwt.return "error remove-users count must be an integer"
      | Some count -> Trafficd_users.remove_users state count)
  | [ "stop" ] ->
      state.Trafficd_types.stop_requested := true;
      Lwt.return "ok stopping"
  | _ -> Lwt.return "error unknown command"
