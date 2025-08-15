import vvn
import gg

struct App {
mut:
	ctx &gg.Context = unsafe { nil }
	d   vvn.Data
	s   vvn.Settings
}

fn main() {
	mut app := &App{}
	app.ctx = gg.new_context( // Important to initialize the context before vvn
		create_window: true
		window_title:  'Visual Novel'
		user_data:     app
		frame_fn:      on_frame
		event_fn:      on_event
		sample_count:  2
	)

	vvn.init(mut app, 'bg.von', 'chars.von', 'data.von', 'dlines.von')!
	app.s = vvn.Settings{
		color_dline:         gg.Color{255, 255, 255, 255}
		color_choice:        gg.Color{128, 128, 128, 255}
		color_select_choice: gg.Color{200, 128, 128, 255}
		side_margin:         10
		line_h:              40
		char_dx:             250
		char_w:              300
		char_h:              500
		text_char_max_w:     16
		text_cfg:            gg.TextCfg{
			color: gg.black
			size:  32
		}
	}

	app.ctx.run()
}

fn on_event(e &gg.Event, mut app App) {
	vvn.events(mut app, e)

	if e.char_code != 0 {
		println(e.char_code)
	}
	match e.typ {
		.mouse_down {}
		.key_down {
			match e.key_code {
				.escape { app.ctx.quit() }
				else {}
			}
		}
		else {}
	}
}

fn on_frame(mut app App) {
	app.ctx.begin()
	vvn.draw(mut app)
	app.ctx.end()
}
