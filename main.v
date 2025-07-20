import gg
import von

struct App {
mut:
	ctx &gg.Context = unsafe { nil }
	bg map[string]gg.Image
	chars map[string]map[string]gg.Image
	data map[string]von.Value
	dlines map[string]von.Value
	current_dline von.Value
}

fn run(bg_path string, chars_path string, data_path string, dlines_path string)! {
	mut app := &App{
		data: von.parse_file(data_path)! as Map.values
		dlines: von.parse_file(dlines_path)! as Map.values
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
		match bg_values[name] {
			string {
				path := bg_values[name] as string
				if os.exists(path) {
					app.bg[name] = gg.Image(path)!
				} else {
					error('background image ${path} not found')
				}
			}
			else {
				error('${bg_values[name]} is not a string path (from the bg name ${name})')
			}
		}
	}

	chars_values := von.parse_file(chars_path)! as Map.values
	for name in chars_values.keys() {
		match chars_values[name] {
			string {
				cname := bg_values[name] as string
				for iname in chars_values[cname].keys() {
					match chars_values[cname][iname] {
						string {
							ipath := chars_values[cname][imane] as string
							if os.exists(ipath) {
								app.chars[cname][iname] = gg.Image(ipath)!
							} else {
								error('char image ${ipath} not found')
							}
						}
						else {
							error('${chars_values[cname][iname]} is not a string path (from the char name ${cname})')
						}
					}
				}
			}
			else {
				error('${chars_values[name]} is not a string path (from the char name ${name})')
			}
		}
	}

	first_dline_name := app.data['vvn_first_dialogue'] or {app.dlines.keys()[0]}
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
