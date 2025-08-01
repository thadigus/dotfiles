# dotfiles

This is a typical dotfiles folder for the various configurations that I do in my installations. This will include almost any special configs or ricing I do in any Linux installs but it will mainly focus on my Arch installs which utilize Hyprland, Kitty, Tmux, Zsh, and Neovim. All packages are managed with GNU Stow, so be sure to have this installed.

## Ansible Pull

I've created an Ansible Pull playbook to deploy this repo on Arch boxes and MacOS boxes with the following command. This should pretty much set everything up as you need it.

```shell
ansible-pull -U https://github.com/thadigus/dotfiles ansible_pull.yml
```

## Support
Any support/questions or ideas can be addressed on the [Issues Page](https://gitlab.com/thadigus/dotfiles/-/issues).

## Contributing
This is mainly a repo for my personal configuration tracking and some examples I can give on my [blog](https://turnerservices.cloud/). I'm open to ideas and suggestions but this is mostly a repo I am providing publicly in case someone wants to see an example of something I've done.

## Authors and acknowledgment

### [Thad Turner](https://turnerservices.cloud/) - Cybersecurity Practitioner

