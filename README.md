# `cdi` - Change Directory Interactively
A Bash script with interactive TUI - by DavidBevi

![GIF](https://github.com/DavidBevi/cdi/blob/main/cdi-demo.gif?raw=true)

# The two `cdi`s
| Antônio Oliveira | in 2020 | made [`cdi`](https://github.com/antonioolf/cdi) | which is inactive since 2020 |
| - | - | - | - |
| DavidBevi (me) | in 2026 | remade `cdi` | which includes [fix 1](https://github.com/antonioolf/cdi/pull/10) and [fix 2](https://github.com/antonioolf/cdi/pull/12) |

I was hoping to merge the 2 projects, but Antônio kindly said he's not interested [here](https://github.com/antonioolf/cdi/issues/15). Therefore I plan to do my best to maintain my version of `cdi`. Suggestions and contributions are welcome!

<br/>

# Install instructions
❶ download `cdi.sh`, ❷ put in programs dir, ❸ make the `cdi` alias for your shell.

For **Bash** with standard program location (`/usr/local/bin/cdi.sh`) and config file (`~/.bashrc`) this does everything:
```bash
sudo curl "https://raw.githubusercontent.com/DavidBevi/cdi/refs/heads/main/cdi.sh" -o "/usr/local/bin/cdi.sh" && echo -e '\nalias cdi=". /usr/local/bin/cdi.sh"' >> ~/.bashrc && . ~/.bashrc
```

For other **Bash-like shells** it should work the same or similar. **Fish is not compatible**.
