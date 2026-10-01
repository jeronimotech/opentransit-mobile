# Release notes, one file per Play locale

`tool/play.sh` passes this directory to `tool/play_publish.py --notes-from`, which sends one
`releaseNotes` entry per `<locale>.txt`. **Play rejects a commit that has no notes for a language the
listing is published in**, so a new store language needs a file here in the same change.

Play caps each at 500 characters and the uploader truncates rather than failing, so keep them short.
Locales must be Play's own codes (`es-419`, `en-US`, `pt-PT`, `fr-FR`, `it-IT`, `ms-MY`, `ar`) and
match the filename exactly.

Rewrite these for every release. The text here is whatever shipped last; leaving it unchanged
publishes a new build describing the previous one. The long-form listing copy these were drawn from
is in `../../STORE-LISTING.md`.
