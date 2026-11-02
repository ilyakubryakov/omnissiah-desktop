LS_COLORS="$LS_COLORS:di=1;38;2;{{blue:sgr}}:ln=38;2;{{cyan:sgr}}:ex=38;2;{{green:sgr}}"
LS_COLORS="$LS_COLORS:*.md=38;2;{{yellow:sgr}}:*.yaml=38;2;{{yellow:sgr}}:*.yml=38;2;{{yellow:sgr}}"
LS_COLORS="$LS_COLORS:*.tf=38;2;{{magenta:sgr}}:*.json=38;2;{{yellow:sgr}}"
export LS_COLORS

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg={{muted}}'

THEME_FZF_COLORS=(
  '--color=fg:{{foreground}},bg:-1,hl:{{blue}}'
  '--color=fg+:{{bright_white}},bg+:{{selection}},hl+:{{bright_blue}}'
  '--color=info:{{cyan}},prompt:{{bright_yellow}},pointer:{{bright_red}}'
  '--color=marker:{{red}},spinner:{{magenta}},header:{{muted}},border:{{dim_foreground}}'
)

THEME_DIM='{{dim_foreground}}'
