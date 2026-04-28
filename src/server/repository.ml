type error =
  | Conflict of string
  | Not_found of string
  | Storage of string

type t = {
  init_schema : unit -> (unit, error) result Lwt.t;
  find_user_by_username : string -> (Domain.user option, error) result Lwt.t;
  find_user_by_email : string -> (Domain.user option, error) result Lwt.t;
  find_user_by_id : int -> (Domain.user option, error) result Lwt.t;
  create_user :
    username:string ->
    email:string ->
    password_hash:string ->
    role:Domain.role ->
    created_at:float ->
    (Domain.user, error) result Lwt.t;
  upsert_admin :
    username:string ->
    email:string ->
    password_hash:string ->
    updated_at:float ->
    (Domain.user, error) result Lwt.t;
  list_users : unit -> (Domain.public_user list, error) result Lwt.t;
  update_ban :
    user_id:int ->
    is_banned:bool ->
    ban_reason:string option ->
    updated_at:float ->
    (Domain.user option, error) result Lwt.t;
  create_session :
    user_id:int ->
    access_token:string ->
    refresh_token:string ->
    access_expires_at:float ->
    refresh_expires_at:float ->
    created_at:float ->
    (Domain.session, error) result Lwt.t;
  find_session_by_access_token :
    string -> (Domain.session option, error) result Lwt.t;
  find_session_by_refresh_token :
    string -> (Domain.session option, error) result Lwt.t;
  revoke_session :
    session_id:int -> revoked_at:float -> (unit, error) result Lwt.t;
  revoke_user_sessions :
    user_id:int -> revoked_at:float -> (unit, error) result Lwt.t;
  create_email_verification :
    user_id:int ->
    token:string ->
    expires_at:float ->
    created_at:float ->
    (Domain.email_verification, error) result Lwt.t;
  find_email_verification_by_token :
    string -> (Domain.email_verification option, error) result Lwt.t;
  consume_email_verification :
    verification_id:int -> consumed_at:float -> (unit, error) result Lwt.t;
  mark_user_verified :
    user_id:int -> updated_at:float -> (Domain.user option, error) result Lwt.t;
}

let error_message = function
  | Conflict value | Not_found value | Storage value -> value
