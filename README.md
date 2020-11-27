# fzmail

fzmail is a terminal based mail client. It allows you to work on your mails
(create mails, reply, forward, etc.) which are saved in maildir format.
As front end or gui fzmail use fzf so you can fuzzy search world. Emails can
be displayed in your favorite text editor or browser.

To use fzmail copy the shell script some, set relevant enviroment variables
and execute the script.

## Status

THIS IS EARLY ALPHA!!!
BREAKING CHANGES ARE LIKELY TO HAPPEND!!!

## Requirements

### Software

- [fzf (as gui)](https://github.com/junegunn/fzf)
- [msmtp (send mail alternative)](https://marlam.de/msmtp/)
- [mblaze (handling mail in maildir format)](https://github.com/leahneukirchen/mblaze)
- general gnu tools


### Files

#### mail-profiles

Pipe seperated mail profiles. One line per profile. Located in `$HOME/.config/mail-profiles`.

```
$HOME/.config/mail-profiles
mail@domain.tld|My Name <mail@domain.tld>|AbsolutePathToDraftFolder|AbsolutePathToSendFolder
```

#### MAILDIR

Enviorment Variable containing path to top maildir which you want to work with
fzmail.

## Optional

Get your mails in maildir format via [isync](https://isync.sourceforge.io/).

## Licence
MIT
