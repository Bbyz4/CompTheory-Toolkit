Ten devcontainer nie podnosi lokalnego stacka aplikacji automatycznie.
Ma tylko środowisko robocze z dostępem do hostowego Dockera przez
`/var/run/docker.sock`, tak aby z terminala w VS Code działało:

```sh
./scripts/local_deploy.sh up
source ./.local-deploy/state/.recognitarc
recognita_compose ps
```

To celowo unika konfliktów portów z `local_deploy`, który sam uruchamia
`db`, `rabbitmq`, `mailpit`, `app`, `worker`, `web`, `trafficd` i `nginx`.
