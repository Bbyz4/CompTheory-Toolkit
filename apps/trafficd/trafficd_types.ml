open Toolkit

type synthetic_user = {
  actor : Loadtest_api.actor;
  mutable session : Loadtest_api.session option;
}

type operation =
  | List_tasks
  | View_task
  | Login
  | Submit

type state = {
  client : Loadtest_api.client;
  seed : int;
  report_every : int;
  admin_username : string option;
  admin_password : string option;
  admin_client_id : string;
  admin_session : Loadtest_api.session option ref;
  running : bool ref;
  stop_requested : bool ref;
  next_index : int ref;
  next_task_index : int ref;
  users : synthetic_user list ref;
  cached_tasks : Loadtest_api.task list ref;
  ops_count : int ref;
  list_tasks_rate : float ref;
  view_task_rate : float ref;
  login_rate : float ref;
  submit_rate : float ref;
}
