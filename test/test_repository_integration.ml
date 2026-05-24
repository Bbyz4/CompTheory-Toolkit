open Test_support

let test_caqti_repo_user_roundtrip () =
  with_postgres_repo (fun repo clock ->
      let now = clock.now () in
      let created_user =
        repo.create_user ~username:"db_zoe" ~email:"db_zoe@example.com"
          ~password_hash:(Toolkit.Password.make "password123")
          ~role:Toolkit.Domain.User ~created_at:now
      in
      let created_user = Lwt.map unwrap_repo_ok created_user in
      let* created_user = created_user in
      let* found_by_username = repo.find_user_by_username "db_zoe" in
      let found_by_username = unwrap_repo_ok found_by_username in
      let* found_by_email = repo.find_user_by_email "db_zoe@example.com" in
      let found_by_email = unwrap_repo_ok found_by_email in
      let* created_session =
        repo.create_session ~user_id:created_user.id ~access_token:"db-access"
          ~refresh_token:"db-refresh" ~access_expires_at:(now +. 300.)
          ~refresh_expires_at:(now +. 600.) ~created_at:now
      in
      let created_session = unwrap_repo_ok created_session in
      let* found_session = repo.find_session_by_access_token "db-access" in
      let found_session = unwrap_repo_ok found_session in
      assert_true
        (Option.map
           (fun (user : Toolkit.Domain.user) -> user.id)
           found_by_username
        = Some created_user.id)
        "Caqti repo should find the created user by username";
      assert_true
        (Option.map
           (fun (user : Toolkit.Domain.user) -> user.id)
           found_by_email
        = Some created_user.id)
        "Caqti repo should find the created user by email";
      assert_true
        (Option.map
           (fun (session : Toolkit.Domain.session) -> session.id)
           found_session
        = Some created_session.id)
        "Caqti repo should find the created session by access token";
      Lwt.return_unit)

let test_caqti_repo_task_and_submission_roundtrip () =
  with_postgres_repo (fun repo clock ->
      let now = clock.now () in
      let* author =
        repo.create_user ~username:"db_author"
          ~email:"db_author@example.com"
          ~password_hash:(Toolkit.Password.make "password123")
          ~role:Toolkit.Domain.Admin ~created_at:now
      in
      let author = unwrap_repo_ok author in
      let* submitter =
        repo.create_user ~username:"db_submitter"
          ~email:"db_submitter@example.com"
          ~password_hash:(Toolkit.Password.make "password123")
          ~role:Toolkit.Domain.User ~created_at:(now +. 1.)
      in
      let submitter = unwrap_repo_ok submitter in
      let* task =
        repo.create_task ~title:"Database task" ~slug:(Some "database-task")
          ~short_description:(Some "Short description")
          ~description:"Task body"
          ~type_:Toolkit.Domain.Model_construction ~author_id:author.id
          ~difficulty:4 ~config:(model_construction_config ())
          ~status:Toolkit.Domain.Published ~visibility:Toolkit.Domain.Public
          ~published_at:(Some now)
          ~created_at:now ~updated_at:now
      in
      let task = unwrap_repo_ok task in
      let* found_task = repo.find_task_by_slug "database-task" in
      let found_task = unwrap_repo_ok found_task in
      let* listed_tasks = repo.list_tasks () in
      let listed_tasks = unwrap_repo_ok listed_tasks in
      let* updated_task =
        repo.update_task ~task_id:task.id ~title:"Database task updated"
          ~slug:(Some "database-task-updated")
          ~short_description:(Some "Updated short description")
          ~description:"Updated task body"
          ~type_:Toolkit.Domain.Model_construction ~author_id:author.id
          ~difficulty:5
          ~config:
            (model_construction_config
               ~grader:
                 (`Assoc
                   [
                     ("kind", `String "explicit-tests");
                     ("tests", `List [ `String "ab"; `String "ba" ]);
                   ])
               ())
          ~status:Toolkit.Domain.Draft ~visibility:Toolkit.Domain.Private
          ~published_at:None ~updated_at:(now +. 0.5)
      in
      let updated_task = unwrap_repo_ok updated_task in
      let* submission =
        repo.create_submission ~task_id:task.id ~user_id:submitter.id
          ~data:(valid_nfa_submission_data ())
          ~created_at:(now +. 2.)
      in
      let submission = unwrap_repo_ok submission in
      let* listed_submissions = repo.list_submissions_by_user ~user_id:submitter.id in
      let listed_submissions = unwrap_repo_ok listed_submissions in
      let* updated_submission =
        repo.update_submission_result ~submission_id:submission.id
          ~verdict:Toolkit.Domain.Accepted
          ~run_data:
            (Some (`Assoc [ ("score", `Int 100); ("worker", `String "test") ]))
          ~judged_at:(now +. 3.)
      in
      let updated_submission = unwrap_repo_ok updated_submission in
      assert_true
        (Option.map
           (fun (current : Toolkit.Domain.task) -> current.id)
           found_task
        = Some task.id)
        "Caqti repo should find the created task by slug";
      assert_true
        (List.exists
           (fun (current : Toolkit.Domain.task) -> current.id = task.id)
           listed_tasks)
        "Caqti repo should list the created task";
      begin
        match updated_task with
        | Some current ->
            assert_true
              (current.slug = Some "database-task-updated")
              "Caqti repo should update the task slug";
            assert_true
              (current.status = Toolkit.Domain.Draft)
              "Caqti repo should update the task status"
        | None -> fail "Expected updated task to be returned"
      end;
      assert_true
        (List.exists
           (fun (current : Toolkit.Domain.submission) -> current.id = submission.id)
           listed_submissions)
        "Caqti repo should list the created submission for the user";
      begin
        match updated_submission with
        | Some current ->
            assert_true
              (current.verdict = Toolkit.Domain.Accepted)
              "Caqti repo should update the submission verdict";
            assert_true
              (current.judged_at <> None)
              "Caqti repo should set judged_at on updated submissions"
        | None -> fail "Expected updated submission to be returned"
      end;
      Lwt.return_unit)

