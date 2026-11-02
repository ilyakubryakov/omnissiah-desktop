hl.config({
	general = {
		col = {
			active_border = "rgb({{accent:hex}})",
			inactive_border = "rgb({{light_background:hex}})",
		},
	},
	group = {
		col = {
			border_active = "rgb({{accent:hex}})",
			border_inactive = "rgb({{light_background:hex}})",
			border_locked_active = "rgb({{red:hex}})",
			border_locked_inactive = "rgb({{light_background:hex}})",
		},
		groupbar = {
			text_color = "rgb({{background:hex}})",
			text_color_inactive = "rgb({{muted:hex}})",
			col = {
				active = "rgb({{accent:hex}})",
				inactive = "rgb({{dark_background:hex}})",
				locked_active = "rgb({{red:hex}})",
				locked_inactive = "rgb({{dark_background:hex}})",
			},
		},
	},
	misc = {
		background_color = "rgb({{background:hex}})",
	},
})
