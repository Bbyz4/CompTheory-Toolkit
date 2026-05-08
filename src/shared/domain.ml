type role =
  | User
  | Admin

type task_type =
  | Model_construction

type task_status =
  | Draft
  | Published
  | Archived

type task_visibility =
  | Private
  | Public
  | Unlisted

type submission_verdict =
  | Pending
  | Accepted
  | Rejected
  | Invalid_format
  | Internal_error

type user = {
  id : int;
  username : string;
  email : string;
  password_hash : string;
  role : role;
  verified : bool;
  is_banned : bool;
  ban_reason : string option;
  created_at : float;
  updated_at : float;
}

type session = {
  id : int;
  user_id : int;
  access_token : string;
  refresh_token : string;
  access_expires_at : float;
  refresh_expires_at : float;
  revoked_at : float option;
  created_at : float;
}

type public_user = {
  id : int;
  username : string;
  email : string;
  role : role;
  verified : bool;
  is_banned : bool;
  ban_reason : string option;
  created_at : float;
  updated_at : float;
}

type email_verification = {
  id : int;
  user_id : int;
  token : string;
  expires_at : float;
  consumed_at : float option;
  created_at : float;
}

type auth_tokens = {
  access_token : string;
  refresh_token : string;
  access_expires_at : float;
  refresh_expires_at : float;
}

type task = {
  id : int;
  title : string;
  slug : string option;
  short_description : string option;
  description : string;
  type_ : task_type;
  author_id : int;
  difficulty : int;
  config : Yojson.Basic.t;
  status : task_status;
  visibility : task_visibility;
  created_at : float;
  updated_at : float;
  published_at : float option;
}

type submission = {
  id : int;
  task_id : int;
  user_id : int;
  data : Yojson.Basic.t;
  verdict : submission_verdict;
  run_data : Yojson.Basic.t option;
  created_at : float;
  judged_at : float option;
}

let role_to_string = function User -> "user" | Admin -> "admin"

let role_to_db_string = function User -> "USER" | Admin -> "ADMIN"

let role_of_string = function
  | "user" | "USER" -> Some User
  | "admin" | "ADMIN" -> Some Admin
  | _ -> None

let task_type_to_string = function
  | Model_construction -> "MODEL_CONSTRUCTION"

let task_type_of_string = function
  | "MODEL_CONSTRUCTION" | "model_construction" -> Some Model_construction
  | _ -> None

let task_status_to_string = function
  | Draft -> "DRAFT"
  | Published -> "PUBLISHED"
  | Archived -> "ARCHIVED"

let task_status_of_string = function
  | "DRAFT" | "draft" -> Some Draft
  | "PUBLISHED" | "published" -> Some Published
  | "ARCHIVED" | "archived" -> Some Archived
  | _ -> None

let task_visibility_to_string = function
  | Private -> "PRIVATE"
  | Public -> "PUBLIC"
  | Unlisted -> "UNLISTED"

let task_visibility_of_string = function
  | "PRIVATE" | "private" -> Some Private
  | "PUBLIC" | "public" -> Some Public
  | "UNLISTED" | "unlisted" -> Some Unlisted
  | _ -> None

let submission_verdict_to_string = function
  | Pending -> "PENDING"
  | Accepted -> "ACCEPTED"
  | Rejected -> "REJECTED"
  | Invalid_format -> "INVALID_FORMAT"
  | Internal_error -> "INTERNAL_ERROR"

let submission_verdict_of_string = function
  | "PENDING" | "pending" -> Some Pending
  | "ACCEPTED" | "accepted" -> Some Accepted
  | "REJECTED" | "rejected" -> Some Rejected
  | "INVALID_FORMAT" | "invalid_format" -> Some Invalid_format
  | "INTERNAL_ERROR" | "internal_error" -> Some Internal_error
  | _ -> None

let public_user_of_user (user : user) : public_user =
  {
    id = user.id;
    username = user.username;
    email = user.email;
    role = user.role;
    verified = user.verified;
    is_banned = user.is_banned;
    ban_reason = user.ban_reason;
    created_at = user.created_at;
    updated_at = user.updated_at;
  }

let auth_tokens_to_yojson (tokens : auth_tokens) =
  `Assoc
    [
      ("access_token", `String tokens.access_token);
      ("refresh_token", `String tokens.refresh_token);
      ("access_expires_at", `String (Util.iso8601_of_unix_time tokens.access_expires_at));
      ( "refresh_expires_at",
        `String (Util.iso8601_of_unix_time tokens.refresh_expires_at) );
    ]

let public_user_to_yojson (user : public_user) =
  `Assoc
    [
      ("id", `Int user.id);
      ("username", `String user.username);
      ("email", `String user.email);
      ("role", `String (role_to_string user.role));
      ("verified", `Bool user.verified);
      ("is_banned", `Bool user.is_banned);
      ( "ban_reason",
        match user.ban_reason with Some reason -> `String reason | None -> `Null );
      ("created_at", `String (Util.iso8601_of_unix_time user.created_at));
      ("updated_at", `String (Util.iso8601_of_unix_time user.updated_at));
    ]

let task_to_yojson (task : task) =
  `Assoc
    [
      ("id", `Int task.id);
      ("title", `String task.title);
      ("slug", match task.slug with Some value -> `String value | None -> `Null);
      ( "short_description",
        match task.short_description with
        | Some value -> `String value
        | None -> `Null );
      ("description", `String task.description);
      ("type", `String (task_type_to_string task.type_));
      ("author_id", `Int task.author_id);
      ("difficulty", `Int task.difficulty);
      ("config", task.config);
      ("status", `String (task_status_to_string task.status));
      ("visibility", `String (task_visibility_to_string task.visibility));
      ("created_at", `String (Util.iso8601_of_unix_time task.created_at));
      ("updated_at", `String (Util.iso8601_of_unix_time task.updated_at));
      ( "published_at",
        match task.published_at with
        | Some value -> `String (Util.iso8601_of_unix_time value)
        | None -> `Null );
    ]

let submission_to_yojson (submission : submission) =
  `Assoc
    [
      ("id", `Int submission.id);
      ("task_id", `Int submission.task_id);
      ("user_id", `Int submission.user_id);
      ("data", submission.data);
      ("verdict", `String (submission_verdict_to_string submission.verdict));
      ( "run_data",
        match submission.run_data with Some value -> value | None -> `Null );
      ( "created_at",
        `String (Util.iso8601_of_unix_time submission.created_at) );
      ( "judged_at",
        match submission.judged_at with
        | Some value -> `String (Util.iso8601_of_unix_time value)
        | None -> `Null );
    ]
