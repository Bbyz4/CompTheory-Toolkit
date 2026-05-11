type state = {
  mutable next_user_id : int;
  mutable next_session_id : int;
  mutable next_verification_id : int;
  mutable next_task_id : int;
  mutable next_submission_id : int;
  users : (int, Domain.user) Hashtbl.t;
  usernames : (string, int) Hashtbl.t;
  emails : (string, int) Hashtbl.t;
  sessions : (int, Domain.session) Hashtbl.t;
  access_index : (string, int) Hashtbl.t;
  refresh_index : (string, int) Hashtbl.t;
  verifications : (int, Domain.email_verification) Hashtbl.t;
  verification_tokens : (string, int) Hashtbl.t;
  tasks : (int, Domain.task) Hashtbl.t;
  task_slugs : (string, int) Hashtbl.t;
  submissions : (int, Domain.submission) Hashtbl.t;
}

let create_state () =
  {
    next_user_id = 1;
    next_session_id = 1;
    next_verification_id = 1;
    next_task_id = 1;
    next_submission_id = 1;
    users = Hashtbl.create 16;
    usernames = Hashtbl.create 16;
    emails = Hashtbl.create 16;
    sessions = Hashtbl.create 32;
    access_index = Hashtbl.create 32;
    refresh_index = Hashtbl.create 32;
    verifications = Hashtbl.create 32;
    verification_tokens = Hashtbl.create 32;
    tasks = Hashtbl.create 32;
    task_slugs = Hashtbl.create 32;
    submissions = Hashtbl.create 64;
  }
