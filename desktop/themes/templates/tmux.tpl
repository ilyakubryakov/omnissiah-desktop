# theme:out=tmux-theme.conf
# The status line, from the same palette as everything else.
#
# This replaces the catppuccin/tmux plugin, which was the last thing on the two
# machines still carrying a different theme - Mocha, next to Kanagawa
# everywhere else, and with no light variant at all.
#
# Shapes are kept from what the plugin drew, because that part was fine: rounded
# segments, window list on the left, command and session name on the right. The
# half-circles are Nerd Font glyphs (U+E0B6 / U+E0B4), which both machines have.
#
# `bg=default` rather than a colour of our own: the terminal's background shows
# through, so a transparent kitty stays transparent behind the status line.

set -g status-position top
set -g status-justify left
set -g status-style "bg=default,fg={{muted}}"
set -g status-left-length 100
set -g status-right-length 100
set -g status-left ""

# Window list. Inactive windows sit on dark_background, which is a shade AWAY
# from the background in both variants - light_background would vanish on
# Lotus, where it is lighter than the paper.
setw -g window-status-separator ""
setw -g window-status-format "#[fg={{dark_background}},bg=default]#[fg={{muted}},bg={{dark_background}}] #I #W #[fg={{dark_background}},bg=default]"
setw -g window-status-current-format "#[fg={{accent}},bg=default]#[fg={{background}},bg={{accent}},bold] #I #W #[fg={{accent}},bg=default]"
setw -g window-status-activity-style "fg={{bright_yellow}},bg={{dark_background}}"
setw -g window-status-bell-style "fg={{bright_red}},bg={{dark_background}}"

# Right: what is running, then the session. The prefix indicator takes the
# place of the command while the prefix is held, which is the one piece the
# plugin did not have and the one worth adding - C-a is easy to lose track of.
set -g status-right "#[fg={{dark_background}},bg=default]#[fg={{muted}},bg={{dark_background}}] #{?client_prefix,#[fg={{bright_red}}#,bold]C-a,#{pane_current_command}} #[fg={{dark_background}},bg=default]#[fg={{green}},bg=default]#[fg={{background}},bg={{green}},bold] #S #[fg={{green}},bg=default]"

# Panes: the active one is outlined in the accent, the rest recede.
set -g pane-border-style "fg={{dim_foreground}}"
set -g pane-active-border-style "fg={{accent}}"
set -g display-panes-colour "{{dim_foreground}}"
set -g display-panes-active-colour "{{accent}}"

# Messages, the command prompt, and copy mode.
set -g message-style "fg={{background}},bg={{bright_yellow}},bold"
set -g message-command-style "fg={{background}},bg={{bright_yellow}},bold"
setw -g mode-style "fg={{bright_foreground}},bg={{selection}}"
setw -g clock-mode-colour "{{accent}}"
