let ( let* ) = Lwt.bind

type command_handler = string -> string Lwt.t

let cleanup_socket socket_path =
  if Sys.file_exists socket_path then Unix.unlink socket_path

let serve ~socket_path ~should_stop ~handle_command =
  cleanup_socket socket_path;
  let server = Lwt_unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Lwt.finalize
    (fun () ->
      let* () = Lwt_unix.bind server (Unix.ADDR_UNIX socket_path) in
      Lwt_unix.listen server 16;
      let rec loop () =
        if should_stop () then
          Lwt.return_unit
        else
          let* client, _ = Lwt_unix.accept server in
          let input = Lwt_io.of_fd ~mode:Lwt_io.Input client in
          let output = Lwt_io.of_fd ~mode:Lwt_io.Output client in
          let* () =
            Lwt.finalize
              (fun () ->
                let* line = Lwt_io.read_line_opt input in
                let* response =
                  match line with
                  | None -> Lwt.return "error no command received"
                  | Some command -> handle_command command
                in
                Lwt_io.write_line output response)
              (fun () -> Lwt_io.close output)
          in
          loop ()
      in
      loop ())
    (fun () ->
      let* () = Lwt_unix.close server in
      cleanup_socket socket_path;
      Lwt.return_unit)

let send_command ~socket_path command =
  let client = Lwt_unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Lwt.finalize
    (fun () ->
      let* () = Lwt_unix.connect client (Unix.ADDR_UNIX socket_path) in
      let input = Lwt_io.of_fd ~mode:Lwt_io.Input client in
      let output = Lwt_io.of_fd ~mode:Lwt_io.Output client in
      let* () = Lwt_io.write_line output command in
      let* response = Lwt_io.read_line input in
      Lwt.return response)
    (fun () -> Lwt_unix.close client)
