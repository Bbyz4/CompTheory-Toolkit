let ( let* ) = Lwt.bind

open Toolkit
open Trafficd_types

let refresh_cached_tasks state =
  let client_id =
    match !(state.users) with
    | user :: _ -> user.actor.client_id
    | [] -> "trafficd-public"
  in
  let* result = Loadtest_api.list_tasks state.client ~client_id () in
  match result with
  | Ok tasks ->
      state.cached_tasks := tasks;
      Lwt.return (Ok tasks)
  | Error _ as error -> Lwt.return error

let perform_list_tasks state =
  let* result = refresh_cached_tasks state in
  match result with
  | Ok _ -> Lwt.return (Ok "list_tasks")
  | Error _ as error -> Lwt.return error

let perform_view_task state =
  match Trafficd_helpers.pick_random !(state.cached_tasks) with
  | None -> Lwt.return (Ok "view_task_skipped_no_tasks")
  | Some task ->
      let client_id =
        match Trafficd_helpers.pick_random !(state.users) with
        | Some user -> user.actor.client_id
        | None -> "trafficd-public"
      in
      let* result =
        Loadtest_api.get_task_by_slug state.client ~client_id task.slug
      in
      begin
        match result with
        | Ok _ -> Lwt.return (Ok "view_task")
        | Error message
          when Trafficd_helpers.has_prefix ~prefix:"HTTP 404" message ->
            state.cached_tasks := [];
            Lwt.return (Ok "view_task_stale_cache")
        | Error _ as error -> Lwt.return error
      end

let perform_login state =
  match Trafficd_helpers.pick_random !(state.users) with
  | None -> Lwt.return (Ok "login_skipped_no_users")
  | Some user ->
      let* logout_result = Trafficd_users.logout_user state user in
      begin
        match logout_result with
        | Error _ as error -> Lwt.return error
        | Ok () ->
            let* login_result = Trafficd_users.login_user state user in
            match login_result with
            | Ok _ -> Lwt.return (Ok "login_relogin")
            | Error _ as error -> Lwt.return error
      end

let perform_submit state =
  match Trafficd_helpers.pick_random !(state.users) with
  | None -> Lwt.return (Ok "submit_skipped_no_users")
  | Some user -> (
      match Trafficd_helpers.pick_random !(state.cached_tasks) with
      | None -> Lwt.return (Ok "submit_skipped_no_tasks")
      | Some task -> (
          match Mock_model.generate_for_task ~task_type:task.type_ ~config:task.config with
          | Error message ->
              prerr_endline
                (Printf.sprintf "trafficd submit generator failed: %s" message);
              Lwt.return (Ok "submit_skipped_unsupported_task")
          | Ok submission_data ->
              let submit_once session =
                Loadtest_api.submit state.client session ~task_id:task.id
                  ~data:submission_data
              in
              let* session_result = Trafficd_users.ensure_live_session state user in
              begin
                match session_result with
                | Error _ as error -> Lwt.return error
                | Ok session ->
                    let* result = submit_once session in
                    begin
                      match result with
                      | Ok _ -> Lwt.return (Ok "submit")
                      | Error message when Trafficd_helpers.is_auth_error message ->
                          user.session <- None;
                          let* relogin_result = Trafficd_users.login_user state user in
                          begin
                            match relogin_result with
                            | Error _ as error -> Lwt.return error
                            | Ok session ->
                                let* retry_result = submit_once session in
                                begin
                                  match retry_result with
                                  | Ok _ -> Lwt.return (Ok "submit_after_relogin")
                                  | Error _ as error -> Lwt.return error
                                end
                          end
                      | Error message
                        when Trafficd_helpers.has_prefix ~prefix:"HTTP 404" message ->
                          state.cached_tasks := [];
                          Lwt.return (Ok "submit_stale_cache")
                      | Error _ as error -> Lwt.return error
                    end
              end))

let add_tasks state requested_count =
  if requested_count < 0 then
    Lwt.return "error add-tasks count must be non-negative"
  else if !(state.users) = [] then
    Lwt.return "error add-tasks requires at least one synthetic user"
  else
    let rec loop created attempts_left =
      if created = requested_count || attempts_left <= 0 then
        Lwt.return (Ok created)
      else
        let index = !(state.next_task_index) in
        state.next_task_index := index + 1;
        let spec = Mock_task.make ~seed:state.seed ~index in
        match Trafficd_users.pick_zipf_user state with
        | None -> Lwt.return (Ok created)
        | Some author -> (
            let* admin_result = Trafficd_users.ensure_admin_session state in
            match admin_result with
            | Error _ as error -> Lwt.return error
            | Ok admin_session ->
                let* result =
                  Loadtest_api.create_task state.client admin_session
                    ~client_id:state.admin_client_id ~author_id:author.actor.user_id
                    ~title:spec.title ~description:spec.description
                    ~difficulty:spec.difficulty ~required_model_type:"NFA" ()
                in
                match result with
                | Ok task ->
                    state.cached_tasks := task :: !(state.cached_tasks);
                    loop (created + 1) (attempts_left - 1)
                | Error message when Trafficd_helpers.is_auth_error message ->
                    state.admin_session := None;
                    loop created (attempts_left - 1)
                | Error message ->
                    prerr_endline
                      (Printf.sprintf "trafficd add-task failed at index=%d: %s"
                         index message);
                    loop created (attempts_left - 1))
    in
    let attempts = max (requested_count * 10) 50 in
    let* result = loop 0 attempts in
    match result with
    | Error message -> Lwt.return ("error " ^ message)
    | Ok created ->
        Lwt.return
          (Printf.sprintf "ok added_tasks %d cached_tasks %d next_task_index %d"
             created (List.length !(state.cached_tasks)) !(state.next_task_index))

let choose_operation state =
  let total = Trafficd_helpers.total_rate state in
  if total <= 0.0 then
    None
  else
    let target = Random.float total in
    let rec loop accumulated = function
      | [] -> None
      | operation :: rest ->
          let next = accumulated +. Trafficd_helpers.current_rate state operation in
          if target < next then Some operation else loop next rest
    in
    loop 0.0 Trafficd_helpers.all_operations

let run_once state =
  match choose_operation state with
  | None -> Lwt.return "idle_no_enabled_operations"
  | Some operation ->
      let* result =
        match operation with
        | List_tasks -> perform_list_tasks state
        | View_task -> perform_view_task state
        | Login -> perform_login state
        | Submit -> perform_submit state
      in
      match result with
      | Ok label -> Lwt.return label
      | Error message ->
          prerr_endline ("trafficd operation failed: " ^ message);
          Lwt.return "error"