let test_caqti_repo_delete_user_cascades () =
  with_postgres_repo (fun repo clock ->
      let now = clock.now () in
      let* author =
        repo.create_user ~username:"db_cascade_author"
          ~email:"db_cascade_author@example.com"
          ~password_hash:(Toolkit.Password.make "password123")
          ~role:Toolkit.Domain.Admin ~created_at:now
      in
      let author = unwrap_repo_ok author in
      let* submitter =
        repo.create_user ~username:"db_cascade_submitter"
          ~email:"db_cascade_submitter@example.com"
          ~password_hash:(Toolkit.Password.make "password123")
          ~role:Toolkit.Domain.User ~created_at:(now +. 1.)
      in
      let submitter = unwrap_repo_ok submitter in
      let* task =
        repo.create_task ~title:"Cascade task" ~slug:(Some "cascade-task")
          ~short_description:None ~description:"Cascade task body"
          ~type_:Toolkit.Domain.Model_construction ~author_id:author.id
          ~difficulty:2
          ~config:(model_construction_config ())
          ~status:Toolkit.Domain.Published ~visibility:Toolkit.Domain.Public
          ~published_at:(Some now) ~created_at:now ~updated_at:now
      in
      let task = unwrap_repo_ok task in
      let* submission =
        repo.create_submission ~task_id:task.id ~user_id:submitter.id
          ~data:(valid_nfa_submission_data ()) ~created_at:(now +. 2.)
      in
      let submission = unwrap_repo_ok submission in
      let* deleted_user = repo.delete_user ~user_id:author.id in
      let deleted_user = unwrap_repo_ok deleted_user in
      let* found_task = repo.find_task_by_id task.id in
      let found_task = unwrap_repo_ok found_task in
      let* found_submission = repo.find_submission_by_id submission.id in
      let found_submission = unwrap_repo_ok found_submission in
      assert_true
        (Option.map
           (fun (user : Toolkit.Domain.user) -> user.id)
           deleted_user
        = Some author.id)
        "Caqti repo should return the deleted author";
      assert_true
        (found_task = None)
        "Deleting the task author should cascade-delete owned tasks";
      assert_true
        (found_submission = None)
        "Deleting the task author should cascade-delete submissions under owned tasks";
      Lwt.return_unit)

let tests : test_case list =
  [
    ("caqti_repo_user_roundtrip", test_caqti_repo_user_roundtrip);
    ( "caqti_repo_task_and_submission_roundtrip",
      test_caqti_repo_task_and_submission_roundtrip );
    ("caqti_repo_delete_user_cascades", test_caqti_repo_delete_user_cascades);
  ]
