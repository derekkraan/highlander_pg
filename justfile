default: test

test:
  watchexec -r --clear=reset --project-origin=. --stop-timeout=0 MIX_ENV=test mix do compile --warnings-as-errors, test

doc:
  watchexec -r --clear=reset --project-origin=. --stop-timeout=0 mix docs

docker:
  docker-compose up -d
