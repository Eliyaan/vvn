import gg
import emmathemartianvon
import os

struct Line {
	chars map[string]string
	bg    string
	l     string
	audio string
	act   []Choice // actions
}

struct Choice {
	l    string
	next string
	ifs  map[string]von.Value
	csq  map[string]von.Value
}

struct App {
mut:
	ctx           &gg.Context = unsafe { nil }
	bgs           map[string]gg.Image
	chars         map[string]map[string]gg.Image
	data          map[string]von.Value
	dlines        map[string]Line
	current_dline von.Value
}

fn run(bg_path string, chars_path string, data_path string, dlines_path string) ! {
	mut app := &App{
		data: von.parse_file(data_path)! as Map.values
	}
	app.ctx = gg.new_context( // TODO: out of module
		create_window: true
		window_title:  'Visual Novel'
		user_data:     app
		frame_fn:      on_frame
		event_fn:      on_event
		sample_count:  2
	)

	bg_values := von.parse_file(bg_path)! as Map.values
	for name in bg_values.keys() {
		if bg_values[name] is string {
			path := bg_values[name] as string
			if os.exists(path) {
				app.bgs[name] = gg.create_image(path)!
			} else {
				return error('background image ${path} not found')
			}
		} else {
			return error('${bg_values[name]} is not a string path (from the bg name ${name})')
		}
	}

	chars_values := von.parse_file(chars_path)! as Map.values
	for name in chars_values.keys() {
		if chars_values[name] is string {
			cname := bg_values[name] as string
			for iname in chars_values[cname].keys() {
				if chars_values[cname][iname] is string {
					ipath := chars_values[cname][imane] as string
					if os.exists(ipath) {
						app.chars[cname][iname] = gg.create_image(ipath)!
					} else {
						return error('char image ${ipath} not found')
					}
				} else {
					return error('${chars_values[cname][iname]} is not a string path (from the char name ${cname})')
				}
			}
		} else {
			return error('${chars_values[name]} is not a string path (from the char name ${name})')
		}
	}

	dlines_values := von.parse_file(dlines_path)! as Map.values
	for name in dlines_values.keys() {
		if dlines_values[name] is von.Map {
			if dlines_values[name] as von.Map.type != 'Line' {
				return error('${dlines_values[name]} is not a `Line`')
			}
			line_map := dlines_values[name] as von.Map.values
			mut line := Line{}
			lchars_values := line_map['chars'] or {
				return error('Did not find `chars` field for line ${name}')
			}
			if lchars_values is von.Map {
				for cname in lchars_values.keys() {
					if cname !in app.chars {
						return error('Unknown char ${cname} in ${app.chars.keys()}')
					}
					char_img := lchars_values[cname]
					if char_img is string {
						if char_img !in app.chars[cname] {
							return error('Unknown charimg ${char_img} for ${cname} in ${app.chars[cname].keys()}')
						}
						line.chars[cname] = char_img
					} else {
						return error('${char_img} is not a string (for char ${cname} of line `${name}`)')
					}
				}
			} else {
				return error('${lchars_values} is not a Map (for chars of line `${name}`)')
			}
			lbg_value := line_map['bg'] or {
				return error('Did not find `bg` field for line ${name}')
			}
			if lbg_value is string {
				if lbg_value !in app.bgs {
					return error('Unknown char ${cname} in ${app.chars.keys()}')
				}
				line.bg = lbg_value
			} else {
				return error('${lbg_value} is not a string (for bg of line `${name}`)')
			}
			ll_value := line_map['l'] or { return error('Did not find `l` field for line ${name}') }
			if ll_value is string {
				line.l = ll_value
			} else {
				return error('${ll_value} is not a string (for l of line `${name}`)')
			}
			laudio_value := line_map['audio'] or { von.Value('') }
			if laudio_value is string {
				if laudio_value != '' {
					line.l = laudio_value
					eprintln('audio is not yet supported')
				}
			} else {
				return error('${laudio_value} is not a string (for audio of line `${name}`)')
			}
			lact_value := line_map['act'] or { von.Value('') }
			if lact_value is string {
				if laudio_value != '' {
					line.act << Choice{
						next: lact_value
					}
				} else {
					return error('You need to specify a act for line ${name}, either \'name_next_line\' or []Choice')
				}
			} else if lact_value is []Value {
				for v in lact_value {
					if v is von.Map {
						if v.type != 'Choice' {
							return error('${v} is not a `Choice`')
						}
						mut c := Choice{}

						line.act << c
					} else {
						return error('${v} is not a Map (choice of act of line `${name}`)')
					}
				}
			} else {
				return error('${laudio_value} is not a string nor a Map (for act of line `${name}`)')
			}
			app.dlines[name] = line
		} else {
			return error('${bg_values[name]} is not a Map (from the line `${name}`)')
		}
	}

	struct Line {
		chars map[string]string
		bg    string
		l     string
		audio string
		act   []Choice // actions
	}

	struct Choice {
		l    string
		next string
		ifs  map[string]von.Value
		csq  map[string]von.Value
	}

	first_dline_name := app.data['vvn_first_dialogue'] or { app.dlines.keys()[0] }
	app.current_dline = app.dlines[first_dline_name]

	app.ctx.run()
}

fn on_frame(mut app App) { // TODO: out of module
	app.ctx.begin()
	app.ctx.end()
}

fn on_event(e &gg.Event, mut app App) { // TODO: out of module
	if e.char_code != 0 {
		println(e.char_code)
	}
	match e.typ {
		.mouse_down {
			app.square_size += 1
		}
		.key_down {
			match e.key_code {
				.escape { app.ctx.quit() }
				else {}
			}
		}
		else {}
	}
}
