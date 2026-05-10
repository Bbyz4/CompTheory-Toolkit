type t = {
  mode : Runtime_mode.t;
  host : string;
  port : int;
  base_url : string;
  public_web_base_url : string;
  db_url : string;
  schema_path : string;
  openapi_path : string;
  access_token_ttl_seconds : float;
  refresh_token_ttl_seconds : float;
  verification_token_ttl_seconds : float;
  rate_limit_window_seconds : float;
  rate_limit_max_requests : int;
  auth_rate_limit_window_seconds : float;
  auth_rate_limit_max_requests : int;
  smtp_host : string;
  smtp_port : int;
  mail_from : string;
  recognita_admin_username : string option;
  recognita_admin_password : string option;
  rabbitmq_api_base_url : string;
  rabbitmq_user : string;
  rabbitmq_password : string;
  rabbitmq_vhost : string;
  rabbitmq_submission_queue : string;
  submission_worker_poll_interval_seconds : float;
}

let env name = Sys.getenv_opt name

let env_string name ~default = Util.option (env name) ~default

let env_nonempty_string name =
  match env name with
  | Some value ->
      let trimmed = String.trim value in
      if trimmed = "" then None else Some trimmed
  | None -> None

let env_int name ~default =
  match env name with
  | Some value -> (
      match int_of_string_opt value with Some parsed -> parsed | None -> default)
  | None -> default

let env_float name ~default =
  match env name with
  | Some value -> (
      match float_of_string_opt value with Some parsed -> parsed | None -> default)
  | None -> default

let load () =
  let mode = Runtime_mode.load () in
  let host = env_string "APP_HOST" ~default:"0.0.0.0" in
  let port = env_int "APP_PORT" ~default:8080 in
  let base_url =
    env_string "APP_BASE_URL"
      ~default:(Printf.sprintf "http://localhost:%d" port)
  in
  {
    mode;
    host;
    port;
    base_url;
    public_web_base_url =
      env_string "PUBLIC_WEB_BASE_URL" ~default:"http://localhost:8081";
    db_url =
      env_string "DATABASE_URL"
        ~default:"postgresql://toolkit:toolkit@db:5432/toolkit";
    schema_path = env_string "SCHEMA_PATH" ~default:"sql/schema.sql";
    openapi_path = env_string "OPENAPI_PATH" ~default:"openapi/openapi.json";
    access_token_ttl_seconds =
      env_float "ACCESS_TOKEN_TTL_SECONDS" ~default:900.;
    refresh_token_ttl_seconds =
      env_float "REFRESH_TOKEN_TTL_SECONDS" ~default:604800.;
    verification_token_ttl_seconds =
      env_float "VERIFICATION_TOKEN_TTL_SECONDS" ~default:86400.;
    rate_limit_window_seconds =
      env_float "RATE_LIMIT_WINDOW_SECONDS" ~default:60.;
    rate_limit_max_requests = env_int "RATE_LIMIT_MAX_REQUESTS" ~default:120;
    auth_rate_limit_window_seconds =
      env_float "AUTH_RATE_LIMIT_WINDOW_SECONDS" ~default:60.;
    auth_rate_limit_max_requests =
      env_int "AUTH_RATE_LIMIT_MAX_REQUESTS" ~default:20;
    smtp_host = env_string "SMTP_HOST" ~default:"127.0.0.1";
    smtp_port = env_int "SMTP_PORT" ~default:1025;
    mail_from = env_string "MAIL_FROM" ~default:"no-reply@recognita.xyz";
    recognita_admin_username = env_nonempty_string "RECOGNITA_ADMIN_USERNAME";
    recognita_admin_password = env_nonempty_string "RECOGNITA_ADMIN_PASSWORD";
    rabbitmq_api_base_url =
      env_string "RABBITMQ_API_BASE_URL" ~default:"http://rabbitmq:15672";
    rabbitmq_user = env_string "RABBITMQ_USER" ~default:"recognita";
    rabbitmq_password = env_string "RABBITMQ_PASSWORD" ~default:"recognita";
    rabbitmq_vhost = env_string "RABBITMQ_VHOST" ~default:"/";
    rabbitmq_submission_queue =
      env_string "RABBITMQ_SUBMISSION_QUEUE" ~default:"submissions.pending";
    submission_worker_poll_interval_seconds =
      env_float "SUBMISSION_WORKER_POLL_INTERVAL_SECONDS" ~default:1.;
  }
