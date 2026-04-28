type role =
  | User
  | Admin

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

let role_to_string = function User -> "user" | Admin -> "admin"

let role_of_string = function
  | "user" -> Some User
  | "admin" -> Some Admin
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
