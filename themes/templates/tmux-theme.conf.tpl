set -g status-position top
set -g status-justify left
set -g status-style "bg=default,fg={{muted}}"
set -g status-left-length 100
set -g status-right-length 100
set -g status-left ""

setw -g window-status-separator ""
setw -g window-status-format "#[fg={{dark_background}},bg=default]#[fg={{muted}},bg={{dark_background}}] #I #W #[fg={{dark_background}},bg=default]"
setw -g window-status-current-format "#[fg={{accent}},bg=default]#[fg={{background}},bg={{accent}},bold] #I #W #[fg={{accent}},bg=default]"
setw -g window-status-activity-style "fg={{bright_yellow}},bg={{dark_background}}"
setw -g window-status-bell-style "fg={{bright_red}},bg={{dark_background}}"

set -g status-right "#[fg={{dark_background}},bg=default]#[fg={{muted}},bg={{dark_background}}] #{?client_prefix,#[fg={{bright_red}}#,bold]C-a,#{pane_current_command}} #[fg={{dark_background}},bg=default]#[fg={{green}},bg=default]#[fg={{background}},bg={{green}},bold] #S #[fg={{green}},bg=default]"

set -g pane-border-style "fg={{dim_foreground}}"
set -g pane-active-border-style "fg={{accent}}"
set -g display-panes-colour "{{dim_foreground}}"
set -g display-panes-active-colour "{{accent}}"

set -g message-style "fg={{background}},bg={{bright_yellow}},bold"
set -g message-command-style "fg={{background}},bg={{bright_yellow}},bold"
setw -g mode-style "fg={{bright_foreground}},bg={{selection}}"
setw -g clock-mode-colour "{{accent}}"
