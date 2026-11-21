# theme:out=starship.toml

format = "$username$hostname$directory$git_branch$git_state$git_status$jobs$character"
right_format = "$status$cmd_duration"

add_newline = false

[username]
show_always = false
style_user = "fg:{{bright_yellow}}"
style_root = "fg:{{red}} bold"
format = "[$user]($style)"

[hostname]
ssh_only = true
style = "fg:{{bright_yellow}}"
format = "[@$hostname]($style) "

[directory]
style = "fg:{{blue}} bold"
read_only = " "
read_only_style = "fg:{{red}}"
format = "[$path]($style)[$read_only]($read_only_style) "
truncation_length = 3
truncation_symbol = "…/"
truncate_to_repo = false
home_symbol = "~"

[git_branch]
symbol = " "
style = "fg:{{magenta}}"
format = "[$symbol$branch]($style) "

[git_state]
style = "fg:{{bright_red}} bold"
format = "[\\($state $progress_current/$progress_total\\)]($style) "

[git_status]
style = "fg:{{bright_yellow}}"
format = "[$all_status$ahead_behind]($style)"
conflicted = "= "
ahead = "⇡${count} "
behind = "⇣${count} "
diverged = "⇕⇡${ahead_count}⇣${behind_count} "
untracked = "? "
stashed = "$ "
modified = "! "
staged = "+ "
renamed = "» "
deleted = "✘ "

[jobs]
symbol = "⏵"
style = "fg:{{bright_yellow}}"
number_threshold = 1
format = "[$symbol$number]($style) "

[status]
disabled = false
style = "fg:{{red}}"
format = "[$status]($style) "
map_symbol = false
pipestatus = true

[character]
success_symbol = "[❯](bold {{green}})"
error_symbol = "[❯](bold {{red}})"

[cmd_duration]
min_time = 2000
style = "fg:{{yellow}}"
format = "[ $duration]($style)"
