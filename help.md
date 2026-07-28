# Install / Usage errors 

| 🚧 This doc is under construction |
|-|


### Wrong shell
If you see this (part of the output of `fish`)
```
_=" this script must be used with Bash shell
#   (You're using a different shell, it crashed)
#   WIKI: https://simple.wikipedia.org/wiki/Bash
```
Or this (output of `zsh`)
```
ERROR: this script must be used with Bash.
WIKI: https://simple.wikipedia.org/wiki/Bash 
EXITING
```
✅ FIX by using Bash shell

-----

### Command
If you see this
```
ERROR: this script doesn't work with 'bash cdi.sh' or './cdi.sh'.
FIX: use an interactive Bash session, and launch with '. cdi.sh'. 
EXITING
```
✅ FIX by using `. cdi.sh`
