let random_bytes count =
  let channel = open_in_bin "/dev/urandom" in
  Fun.protect
    ~finally:(fun () -> close_in_noerr channel)
    (fun () -> really_input_string channel count)

let generate ?(bytes = 32) () = Util.hex_of_string (random_bytes bytes)

