let make () =
  let state = In_memory_repo_state.create_state () in
  {
    Repository.init_schema = (fun () -> Lwt.return (Ok ()));
    find_user_by_username = In_memory_repo_users.find_user_by_username state;
    find_user_by_email = In_memory_repo_users.find_user_by_email state;
    find_user_by_id = In_memory_repo_users.find_user_by_id state;
    create_user = In_memory_repo_users.create_user state;
    list_users = In_memory_repo_users.list_users state;
    update_role = In_memory_repo_users.update_role state;
    update_bootstrap_admin = In_memory_repo_users.update_bootstrap_admin state;
    update_ban = In_memory_repo_users.update_ban state;
    create_session = In_memory_repo_users.create_session state;
    find_session_by_access_token =
      In_memory_repo_users.find_session_by_access_token state;
    find_session_by_refresh_token =
      In_memory_repo_users.find_session_by_refresh_token state;
    revoke_session = In_memory_repo_users.revoke_session state;
    revoke_user_sessions = In_memory_repo_users.revoke_user_sessions state;
    create_email_verification =
      In_memory_repo_users.create_email_verification state;
    find_email_verification_by_token =
      In_memory_repo_users.find_email_verification_by_token state;
    consume_email_verification =
      In_memory_repo_users.consume_email_verification state;
    mark_user_verified = In_memory_repo_users.mark_user_verified state;
    delete_user = In_memory_repo_users.delete_user state;
    create_task = In_memory_repo_tasks.create_task state;
    update_task = In_memory_repo_tasks.update_task state;
    list_tasks = In_memory_repo_tasks.list_tasks state;
    find_task_by_id = In_memory_repo_tasks.find_task_by_id state;
    find_task_by_slug = In_memory_repo_tasks.find_task_by_slug state;
    create_submission = In_memory_repo_tasks.create_submission state;
    list_submissions = In_memory_repo_tasks.list_submissions state;
    list_submissions_by_user = In_memory_repo_tasks.list_submissions_by_user state;
    find_submission_by_id = In_memory_repo_tasks.find_submission_by_id state;
    update_submission_result =
      In_memory_repo_tasks.update_submission_result state;
  }
