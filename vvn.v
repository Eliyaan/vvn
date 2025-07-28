module vvn

import gx
import gg
import emmathemartian.von
import os

pub struct Line {
pub mut:
	chars map[string]string
	bg    string
	l     string
	audio string
	act   []Choice // actions
}

pub struct Choice {
pub mut:
	l    string
	next string
	ifs  map[string]von.Value
	csq  map[string]von.Value
}

pub struct Data {
pub mut:
	bgs            map[string]gg.Image
	chars          map[string]map[string]gg.Image
	data           map[string]von.Value
	dlines         map[string]Line
	current_dline  Line
	lines          []string
	selected_dline int
	old_size       gg.Size
}

pub struct Settings {
pub mut:
	char_w              f32
	char_h              f32
	char_dx             int
	side_margin         int
	line_h              int
	color_dline         gg.Color
	color_choice        gg.Color
	color_select_choice gg.Color
	text_cfg            gx.TextCfg
	text_char_max_w     int = 8
}

pub interface App {
mut:
	ctx &gg.Context
	d   Data
	s   Settings
}

pub fn init(mut app App, bg_path string, chars_path string, data_path string, dlines_path string) ! {
	println('Parsing ${data_path}')
	app.d.data = (von.parse_file(data_path)! as von.Map).values

	println('Parsing ${data_path}')
	bg_values := (von.parse_file(bg_path)! as von.Map).values
	for name, path in bg_values {
		if path is string {
			if os.exists(path) {
				app.d.bgs[name] = app.ctx.create_image(path)!
			} else {
				return error('background image ${path} not found')
			}
		} else {
			return error('${path} is not a string path (from the bg name ${name})')
		}
	}

	println('Parsing ${chars_path}')
	chars_values := (von.parse_file(chars_path)! as von.Map).values
	for name, char_von in chars_values {
		if char_von is von.Map {
			char_map := unsafe { &char_von.values }
			for iname, ipath in char_map {
				if ipath is string {
					if os.exists(ipath) {
						app.d.chars[name][iname] = app.ctx.create_image(ipath)!
					} else {
						return error('char image ${ipath} not found')
					}
				} else {
					return error('${ipath} is not a string path (from the char name ${name})')
				}
			}
		} else {
			return error('${char_von} is not a Map (from the char name ${name})')
		}
	}

	println('Parsing ${dlines_path}')
	dlines_values := (von.parse_file(dlines_path)! as von.Map).values
	for name, line_von_map in dlines_values {
		if line_von_map is von.Map {
			if line_von_map.type or { '' } != 'Line' {
				return error('${line_von_map} is not a `Line`')
			}
			line_map := unsafe { &line_von_map.values }
			mut line := Line{}
			lchars_values := unsafe {
				line_map['chars'] or { return error('Did not find `chars` field for line ${name}') }
			}
			if lchars_values is von.Map {
				lchars := unsafe { &lchars_values.values }
				for cname, char_img in lchars {
					char_imgs := unsafe {
						&app.d.chars[cname] or {
							return error('Unknown char ${cname} in ${app.d.chars.keys()}')
						}
					}
					if char_img is string {
						if char_img !in char_imgs {
							return error('Unknown charimg ${char_img} for ${cname} in ${char_imgs.keys()}')
						}
						line.chars[cname] = char_img
					} else {
						return error('${char_img} is not a string (for char ${cname} of line `${name}`)')
					}
				}
			} else {
				return error('${lchars_values} is not a Map (for chars of line `${name}`)')
			}
			lbg_value := unsafe {
				line_map['bg'] or { return error('Did not find `bg` field for line ${name}') }
			}
			if lbg_value is string {
				if lbg_value !in app.d.bgs {
					return error('Unknown bg ${lbg_value} in ${app.d.bgs.keys()}')
				}
				line.bg = lbg_value
			} else {
				return error('${lbg_value} is not a string (for bg of line `${name}`)')
			}
			ll_value := unsafe {
				line_map['l'] or { return error('Did not find `l` field for line ${name}') }
			}
			if ll_value is string {
				line.l = ll_value
			} else {
				return error('${ll_value} is not a string (for l of line `${name}`)')
			}
			laudio_value := unsafe { line_map['audio'] or { von.Value('') } }
			if laudio_value is string {
				if laudio_value != '' {
					line.audio = laudio_value
					eprintln('audio is not yet supported')
				}
			} else {
				return error('${laudio_value} is not a string (for audio of line `${name}`)')
			}
			lact_value := unsafe { line_map['act'] or { von.Value('') } }
			if lact_value is string {
				if lact_value != '' {
					line.act << Choice{
						next: lact_value
					}
				} else {
					return error('You need to specify a act for line ${name}, either \'name_next_line\' or []Choice')
				}
			} else if lact_value is []von.Value {
				for v in lact_value {
					if v is von.Map {
						vv := unsafe { &v.values }
						if v.type or { '' } != 'Choice' {
							return error('${vv} is not a `Choice`')
						}
						mut c := Choice{}
						c_l_value := unsafe { vv['l'] or { von.Value('') } }
						if c_l_value is string {
							c.l = c_l_value
						} else {
							return error('l ${c_l_value} is not a string (for choice ${vv} of line `${name}`)')
						}
						c_next_value := unsafe { vv['next'] or { von.Value('') } }
						if c_next_value is string {
							if c_next_value == '' {
								return error('You need to specify next dialogue line for choice ${vv}')
							}
							if c_next_value !in dlines_values {
								return error('dialogue line ${c_next_value} does not exist (from choice ${vv})')
							}
							c.next = c_next_value
						} else {
							return error('next ${c_next_value} is not a string (for choice ${vv} of line `${name}`)')
						}
						c_if_value := unsafe { vv['if'] or { von.Map{} } }
						if c_if_value is von.Map {
							c_if := unsafe { &c_if_value.values }
							if c_if.keys().len > 0 {
								for field in c_if.keys() {
									if field !in app.d.data { // TODO: check type
										return error('${field} is not in data.von (if of choice ${vv} of line `${name}`)')
									}
								}
								c.ifs = c_if
								eprintln('ifs are not supported yet')
							}
						} else {
							return error('if ${c_if_value} is not a Map (for choice ${vv} of line `${name}`)')
						}
						c_csq_value := unsafe { vv['csq'] or { von.Map{} } }
						if c_csq_value is von.Map {
							c_csq := unsafe { &c_csq_value.values }
							if c_csq.keys().len > 0 {
								for field in c_csq.keys() {
									if field !in app.d.data { // TODO: check type
										return error('${field} is not in data.von (csq of choice ${vv} of line `${name}`)')
									}
								}
								c.csq = c_csq
								eprintln('csq are not supported yet')
							}
						} else {
							return error('csq ${c_csq_value} is not a Map (for choice ${vv} of line `${name}`)')
						}
						line.act << c
					} else {
						return error('${v} is not a Map (choice of act of line `${name}`)')
					}
				}
			} else {
				return error('${lact_value} is not a string nor a Map (for act of line `${name}`)')
			}
			app.d.dlines[name] = line
		} else {
			return error('${line_von_map} is not a Map (from the line `${name}`)')
		}
	}

	first_dline_name := app.d.data['vvn_first_dialogue'] or { app.d.dlines.keys()[0] }
	if first_dline_name is string {
		change_dline(mut app, first_dline_name)
	} else {
		return error('vvn_first_dialogue: ${first_dline_name} is not string ')
	}
}

