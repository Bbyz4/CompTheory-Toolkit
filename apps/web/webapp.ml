let () =
  let config = Toolkit.Web_config.load () in
  Dream.run ~interface:config.host ~port:config.port
  @@ Dream.logger
  @@ Toolkit.Web_app.make config
