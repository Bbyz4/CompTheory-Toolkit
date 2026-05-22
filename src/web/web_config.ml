type t = {
  mode : Runtime_mode.t;
  host : string;
  port : int;
  api_base_url : string;
  site_name : string;
  access_code : string;
  access_cookie_secret : string;
}

let env name = Sys.getenv_opt name

let env_string name ~default = match env name with Some value -> value | None -> default

let env_int name ~default =
  match env name with
  | Some value -> (
      match int_of_string_opt value with Some parsed -> parsed | None -> default)
  | None -> default

let load () =
  {
    mode = Runtime_mode.load ();
    host = env_string "WEB_HOST" ~default:"0.0.0.0";
    port = env_int "WEB_PORT" ~default:8081;
    api_base_url =
      env_string "API_BASE_URL" ~default:"http://localhost:8080";
    site_name = env_string "SITE_NAME" ~default:"Recognita";
    access_code = env_string "ACCESS_GATE_CODE" ~default:"pezarski";
    access_cookie_secret =
      env_string "ACCESS_GATE_COOKIE_SECRET"
        ~default:"recognita-gate-cookie-secret-v1";
  }
