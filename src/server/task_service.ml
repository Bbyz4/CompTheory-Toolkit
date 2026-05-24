let ( let* ) = Lwt.bind

type deps = {
  repo : Repository.t;
  clock : Clock.t;
  queue : Submission_queue.t;
}

type submission_scope =
  | Mine
  | All

let ok value = Lwt.return (Ok value)

let error value = Lwt.return (Error value)

let map_repo_error = function
  | Repository.Conflict message -> App_error.Conflict message
  | Repository.Not_found message -> App_error.Not_found message
  | Repository.Storage message -> App_error.Internal message

let normalize_optional_string value =
  match value with
  | None -> None
  | Some text ->
      let trimmed = String.trim text in
      if trimmed = "" then None else Some trimmed

let slugify value =
  let buffer = Buffer.create (String.length value) in
  let pending_dash = ref false in
  String.iter
    (fun char ->
      let normalized =
        match char with
        | 'A' .. 'Z' -> Some (Char.lowercase_ascii char)
        | 'a' .. 'z' | '0' .. '9' -> Some char
        | _ -> None
      in
      match normalized with
      | Some safe_char ->
          if !pending_dash && Buffer.length buffer > 0 then Buffer.add_char buffer '-';
          pending_dash := false;
          Buffer.add_char buffer safe_char
      | None -> pending_dash := Buffer.length buffer > 0 || !pending_dash)
    value;
  let result = Buffer.contents buffer in
  if result = "" then None else Some result

let validate_difficulty difficulty =
  if difficulty < 0 || difficulty > 10 then
    Error (App_error.Bad_request "difficulty must be between 0 and 10")
  else
    Ok ()

let validate_title title =
  if String.trim title = "" then
    Error (App_error.Bad_request "title must not be empty")
  else
    Ok ()

let validate_description description =
  if String.trim description = "" then
    Error (App_error.Bad_request "description must not be empty")
  else
    Ok ()

let validate_slug slug =
  let valid_char = function
    | 'a' .. 'z' | '0' .. '9' | '-' -> true
    | _ -> false
  in
  match normalize_optional_string slug with
  | None -> Ok None
  | Some value ->
      if String.for_all valid_char value then
        Ok (Some value)
      else
        Error
          (App_error.Bad_request
             "slug may contain only lowercase letters, digits and hyphens")

let resolve_slug ~title slug =
  match validate_slug slug with
  | Error _ as error -> error
  | Ok (Some slug_value) -> Ok (Some slug_value)
  | Ok None -> Ok (slugify title)

let validate_config ~task_type config =
  match Task_config.validate_task_config ~task_type config with
  | Ok normalized -> Ok normalized
  | Error message -> Error (App_error.Bad_request message)

let validate_submission_data ~task_type ~config data =
  match Task_config.validate_submission_data ~task_type ~config data with
  | Ok normalized -> Ok normalized
  | Error message -> Error (App_error.Bad_request message)

let can_manage_task (context : Auth_service.session_context) (task : Domain.task) =
  context.user.role = Domain.Admin || context.user.id = task.author_id

let can_view_task viewer task =
  match viewer with
  | Some context when can_manage_task context task -> true
  | _ -> (
      match task.status, task.visibility with
      | Domain.Published, (Domain.Public | Domain.Unlisted) -> true
      | _ -> false)

let can_submit_to_task viewer task =
  match viewer with
  | Some context when can_manage_task context task -> true
  | _ -> (
      match task.status, task.visibility with
      | Domain.Published, (Domain.Public | Domain.Unlisted) -> true
      | _ -> false)

let load_task deps task_id =
  let* found = deps.repo.find_task_by_id task_id in
  match found with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok None -> error (App_error.Not_found "Task not found")
  | Ok (Some task) -> ok task

let load_task_by_slug deps slug =
  let* found = deps.repo.find_task_by_slug slug in
  match found with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok None -> error (App_error.Not_found "Task not found")
  | Ok (Some task) -> ok task

let list_public_tasks deps =
  let* listed = deps.repo.list_tasks () in
  match listed with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok tasks ->
      ok
        (List.filter
           (fun (task : Domain.task) ->
             task.status = Domain.Published && task.visibility = Domain.Public)
           tasks)

let list_all_tasks deps =
  let* listed = deps.repo.list_tasks () in
  match listed with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok tasks -> ok tasks

let get_task deps ~viewer ~task_id =
  let* task_result = load_task deps task_id in
  match task_result with
  | Error _ as app_error -> Lwt.return app_error
  | Ok task ->
      if can_view_task viewer task then ok task
      else error (App_error.Not_found "Task not found")

let get_task_by_slug deps ~viewer ~slug =
  let* task_result = load_task_by_slug deps slug in
  match task_result with
  | Error _ as app_error -> Lwt.return app_error
  | Ok task ->
      if can_view_task viewer task then ok task
      else error (App_error.Not_found "Task not found")

