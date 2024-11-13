# CHANGELOG

## 1.0.6

Add and prefer `:repo` option. This simplifies setup for anyone using Ecto.

## 1.0.5

Update dependencies to allow postgrex 0.19.x.

## 1.0.4

Update dependencies to allow postgrex 0.18.x.

## 1.0.3

Fixed a bug that caused Postgres VACUUM to fail to clean up dead rows while HighlanderPG was waiting for a lock.

When a child process returns `{:error, reason}` on start, log the error and shut down HighlanderPG. Previously the error was formatted in a way that made it hard to read.

## 1.0.2

Minor fix to documentation.

## 1.0.1

Set `type: :supervisor` on HighlanderPG's child spec so that it gets a shutdown timeout of `:infinity`, like other supervisors.

## 1.0.0

Initial release.
