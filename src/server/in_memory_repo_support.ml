type state = In_memory_repo_state.state

let user_by_id state id = Hashtbl.find_opt state.In_memory_repo_state.users id

let session_by_id state id =
  Hashtbl.find_opt state.In_memory_repo_state.sessions id

let verification_by_id state id =
  Hashtbl.find_opt state.In_memory_repo_state.verifications id

let task_by_id state id = Hashtbl.find_opt state.In_memory_repo_state.tasks id

let submission_by_id state id =
  Hashtbl.find_opt state.In_memory_repo_state.submissions id

let sorted_public_users state =
  let user_rows : Domain.user list =
    Hashtbl.to_seq_values state.In_memory_repo_state.users |> List.of_seq
  in
  user_rows
  |> List.sort
       (fun (left : Domain.user) (right : Domain.user) ->
         Int.compare left.Domain.id right.Domain.id)
  |> List.map (fun (user : Domain.user) -> Domain.public_user_of_user user)

let sorted_tasks state =
  let rows : Domain.task list =
    Hashtbl.to_seq_values state.In_memory_repo_state.tasks |> List.of_seq
  in
  List.sort
    (fun (left : Domain.task) (right : Domain.task) ->
      Int.compare right.id left.id)
    rows

let sorted_submissions state =
  let rows : Domain.submission list =
    Hashtbl.to_seq_values state.In_memory_repo_state.submissions |> List.of_seq
  in
  List.sort
    (fun (left : Domain.submission) (right : Domain.submission) ->
      Int.compare right.id left.id)
    rows