pub fn draw(mut app App) {
	s := app.ctx.window_size()

	w_margin := s.width - 2 * app.s.side_margin
	app.ctx.draw_image(0, 0, s.width, s.height, unsafe { app.d.bgs[app.d.current_dline.bg] })
	if s != app.d.old_size {
		app.d.lines = app.d.current_dline.l.wrap(width: w_margin / app.s.text_char_max_w).split('\n')
		app.d.old_size = s
	}
	for i, c in app.d.current_dline.chars.keys() {
		c_img := app.d.current_dline.chars[c]
		app.ctx.draw_image(i * app.s.char_dx, s.height - app.s.char_h, app.s.char_w, app.s.char_h,
			unsafe { app.d.chars[c][c_img] })
	}
	app.ctx.draw_rect_filled(0, s.height - app.s.line_h * app.d.lines.len, s.width, app.s.line_h * app.d.lines.len,
		app.s.color_dline)
	if app.d.current_dline.act.len > 1 {
		app.ctx.draw_rect_filled(0, s.height - app.s.line_h * (app.d.lines.len +
			app.d.current_dline.act.len), s.width, app.s.line_h * app.d.current_dline.act.len,
			app.s.color_choice)
	}
	app.ctx.draw_rect_filled(0, s.height - app.s.line_h * (app.d.lines.len + app.d.selected_dline +
		1), s.width, app.s.line_h, app.s.color_select_choice)

	off_y := (app.s.line_h - app.s.text_cfg.size) / 2
	for i, l in app.d.lines {
		app.ctx.draw_text(app.s.side_margin, s.height - app.s.line_h * (app.d.lines.len - i) + off_y,
			l, app.s.text_cfg)
	}
	for i, c in app.d.current_dline.act {
		app.ctx.draw_text(app.s.side_margin, s.height - app.s.line_h * (app.d.lines.len + i + 1) +
			off_y, c.l, app.s.text_cfg)
	}
}

pub fn change_dline(mut app App, next string) {
	s := app.ctx.window_size()
	app.d.current_dline = app.d.dlines[next]
	app.d.lines = app.d.current_dline.l.wrap(width: s.width / app.s.text_char_max_w).split('\n')
	app.d.old_size = s
	app.d.selected_dline = 0
}

pub fn events(mut app App, e &gg.Event) {
	s := app.ctx.window_size()

	match e.typ {
		.mouse_down {
			if app.d.current_dline.act.len == 1 && app.d.current_dline.act[0].l == '' {
				change_dline(mut app, app.d.current_dline.act[0].next)
			} else {
				for i, c in app.d.current_dline.act {
					y := s.height - app.s.line_h * (app.d.lines.len + i + 1)
					y_2 := s.height - app.s.line_h * (app.d.lines.len + i)
					if e.mouse_x >= 0 && e.mouse_x <= s.width && e.mouse_y >= y && e.mouse_y <= y_2 {
						change_dline(mut app, c.next)
					}
				}
			}
		}
		.mouse_move {
			for i, _ in app.d.current_dline.act {
				y := s.height - app.s.line_h * (app.d.lines.len + i + 1)
				y_2 := s.height - app.s.line_h * (app.d.lines.len + i)
				if e.mouse_x >= 0 && e.mouse_x <= s.width && e.mouse_y >= y && e.mouse_y <= y_2 {
					app.d.selected_dline = i
				}
			}
		}
		.key_down {}
		else {}
	}
}