let create_task deps ~admin_context ~title ~slug ~short_description ~description
    ~type_ ?author_id ~difficulty ~config ~status ~visibility () =
  match
    ( validate_title title,
      resolve_slug ~title slug,
      validate_description description,
      validate_difficulty difficulty,
      validate_config ~task_type:type_ config )
  with
  | Error app_error, _, _, _, _
  | _, Error app_error, _, _, _
  | _, _, Error app_error, _, _
  | _, _, _, Error app_error, _
  | _, _, _, _, Error app_error ->
      error app_error
  | Ok (), Ok normalized_slug, Ok (), Ok (), Ok normalized_config ->
      let now = deps.clock.now () in
      let published_at =
        match status with Domain.Published -> Some now | _ -> None
      in
      let author_id =
        match author_id with
        | Some value -> value
        | None -> admin_context.Auth_service.user.id
      in
      let* created =
        deps.repo.create_task ~title ~slug:normalized_slug
          ~short_description:(normalize_optional_string short_description)
          ~description ~type_ ~author_id ~difficulty ~config:normalized_config
          ~status ~visibility ~published_at
          ~created_at:now ~updated_at:now
      in
      match created with
      | Ok task -> ok task
      | Error repo_error -> error (map_repo_error repo_error)

let update_task deps ~admin_context:_ ~task_id ~title ~slug ~short_description
    ~description ~type_ ?author_id ~difficulty ~config ~status ~visibility ()
    =
  let* existing_result = load_task deps task_id in
  match existing_result with
  | Error _ as app_error -> Lwt.return app_error
  | Ok existing_task -> (
      let slug_result =
        match slug with
        | Some _ -> validate_slug slug
        | None -> Ok existing_task.slug
      in
      match
        ( validate_title title,
          slug_result,
          validate_description description,
          validate_difficulty difficulty,
          validate_config ~task_type:type_ config )
      with
      | Error app_error, _, _, _, _
      | _, Error app_error, _, _, _
      | _, _, Error app_error, _, _
      | _, _, _, Error app_error, _
      | _, _, _, _, Error app_error ->
          error app_error
      | Ok (), Ok normalized_slug, Ok (), Ok (), Ok normalized_config ->
          let now = deps.clock.now () in
          let published_at =
            match status, existing_task.published_at with
            | Domain.Published, Some value when existing_task.status = Domain.Published ->
                Some value
            | Domain.Published, _ -> Some now
            | _ -> None
          in
          let author_id =
            match author_id with
            | Some value -> value
            | None -> existing_task.author_id
          in
          let* updated =
            deps.repo.update_task ~task_id ~title ~slug:normalized_slug
              ~short_description:(normalize_optional_string short_description)
              ~description ~type_ ~author_id ~difficulty ~config:normalized_config
              ~status ~visibility ~published_at ~updated_at:now
          in
          match updated with
          | Ok (Some task) -> ok task
          | Ok None -> error (App_error.Not_found "Task not found")
          | Error repo_error -> error (map_repo_error repo_error))

let create_submission deps ~(context : Auth_service.session_context) ~task_id
    ~data =
  let* task_result = load_task deps task_id in
  match task_result with
  | Error _ as app_error -> Lwt.return app_error
  | Ok task ->
      if not (can_submit_to_task (Some context) task) then
        error (App_error.Not_found "Task not found")
      else
        begin
          match
            Task_config.validate_task_config ~task_type:task.type_ task.config
          with
          | Error message -> error (App_error.Internal ("Stored task config is invalid: " ^ message))
          | Ok normalized_config -> (
              match
                validate_submission_data ~task_type:task.type_
                  ~config:normalized_config data
              with
              | Error app_error -> error app_error
              | Ok normalized_data ->
                  let now = deps.clock.now () in
                  let* created =
                    deps.repo.create_submission ~task_id:task.id
                      ~user_id:context.user.id ~data:normalized_data
                      ~created_at:now
                  in
                  match created with
                  | Error repo_error -> error (map_repo_error repo_error)
                  | Ok submission -> (
                      let* published =
                        deps.queue.publish_submission
                          ~submission_id:submission.id
                      in
                      match published with
                      | Ok () -> ok submission
                      | Error message -> error (App_error.Internal message)))
        end

let list_submissions deps ~(context : Auth_service.session_context) ~scope =
  match scope with
  | All when context.user.role <> Domain.Admin ->
      error (App_error.Forbidden "Admin privileges required")
  | Mine | All ->
      let listed =
        match scope with
        | Mine -> deps.repo.list_submissions_by_user ~user_id:context.user.id
        | All -> deps.repo.list_submissions ()
      in
      let* result = listed in
      match result with
      | Ok submissions -> ok submissions
      | Error repo_error -> error (map_repo_error repo_error)

let get_submission deps ~(context : Auth_service.session_context) ~submission_id =
  let* found = deps.repo.find_submission_by_id submission_id in
  match found with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok None -> error (App_error.Not_found "Submission not found")
  | Ok (Some submission) ->
      if context.user.role = Domain.Admin || context.user.id = submission.user_id then
        ok submission
      else
        let* task_result = deps.repo.find_task_by_id submission.task_id in
        begin
          match task_result with
          | Error repo_error -> error (map_repo_error repo_error)
          | Ok (Some task) when task.author_id = context.user.id -> ok submission
          | Ok _ -> error (App_error.Forbidden "Cannot access this submission")
        end
