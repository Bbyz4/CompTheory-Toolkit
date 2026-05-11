let create_task (state : In_memory_repo_state.state) ~title ~slug ~short_description ~description ~type_
    ~author_id ~difficulty ~config ~status ~visibility ~published_at
    ~created_at ~updated_at =
  match slug with
  | Some value when Hashtbl.mem state.In_memory_repo_state.task_slugs value ->
      Lwt.return (Error (Repository.Conflict "Task slug already exists"))
  | _ ->
      let task =
        {
          Domain.id = state.next_task_id;
          title;
          slug;
          short_description;
          description;
          type_;
          author_id;
          difficulty;
          config;
          status;
          visibility;
          created_at;
          updated_at;
          published_at;
        }
      in
      state.next_task_id <- state.next_task_id + 1;
      Hashtbl.replace state.tasks task.id task;
      begin
        match slug with
        | Some value -> Hashtbl.replace state.task_slugs value task.id
        | None -> ()
      end;
      Lwt.return (Ok task)

let list_tasks (state : In_memory_repo_state.state) () =
  Lwt.return (Ok (In_memory_repo_support.sorted_tasks state))

let find_task_by_id (state : In_memory_repo_state.state) task_id =
  Lwt.return (Ok (In_memory_repo_support.task_by_id state task_id))

let find_task_by_slug (state : In_memory_repo_state.state) slug =
  match Hashtbl.find_opt state.In_memory_repo_state.task_slugs slug with
  | None -> Lwt.return (Ok None)
  | Some task_id ->
      Lwt.return (Ok (In_memory_repo_support.task_by_id state task_id))

let create_submission (state : In_memory_repo_state.state) ~task_id ~user_id ~data ~created_at =
  let submission =
    {
      Domain.id = state.next_submission_id;
      task_id;
      user_id;
      data;
      verdict = Domain.Pending;
      run_data = None;
      created_at;
      judged_at = None;
    }
  in
  state.next_submission_id <- state.next_submission_id + 1;
  Hashtbl.replace state.submissions submission.id submission;
  Lwt.return (Ok submission)

let list_submissions (state : In_memory_repo_state.state) () =
  Lwt.return (Ok (In_memory_repo_support.sorted_submissions state))

let list_submissions_by_user (state : In_memory_repo_state.state) ~user_id =
  let filtered_rows =
    In_memory_repo_support.sorted_submissions state
    |> List.filter
         (fun (submission : Domain.submission) ->
           submission.user_id = user_id)
  in
  Lwt.return (Ok filtered_rows)

let find_submission_by_id (state : In_memory_repo_state.state) submission_id =
  Lwt.return (Ok (In_memory_repo_support.submission_by_id state submission_id))

let update_submission_result (state : In_memory_repo_state.state) ~submission_id
    ~verdict ~run_data ~judged_at =
  match In_memory_repo_support.submission_by_id state submission_id with
  | None -> Lwt.return (Ok None)
  | Some submission ->
      let next_submission =
        { submission with verdict; run_data; judged_at = Some judged_at }
      in
      Hashtbl.replace state.submissions submission_id next_submission;
      Lwt.return (Ok (Some next_submission))
