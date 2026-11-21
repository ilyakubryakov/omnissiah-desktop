# theme:out=mako.conf
font=Inter 11
width=380
height=180
margin=8
padding=12
border-size=1
border-radius=0
background-color={{background}}
text-color={{foreground}}
border-color={{accent}}
progress-color=over {{selection}}
anchor=top-right
max-visible=4
max-history=30
default-timeout=7000
on-button-left=invoke-default-action
on-button-right=dismiss
on-button-middle=exec makoctl menu -n "$id" -- fuzzel --dmenu --prompt='Action: '
group-by=app-name,summary

[grouped]
format=<b>%s</b>  ×%g\n%b

[urgency=critical]
border-color={{red}}
default-timeout=0
ignore-timeout=1

[mode=do-not-disturb]
invisible=1

[mode=do-not-disturb urgency=critical]
invisible=0

[app-name="OniNix Notebook"]
on-button-left=dismiss
border-color={{accent}}

[app-name=blueman actionable=1]
on-button-left=exec makoctl menu -n "$id" -- fuzzel --dmenu --prompt='Bluetooth: '
default-timeout=0
ignore-timeout=1

[actionable=1]
invisible=1

[app-name="KDE Connect" actionable=1]
default-timeout=0
ignore-timeout=1

[mode=gaming]
invisible=1
