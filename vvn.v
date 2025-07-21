module vvn

import gg
import emmathemartian.von
import os

struct Line {
mut:
	chars map[string]string
	bg    string
	l     string
	audio string
	act   []Choice // actions
}

struct Choice {
mut:
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
	current_dline Line
}

fn run(bg_path string, chars_path string, data_path string, dlines_path string) ! {
	mut app := &App{
		data: (von.parse_file(data_path)! as von.Map).values
	}
	app.ctx = gg.new_context( // TODO: out of module
		create_window: true
		window_title:  'Visual Novel'
		user_data:     app
		frame_fn:      on_frame
		event_fn:      on_event
		sample_count:  2
	)

	bg_values := (von.parse_file(bg_path)! as von.Map).values
	for name in bg_values.keys() {
		path := bg_values[name] or { von.Value('') }
		if path is string {
			if os.exists(path) {
				app.bgs[name] = app.ctx.create_image(path)!
			} else {
				return error('background image ${path} not found')
			}
		} else {
			return error('${path} is not a string path (from the bg name ${name})')
		}
	}

	chars_values := (von.parse_file(chars_path)! as von.Map).values
	for name in chars_values.keys() {
		char_von := chars_values[name] or { von.Value('') }
		if char_von is von.Map {
			char_map := unsafe { &char_von.values }
			for iname in char_map.keys() {
				ipath := unsafe { char_map[iname] }
				if ipath is string {
					if os.exists(ipath) {
						app.chars[name][iname] = app.ctx.create_image(ipath)!
					} else {
						return error('char image ${ipath} not found')
					}
				} else {
					return error('${ipath} is not a string path (from the char name ${name})')
				}
			}
		} else {
			return error('${char_von} is not a string path (from the char name ${name})')
		}
	}

	dlines_values := (von.parse_file(dlines_path)! as von.Map).values
	for name in dlines_values.keys() {
		line_von_map := dlines_values[name] or { von.Value('') }
		if line_von_map is von.Map {
			if line_von_map.type or { '' } != 'Line' {
				return error('${line_von_map} is not a `Line`')
			}
			line_map := unsafe { &line_von_map.values }
			mut line := Line{}
			lchars_values := unsafe { line_map['chars'] or { return error('Did not find `chars` field for line ${name}') } }
			if lchars_values is von.Map {
				lchars := unsafe { &lchars_values.values }
				for cname in lchars.keys() {
					char_imgs := unsafe { &app.chars[cname] or { return error('Unknown char ${cname} in ${app.chars.keys()}') }}
					char_img := unsafe { lchars[cname] }
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
			lbg_value := unsafe { line_map['bg'] or { return error('Did not find `bg` field for line ${name}') }}
			if lbg_value is string {
				if lbg_value !in app.bgs {
					return error('Unknown bg ${lbg_value} in ${app.bgs.keys()}')
				}
				line.bg = lbg_value
			} else {
				return error('${lbg_value} is not a string (for bg of line `${name}`)')
			}
			ll_value := unsafe { line_map['l'] or { return error('Did not find `l` field for line ${name}') }}
			if ll_value is string {
				line.l = ll_value
			} else {
				return error('${ll_value} is not a string (for l of line `${name}`)')
			}
			laudio_value := unsafe{line_map['audio'] or { von.Value('') }}
			if laudio_value is string {
				if laudio_value != '' {
					line.l = laudio_value
					eprintln('audio is not yet supported')
				}
			} else {
				return error('${laudio_value} is not a string (for audio of line `${name}`)')
			}
			lact_value := unsafe{line_map['act'] or { von.Value('') }}
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
						c_if_value := unsafe { vv['if'] or {von.Map{}}}
						if c_if_value is von.Map {
							c_if := unsafe { &c_if_value.values }
							if c_if.keys().len > 0 {
								for field in c_if.keys() {
									if field !in app.data { // TODO: check type
										return error('${field} is not in data.von (if of choice ${vv} of line `${name}`)')
									}
								}
								c.ifs = c_if
								eprintln('ifs are not supported yet')
							}
						} else {
							return error('if ${c_if_value} is not a Map (for choice ${vv} of line `${name}`)')
						}
						c_csq_value := unsafe { vv['csq'] or {von.Map{}}}
						if c_csq_value is von.Map {
							c_csq := unsafe { &c_csq_value.values }
							if c_csq.keys().len > 0 {
								for field in c_csq.keys() {
									if field !in app.data { // TODO: check type
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
				return error('${laudio_value} is not a string nor a Map (for act of line `${name}`)')
			}
			app.dlines[name] = line
		} else {
			return error('${line_von_map} is not a Map (from the line `${name}`)')
		}
	}

	first_dline_name := app.data['vvn_first_dialogue'] or { app.dlines.keys()[0] }
	if first_dline_name is string {
		app.current_dline = app.dlines[first_dline_name]
	} else {
		return error('vvn_first_dialogue: ${first_dline_name} is not string ')
	}

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
