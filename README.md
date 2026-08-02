# `cdi` - Change Directory Interactively
**A Bash script with interactive TUI - by DavidBevi** (not [Antônio Oliveira's **`cdi`**](https://github.com/antonioolf/cdi))

![GIF](https://github.com/DavidBevi/cdi/blob/main/cdi_2.0_demo.gif?raw=true)

# How to use

### Install
❶ download `cdi.sh`, ❷ put in `/usr/local/bin/`, ❸ make the `cdi` alias. Here's a command that does all 3 steps:
```bash
sudo curl "https://raw.githubusercontent.com/DavidBevi/cdi/refs/heads/main/cdi.sh" -o "/usr/local/bin/cdi.sh" && echo -e '\nalias cdi=". /usr/local/bin/cdi.sh"' >> ~/.bashrc && . ~/.bashrc
```

### Use
Run `cdi` with command `cdi`.

> **Details:** `cdi` must be _sourced_, that is `source cdi.sh` or `. cdi.sh`.<br/>
With `./cdi.sh` or `bash cdi.sh` a _sub-shell_ is created, and `cdi` will `cd` _the sub-shell_ and exit.<br/>
To save you an headache `cdi` only works when sourced, and prints an helpful text otherwise.

<br/>

# Help

### What's a shell?
Shells are programs that accepts textual commands, Bash is the most famous and popular Linux shell. Usually you might also call it "terminal", but the "terminal emulator" is the program that **_displays_** the input and output of the shell. You can change shell without changing terminal (or the opposite).

### Check your shell
Run `ps -p $$ -o comm=`, if it doesn't print back `bash` you're not on Bash. But usually you can still enter Bash by running `bash`.

### Temporarily change shell
Run `bash` and work there: this command calls a sub-shell, from which you can do your normal stuff. You can return to the caller-shell with `exit` and usually with **`ctrl`+`d`**.

### Permanently change shell
Run `chsh -s /usr/bin/bash` and type the superuser password (the one you type for `sudo`).

<br/>

# Acknowledgement
Antônio Oliveira in 2020 made [`cdi`](https://github.com/antonioolf/cdi), which is inactive since then. My `cdi` is a complete rewrite, done because I wanted learn Bash scripting by building a script myself.

After doing so I was hoping to merge the 2 projects somehow, but Antônio kindly [declined](https://github.com/antonioolf/cdi/issues/15), so I'll do my best to maintain this `cdi`.

<br/>
