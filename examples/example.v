import vvn
import emmathemartian.von
import gx
import gg

struct App {
mut:
	ctx           &gg.Context = unsafe { nil }
	bgs           map[string]gg.Image
	chars         map[string]map[string]gg.Image
	data          map[string]von.Value
	dlines        map[string]vvn.Line
	current_dline vvn.Line
	lines         []string
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

	app.ctx.run()
}

fn on_event(e &gg.Event, mut app App) { 
	vvn.events(mut app, e, 16, 40)
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
	vvn.draw(mut app, 200, 600, 16, 40, gx.TextCfg{ color: gx.black, size: 32 })
	app.ctx.end()
}
