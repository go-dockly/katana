package vgo

import "core:c/libc"
import "core:encoding/json"
import "core:unicode"
import "core:unicode/utf8"
import "core:unicode/utf16"
import "base:runtime"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"
import stbi "vendor:stb/image"
import "vendor:wgpu"

Font_Glyph :: struct {
	// UV location in source texture
	source:  Box,
	bounds:  Box,
	advance: f32,
	descend: f32,
}

Font :: struct {
	first_rune:            rune,
	// em_size:               f32,
	size:                  f32,
	space_advance:                  f32,
	ascend:                f32,
	descend:               f32,
	// underline_y:           f32,
	// underline_width:       f32,
	line_height:           f32,
	distance_range:        f32,
	glyphs:                []Font_Glyph,
}

destroy_font :: proc(font: ^Font) {
	delete(font.glyphs)
	font^ = {}
}

set_font :: proc(font: Font) {
	core.current_font = font
}

set_fallback_font :: proc(font: Font) {
	core.fallback_font = font
}

load_font_from_files :: proc(image_file, json_file: string) -> (font: Font, ok: bool) {
	image_data := os.read_entire_file(image_file) or_return
	defer delete(image_data)
	json_data := os.read_entire_file(json_file) or_return
	defer delete(json_data)
	return load_font_from_slices(image_data, json_data)
}

load_font_from_slices :: proc(image_data, json_data: []u8) -> (font: Font, ok: bool) {
	width, height: libc.int
	bitmap_data := stbi.load_from_memory(
		raw_data(image_data),
		i32(len(image_data)),
		&width,
		&height,
		nil,
		4,
	)

	if bitmap_data == nil do return
	atlas_source := copy_image_to_atlas(bitmap_data, int(width), int(height))

	json_value, json_err := json.parse(json_data)
	defer json.destroy_value(json_value)

	if json_err != nil do return

	obj := json_value.(json.Object) or_return

	atlas_obj := obj["atlas"].(json.Object) or_return
	font.distance_range = f32(atlas_obj["distanceRange"].(json.Float) or_return)
	font.size = f32(atlas_obj["size"].(json.Float) or_return)

	metrics_obj := obj["metrics"].(json.Object) or_return
	// font.em_size = f32(metrics_obj["emSize"].(json.Float) or_return)
	font.line_height = f32(metrics_obj["lineHeight"].(json.Float) or_return)
	font.ascend = f32(metrics_obj["ascender"].(json.Float) or_return)
	font.descend = f32(metrics_obj["descender"].(json.Float) or_return)
	// font.underline_y = f32(metrics_obj["underlineY"].(json.Float) or_return)
	// font.underline_width = f32(metrics_obj["underlineThickness"].(json.Float) or_return)

	glyphs: [dynamic]Font_Glyph

	for glyph_value, i in obj["glyphs"].(json.Array) or_return {
		glyph_obj := glyph_value.(json.Object) or_return
		code := rune(i32(glyph_obj["unicode"].(json.Float) or_return))
		glyph := Font_Glyph {
			advance = f32(glyph_obj["advance"].(json.Float) or_return),
		}
		if code == ' ' {
			font.space_advance = glyph.advance
		}
		// left, bottom, right, top
		if plane_bounds_obj, ok := glyph_obj["planeBounds"].(json.Object); ok {
			glyph.bounds = Box {
				{
					f32(plane_bounds_obj["left"].(json.Float) or_return),
					1.0 - f32(plane_bounds_obj["top"].(json.Float) or_return),
				},
				{
					f32(plane_bounds_obj["right"].(json.Float) or_return),
					1.0 - f32(plane_bounds_obj["bottom"].(json.Float) or_return),
				},
			}
		}
		if atlas_bounds_obj, ok := glyph_obj["atlasBounds"].(json.Object); ok {
			glyph.source = Box{
				{
					atlas_source.lo.x + f32(atlas_bounds_obj["left"].(json.Float) or_return),
					atlas_source.hi.y - f32(atlas_bounds_obj["top"].(json.Float) or_return),
				},
				{
					atlas_source.lo.x + f32(atlas_bounds_obj["right"].(json.Float) or_return),
					atlas_source.hi.y - f32(atlas_bounds_obj["bottom"].(json.Float) or_return),
				},
			}
		}
		if i == 0 {
			font.first_rune = code
		}
		index := int(code - font.first_rune)
		non_zero_resize(&glyphs, index + 1)
		glyphs[index] = glyph
	}
	font.glyphs = glyphs[:]
	ok = true

	return
}

get_font_glyph :: proc(font: Font, char: rune) -> (glyph: Font_Glyph, ok: bool) {
	index := int(char - font.first_rune)
	ok = index >= 0 && index < len(font.glyphs)
	if !ok do return
	glyph = font.glyphs[index]
	return
}

DEFAULT_FONT: Font

make_default_font :: proc() {
	font: Font = {
		// em_size = 1,
		ascend = 0.927734375,
		descend = -0.244140625,
		// underline_y = -0.09765625,
		// underline_width = 0.048828125,
		line_height = 1.171875,
		size = 32.53125,
		distance_range = 2,
	}

	width, height: libc.int
	bitmap_data := stbi.load_from_memory(
		raw_data(DEFAULT_FONT_IMAGE),
		i32(len(DEFAULT_FONT_IMAGE)),
		&width,
		&height,
		nil,
		4,
	)
	if bitmap_data == nil do return

	atlas_source := copy_image_to_atlas(bitmap_data, int(width), int(height))

	glyphs: [dynamic]Font_Glyph

	for info, i in DEFAULT_FONT_INFO {
		glyph := Font_Glyph{
			advance = info.advance,
			bounds = {
				{info.quad_left, 1.0 - info.quad_top},
				{info.quad_right, 1.0 - info.quad_bottom},
			},
			source = {
				{atlas_source.lo.x + info.atlas_left, atlas_source.hi.y - info.atlas_top},
				{atlas_source.lo.x + info.atlas_right, atlas_source.hi.y - info.atlas_bottom},
			},
		}
		if i == 0 {
			font.first_rune = info.code
		}
		index := int(info.code - font.first_rune)
		non_zero_resize(&glyphs, index + 1)
		glyphs[index] = glyph
	}

	font.glyphs = glyphs[:]

	DEFAULT_FONT = font
}

Glyph_Atlas_Info :: struct {
	code: rune,
	advance: f32,
	quad_left: f32,
	quad_bottom: f32,
	quad_right: f32,
	quad_top: f32,
	atlas_left: f32,
	atlas_bottom: f32,
	atlas_right: f32,
	atlas_top: f32,
}

DEFAULT_FONT_INFO :: [?]Glyph_Atlas_Info{
	{13,0.24755859375,0,0,0,0,0,0,0,0},
	{32,0.24755859375,0,0,0,0,0,0,0,0},
	{33,0.25732421875,0.039372776702089329,-0.046109510086455335,0.22381081704791067,0.75312199807877034,309.5,186.5,315.5,212.5},
	{34,0.31982421875,0.028419516615633994,0.47646493756003838,0.30507657713436598,0.78386167146974062,351.5,331.5,360.5,341.5},
	{35,0.61572265625,0.023169672340297737,-0.046109510086455335,0.63796314015970224,0.75312199807877034,48.5,154.5,68.5,180.5},
	{36,0.5615234375,0.019718635551753065,-0.13832853025936598,0.54229308319824676,0.87608069164265123,191.5,328.5,208.5,361.5},
	{37,0.732421875,0.016610943503842401,-0.046109510086455335,0.72362343149615749,0.75312199807877034,146.5,154.5,169.5,180.5},
	{38,0.62158203125,0.011217804394812625,-0.046109510086455335,0.65675094560518721,0.75312199807877034,174.5,154.5,195.5,180.5},
	{39,0.17431640625,0.010064879022574455,0.47646493756003838,0.16376324597742556,0.78386167146974062,356.5,36.5,361.5,46.5},
	{40,0.341796875,0.024779452599663777,-0.26128722382324687,0.3629158599003362,0.84534101825168106,2.5,325.5,13.5,361.5},
	{41,0.34765625,-0.021363125525336216,-0.26128722382324687,0.31677328177533626,0.84534101825168106,18.5,325.5,29.5,361.5},
	{42,0.4306640625,-0.03082949650276183,0.26128722382324687,0.46100527775276173,0.75312199807877045,166.5,14.5,182.5,30.5},
	{43,0.56689453125,0.0050812207312679603,0.015369836695485105,0.55839534176873196,0.63016330451488956,235.5,36.5,253.5,56.5},
	{44,0.1962890625,-0.025313466243395769,-0.19980787704130648,0.18986424749339578,0.13832853025936598,272.5,19.5,279.5,30.5},
	{45,0.27587890625,-0.016491335704851104,0.23054755043227665,0.29090539820485112,0.38424591738712777,351.5,356.5,361.5,361.5},
	{46,0.26318359375,0.034245823577089329,-0.046109510086455335,0.21868386392291067,0.13832853025936598,355.5,66.5,361.5,72.5},
	{47,0.412109375,-0.034746769182276663,-0.10758885686839577,0.42634833168227659,0.75312199807877034,246.5,254.5,261.5,282.5},
	{48,0.5615234375,0.019230354301753065,-0.046109510086455335,0.54180480194824676,0.75312199807877034,322.5,154.5,339.5,180.5},
	{49,0.5615234375,0.050414218224663777,-0.046109510086455335,0.3885506255253362,0.75312199807877034,350.5,294.5,361.5,320.5},
	{50,0.5615234375,0.0084991894812679603,-0.046109510086455335,0.56181331051873196,0.75312199807877034,2.5,123.5,20.5,149.5},
	{51,0.5615234375,0.0099530105517530582,-0.046109510086455335,0.53252745819824676,0.75312199807877034,344.5,154.5,361.5,180.5},
	{52,0.5615234375,-0.0095561940892171515,-0.046109510086455335,0.57449760033921704,0.75312199807877034,25.5,123.5,44.5,149.5},
	{53,0.5615234375,0.037296760551753058,-0.046109510086455335,0.55987120819824676,0.75312199807877034,49.5,123.5,66.5,149.5},
	{54,0.5615234375,0.027775276176753058,-0.046109510086455335,0.55034972382324676,0.75312199807877034,71.5,123.5,88.5,149.5},
	{55,0.5615234375,0.0011749707312679603,-0.046109510086455335,0.55448909176873196,0.75312199807877034,111.5,123.5,129.5,149.5},
	{56,0.5615234375,0.019474494926753065,-0.046109510086455335,0.54204894257324676,0.75312199807877034,134.5,123.5,151.5,149.5},
	{57,0.5615234375,0.011173713676753058,-0.046109510086455335,0.53374816132324676,0.75312199807877034,156.5,123.5,173.5,149.5},
	{58,0.2421875,0.029607151702089329,-0.046109510086455335,0.21404519204791067,0.56868395773294911,258.5,36.5,264.5,56.5},
	{59,0.21142578125,-0.014327138118395769,-0.19980787704130648,0.20085057561839578,0.568683957732949,239.5,62.5,246.5,87.5},
	{60,0.50830078125,0.0043157308177232817,0.046109510086455321,0.46541083168227659,0.56868395773294911,68.5,13.5,83.5,30.5},
	{61,0.548828125,0.03191464412223817,0.13832853025936598,0.52374941837776179,0.50720461095100866,235.5,18.5,251.5,30.5},
	{62,0.5224609375,0.02800839412223817,0.046109510086455321,0.51984316837776179,0.56868395773294911,88.5,13.5,104.5,30.5},
	{63,0.47216796875,0.0040715901927232817,-0.046109510086455335,0.46516669105727659,0.75312199807877034,178.5,123.5,193.5,149.5},
	{64,0.89794921875,0.022776604479612203,-0.26128722382324687,0.88348745942677831,0.75312199807877034,235.5,328.5,263.5,361.5},
	{65,0.65234375,-0.027090228371157599,-0.046109510086455335,0.67992225962115749,0.75312199807877034,228.5,123.5,251.5,149.5},
	{66,0.62255859375,0.047805830106267946,-0.046109510086455335,0.60111995114373196,0.75312199807877034,256.5,123.5,274.5,149.5},
	{67,0.65087890625,0.024390375465297737,-0.046109510086455335,0.63918384328470224,0.75312199807877034,290.5,123.5,310.5,149.5},
	{68,0.65576171875,0.047572712160782835,-0.046109510086455335,0.63162650658921704,0.75312199807877034,315.5,123.5,334.5,149.5},
	{69,0.568359375,0.047062385551753058,-0.046109510086455335,0.56963683319824676,0.75312199807877034,22.5,92.5,39.5,118.5},
	{70,0.552734375,0.041447151176753058,-0.046109510086455335,0.56402159882324676,0.75312199807877034,44.5,92.5,61.5,118.5},
	{71,0.68115234375,0.026099359840297737,-0.046109510086455335,0.64089282765970224,0.75312199807877034,66.5,92.5,86.5,118.5},
	{72,0.712890625,0.048316156715297723,-0.046109510086455335,0.66310962453470224,0.75312199807877034,91.5,92.5,111.5,118.5},
	{73,0.27197265625,0.044011448577089329,-0.046109510086455335,0.22844948892291067,0.75312199807877034,350.5,186.5,356.5,212.5},
	{74,0.5517578125,-0.011043083198246942,-0.046109510086455335,0.51153136444824676,0.75312199807877034,138.5,92.5,155.5,118.5},
	{75,0.626953125,0.047583734840297723,-0.046109510086455335,0.66237720265970224,0.75312199807877034,160.5,92.5,180.5,118.5},
	{76,0.5380859375,0.036808479301753058,-0.046109510086455335,0.55938292694824676,0.75312199807877034,185.5,92.5,202.5,118.5},
	{77,0.873046875,0.036663542792387066,-0.046109510086455335,0.83589505095761274,0.75312199807877034,157.5,61.5,183.5,87.5},
	{78,0.712890625,0.048316156715297723,-0.046109510086455335,0.66310962453470224,0.75312199807877034,214.5,61.5,234.5,87.5},
	{79,0.6875,0.020739288769812625,-0.046109510086455335,0.66627242998018721,0.75312199807877034,188.5,61.5,209.5,87.5},
	{80,0.630859375,0.046107868410782835,-0.046109510086455335,0.63016166283921704,0.75312199807877034,342.5,92.5,361.5,118.5},
	{81,0.6875,0.017809601269812625,-0.1690682036503362,0.66334274248018721,0.75312199807877034,178.5,252.5,199.5,282.5},
	{82,0.61572265625,0.048060993410782835,-0.046109510086455335,0.63211478783921704,0.75312199807877034,110.5,61.5,129.5,87.5},
	{83,0.59326171875,0.0053363840357828485,-0.046109510086455335,0.58939017846421704,0.75312199807877034,86.5,61.5,105.5,87.5},
	{84,0.5966796875,-0.0085686089097022633,-0.046109510086455335,0.60622485890970224,0.75312199807877034,61.5,61.5,81.5,87.5},
	{85,0.6484375,0.033656696535782835,-0.046109510086455335,0.61771049096421704,0.75312199807877034,37.5,61.5,56.5,87.5},
	{86,0.63623046875,-0.019532891675672487,-0.046109510086455335,0.65673992292567229,0.75312199807877034,339.5,123.5,361.5,149.5},
	{87,0.88720703125,-0.013341194614553312,-0.046109510086455335,0.9088490071145533,0.75312199807877034,2.5,61.5,32.5,87.5},
	{88,0.626953125,-0.0085575862301873751,-0.046109510086455335,0.63697555498018721,0.75312199807877034,316.5,92.5,337.5,118.5},
	{89,0.6005859375,-0.023450164355187375,-0.046109510086455335,0.62208297685518721,0.75312199807877034,290.5,92.5,311.5,118.5},
	{90,0.5986328125,0.0087543527857828485,-0.046109510086455335,0.59280814721421704,0.75312199807877034,266.5,92.5,285.5,118.5},
	{91,0.26513671875,0.040371384561119106,-0.19980787704130648,0.28628877168888089,0.84534101825168118,78.5,327.5,86.5,361.5},
	{92,0.41015625,-0.019610050432276663,-0.10758885686839577,0.44148505043227659,0.75312199807877034,266.5,254.5,281.5,282.5},
	{93,0.26513671875,-0.041648842759365992,-0.19980787704130648,0.23500821775936601,0.84534101825168118,91.5,327.5,100.5,361.5},
	{94,0.41796875,-0.007169901236791551,0.32276657060518732,0.42318552623679156,0.75312199807877045,347.5,231.5,361.5,245.5},
	{95,0.451171875,-0.035701286323246942,-0.10758885686839577,0.48687316132324676,0.046109510086455335,344.5,51.5,361.5,56.5},
	{96,0.30908203125,-0.0086898583843659921,0.56868395773294911,0.26796720213436598,0.78386167146974062,347.5,219.5,356.5,226.5},
	{97,0.5439453125,0.0099530105517530582,-0.046109510086455335,0.53252745819824676,0.59942363112391928,2.5,35.5,19.5,56.5},
	{98,0.56103515625,0.030704963676753058,-0.046109510086455335,0.55327941132324676,0.78386167146974062,325.5,218.5,342.5,245.5},
	{99,0.5234375,0.0062909011767530582,-0.046109510086455335,0.52886534882324676,0.59942363112391928,57.5,35.5,74.5,56.5},
	{100,0.56396484375,0.0079998855517530582,-0.046109510086455335,0.53057433319824676,0.78386167146974062,2.5,185.5,19.5,212.5},
	{101,0.52978515625,0.0082440261767530582,-0.046109510086455335,0.53081847382324676,0.59942363112391928,192.5,35.5,209.5,56.5},
	{102,0.34716796875,-0.010843033291306439,-0.046109510086455335,0.38877272079130643,0.81460134486071079,286.5,254.5,299.5,282.5},
	{103,0.56103515625,0.0087323074267530582,-0.26128722382324687,0.53130675507324676,0.59942363112391928,304.5,254.5,321.5,282.5},
	{104,0.55078125,0.03020565974723817,-0.046109510086455335,0.52204043400276179,0.78386167146974062,89.5,185.5,105.5,212.5},
	{105,0.24267578125,0.030095432952089329,-0.046109510086455335,0.21453347329791067,0.75312199807877034,279.5,123.5,285.5,149.5},
	{106,0.23876953125,-0.06996915525936602,-0.26128722382324687,0.20668790525936598,0.75312199807877034,268.5,328.5,277.5,361.5},
	{107,0.5068359375,0.026066291801753058,-0.046109510086455335,0.54864073944824676,0.78386167146974062,133.5,185.5,150.5,212.5},
	{108,0.24267578125,0.044488707147574441,-0.046109510086455335,0.19818707410242553,0.78386167146974062,155.5,185.5,160.5,212.5},
	{109,0.87646484375,0.023246831096901954,-0.046109510086455335,0.85321801265309793,0.59942363112391928,160.5,35.5,187.5,56.5},
	{110,0.5517578125,0.03020565974723817,-0.046109510086455335,0.52204043400276179,0.59942363112391928,139.5,35.5,155.5,56.5},
	{111,0.5703125,0.0082550488562679603,-0.046109510086455335,0.56156916989373196,0.59942363112391928,116.5,35.5,134.5,56.5},
	{112,0.56103515625,0.030216682426753058,-0.26128722382324687,0.55279113007324676,0.59942363112391928,326.5,254.5,343.5,282.5},
	{113,0.568359375,0.0077557449267530582,-0.26128722382324687,0.53033019257324676,0.59942363112391928,2.5,217.5,19.5,245.5},
	{114,0.33837890625,0.026976718224663777,-0.046109510086455335,0.3651131255253362,0.59942363112391928,100.5,35.5,111.5,56.5},
	{115,0.515625,0.01043026912223817,-0.046109510086455335,0.50226504337776179,0.59942363112391928,79.5,35.5,95.5,56.5},
	{116,0.32666015625,-0.036244680970821327,-0.046109510086455335,0.33263139972082134,0.69164265129682989,274.5,63.5,286.5,87.5},
	{117,0.55126953125,0.02849667537223817,-0.046109510086455335,0.52033144962776179,0.56868395773294911,2.5,10.5,18.5,30.5},
	{118,0.484375,-0.020320426948246942,-0.046109510086455335,0.50225402069824676,0.56868395773294911,322.5,36.5,339.5,56.5},
	{119,0.75146484375,-0.02510403533261292,-0.046109510086455335,0.77412747283261274,0.56868395773294911,291.5,36.5,317.5,56.5},
	{120,0.49560546875,-0.014461051948246942,-0.046109510086455335,0.50811339569824676,0.56868395773294911,269.5,36.5,286.5,56.5},
	{121,0.47314453125,-0.025447380073246942,-0.26128722382324687,0.49712706757324676,0.56868395773294911,187.5,185.5,204.5,212.5},
	{122,0.49560546875,0.0067681597472381699,-0.046109510086455335,0.49860293400276173,0.56868395773294911,214.5,36.5,230.5,56.5},
	{123,0.33837890625,-0.0052388215958213274,-0.2305475504322767,0.36363725909582134,0.8146013448607109,105.5,327.5,117.5,361.5},
	{124,0.24365234375,0.044976988397574441,-0.1690682036503362,0.19867535535242553,0.75312199807877034,204.5,252.5,209.5,282.5},
	{125,0.33837890625,-0.026967337220821327,-0.2305475504322767,0.34190874347082134,0.8146013448607109,122.5,327.5,134.5,361.5},
	{126,0.68017578125,0.032935297340297723,0.13832853025936598,0.64772876515970212,0.44572526416906821,341.5,77.5,361.5,87.5},
	{160,0.24755859375,0,0,0,0,0,0,0,0},
	{161,0.24365234375,0.029118870452089329,-0.2305475504322767,0.21355691079791067,0.568683957732949,135.5,154.5,141.5,180.5},
	{162,0.546875,0.012638557426753058,-0.1690682036503362,0.53521300507324676,0.69164265129682989,69.5,217.5,86.5,245.5},
	{163,0.5810546875,0.0055805246607828485,-0.046109510086455335,0.58963431908921704,0.75312199807877034,73.5,154.5,92.5,180.5},
	{164,0.712890625,0.0068453185038424014,-0.046109510086455335,0.71385780649615749,0.66090297790585972,291.5,64.5,314.5,87.5},
	{165,0.52490234375,-0.029575725339217152,-0.046109510086455335,0.55447806908921704,0.75312199807877034,24.5,154.5,43.5,180.5},
	{166,0.23974609375,0.040338316522574441,-0.1690682036503362,0.19403668347742553,0.75312199807877034,214.5,252.5,219.5,282.5},
	{167,0.61328125,0.0094867746607828485,-0.2920268972142171,0.59354056908921704,0.75312199807877045,139.5,327.5,158.5,361.5},
	{168,0.41796875,0.0079557948336935608,0.56868395773294911,0.40757154891630643,0.75312199807877045,348.5,276.5,361.5,282.5},
	{169,0.78564453125,0.0066232232378721778,-0.046109510086455335,0.77511505801212766,0.75312199807877034,320.5,186.5,345.5,212.5},
	{170,0.44677734375,0.027242904208693561,0.2920268972142171,0.42685865829130643,0.75312199807877034,348.5,256.5,361.5,271.5},
	{171,0.46923828125,0.0062688558177232817,0.015369836695485105,0.46736395668227659,0.50720461095100866,146.5,14.5,161.5,30.5},
	{172,0.5537109375,0.01897519099723817,0.13832853025936598,0.51080996525276179,0.44572526416906821,284.5,20.5,300.5,30.5},
	{173,0.27587890625,-0.016491335704851104,0.23054755043227665,0.29090539820485112,0.38424591738712777,351.5,346.5,361.5,351.5},
	{174,0.7861328125,0.0061349419878721778,-0.046109510086455335,0.77462677676212766,0.75312199807877034,265.5,154.5,290.5,180.5},
	{175,0.4580078125,0.033590560458693561,0.59942363112391928,0.43320631454130643,0.75312199807877045,316.5,25.5,329.5,30.5},
	{176,0.37353515625,0.017943515099663777,0.41498559077809793,0.3560799224003362,0.75312199807877045,256.5,19.5,267.5,30.5},
	{177,0.5341796875,0.0097088699267530582,-0.046109510086455335,0.53228331757324676,0.66090297790585972,319.5,64.5,336.5,87.5},
	{178,0.36669921875,-0.0015767122208213274,0.2920268972142171,0.36729936847082134,0.75312199807877034,187.5,15.5,199.5,30.5},
	{179,0.36669921875,-0.0067036653458213274,0.26128722382324687,0.36217241534582134,0.75312199807877045,129.5,14.5,141.5,30.5},
	{180,0.3134765625,0.023536704115634008,0.56868395773294911,0.30019376463436598,0.78386167146974062,341.5,65.5,350.5,72.5},
	{181,0.56640625,0.03728573787223817,-0.26128722382324687,0.52912051212776179,0.56868395773294911,68.5,185.5,84.5,212.5},
	{182,0.48876953125,-0.011065128557276663,-0.046109510086455335,0.45002997230727659,0.75312199807877034,2.5,92.5,17.5,118.5},
	{183,0.2607421875,0.035710667327089329,0.26128722382324687,0.22014870767291067,0.44572526416906821,305.5,24.5,311.5,30.5},
	{184,0.24755859375,0.024735361881604224,-0.26128722382324687,0.23991307561839578,0.046109510086455363,344.5,36.5,351.5,46.5},
	{185,0.36669921875,0.02767607206111912,0.2920268972142171,0.27359345918888089,0.75312199807877034,222.5,15.5,230.5,30.5},
	{186,0.45458984375,0.026998763583693561,0.2920268972142171,0.42661451766630643,0.75312199807877034,204.5,15.5,217.5,30.5},
	{187,0.46875,0.011151668317723282,0.015369836695485105,0.47224676918227659,0.50720461095100866,109.5,14.5,124.5,30.5},
	{188,0.732421875,-0.00022373694164271041,-0.046109510086455335,0.73752842444164257,0.75312199807877034,207.5,92.5,231.5,118.5},
	{189,0.77587890625,-0.0031424017621278222,-0.046109510086455335,0.76534943301212766,0.75312199807877034,236.5,92.5,261.5,118.5},
	{190,0.77783203125,0.013215020112872178,-0.046109510086455335,0.78170685488712766,0.75312199807877034,198.5,123.5,223.5,149.5},
	{191,0.47314453125,-0.01251894962776183,-0.2305475504322767,0.47931582462776173,0.568683957732949,244.5,154.5,260.5,180.5},
	{192,0.65234375,-0.027090228371157599,-0.046109510086455335,0.67992225962115749,0.93756003842459168,69.5,288.5,92.5,320.5},
	{193,0.65234375,-0.027090228371157599,-0.046109510086455335,0.67992225962115749,0.93756003842459168,97.5,288.5,120.5,320.5},
	{194,0.65234375,-0.027090228371157599,-0.046109510086455335,0.67992225962115749,0.93756003842459168,125.5,288.5,148.5,320.5},
	{195,0.65234375,-0.027090228371157599,-0.046109510086455335,0.67992225962115749,0.93756003842459168,153.5,288.5,176.5,320.5},
	{196,0.65234375,-0.027090228371157599,-0.046109510086455335,0.67992225962115749,0.90682036503362151,124.5,251.5,147.5,282.5},
	{197,0.65234375,-0.027090228371157599,-0.046109510086455335,0.67992225962115749,0.99903938520653224,163.5,327.5,186.5,361.5},
	{198,0.9345703125,-0.051882345326008647,-0.046109510086455335,0.96252687657600855,0.75312199807877034,97.5,154.5,130.5,180.5},
	{199,0.65087890625,0.024390375465297737,-0.26128722382324687,0.63918384328470224,0.75312199807877034,282.5,328.5,302.5,361.5},
	{200,0.568359375,0.047062385551753058,-0.046109510086455335,0.56963683319824676,0.96829971181556185,307.5,328.5,324.5,361.5},
	{201,0.568359375,0.047062385551753058,-0.046109510086455335,0.56963683319824676,0.96829971181556185,329.5,328.5,346.5,361.5},
	{202,0.568359375,0.047062385551753058,-0.046109510086455335,0.56963683319824676,0.96829971181556185,2.5,287.5,19.5,320.5},
	{203,0.568359375,0.047062385551753058,-0.046109510086455335,0.56963683319824676,0.93756003842459168,181.5,288.5,198.5,320.5},
	{204,0.27197265625,-0.05214688963436602,-0.046109510086455335,0.22451017088436598,0.96829971181556185,24.5,287.5,33.5,320.5},
	{205,0.27197265625,0.049415610365633994,-0.046109510086455335,0.32607267088436598,0.96829971181556185,38.5,287.5,47.5,320.5},
	{206,0.27197265625,-0.047963430970821341,-0.046109510086455335,0.32091264972082134,0.96829971181556185,52.5,287.5,64.5,320.5},
	{207,0.27197265625,-0.062356705166306439,-0.046109510086455335,0.33725904891630643,0.93756003842459168,203.5,288.5,216.5,320.5},
	{208,0.67041015625,-0.030763360425672487,-0.046109510086455335,0.64550945417567229,0.75312199807877034,295.5,154.5,317.5,180.5},
	{209,0.712890625,0.048316156715297723,-0.046109510086455335,0.66310962453470224,0.93756003842459168,221.5,288.5,241.5,320.5},
	{210,0.6875,0.020739288769812625,-0.046109510086455335,0.66627242998018721,0.93756003842459168,246.5,288.5,267.5,320.5},
	{211,0.6875,0.020739288769812625,-0.046109510086455335,0.66627242998018721,0.93756003842459168,272.5,288.5,293.5,320.5},
	{212,0.6875,0.020739288769812625,-0.046109510086455335,0.66627242998018721,0.93756003842459168,298.5,288.5,319.5,320.5},
	{213,0.6875,0.020739288769812625,-0.046109510086455335,0.66627242998018721,0.93756003842459168,324.5,288.5,345.5,320.5},
	{214,0.6875,0.020739288769812625,-0.046109510086455335,0.66627242998018721,0.90682036503362151,152.5,251.5,173.5,282.5},
	{215,0.533203125,0.0018963699267530582,0.046109510086455321,0.52447081757324676,0.59942363112391939,46.5,12.5,63.5,30.5},
	{216,0.6875,0.025622101269812625,-0.076849183477425573,0.67115524248018721,0.78386167146974062,113.5,217.5,134.5,245.5},
	{217,0.6484375,0.033656696535782835,-0.046109510086455335,0.61771049096421704,0.93756003842459168,76.5,250.5,95.5,282.5},
	{218,0.6484375,0.033656696535782835,-0.046109510086455335,0.61771049096421704,0.93756003842459168,52.5,250.5,71.5,282.5},
	{219,0.6484375,0.033656696535782835,-0.046109510086455335,0.61771049096421704,0.93756003842459168,28.5,250.5,47.5,282.5},
	{220,0.6484375,0.033656696535782835,-0.046109510086455335,0.61771049096421704,0.90682036503362151,100.5,251.5,119.5,282.5},
	{221,0.6005859375,-0.023450164355187375,-0.046109510086455335,0.62208297685518721,0.93756003842459168,2.5,250.5,23.5,282.5},
	{222,0.5908203125,0.036575361356267946,-0.046109510086455335,0.58988948239373196,0.75312199807877034,134.5,61.5,152.5,87.5},
	{223,0.5947265625,0.033157392606267946,-0.046109510086455335,0.58647151364373196,0.81460134486071079,24.5,217.5,42.5,245.5},
	{224,0.5439453125,0.0099530105517530582,-0.046109510086455335,0.53252745819824676,0.78386167146974062,265.5,185.5,282.5,212.5},
	{225,0.5439453125,0.0099530105517530582,-0.046109510086455335,0.53252745819824676,0.78386167146974062,176.5,218.5,193.5,245.5},
	{226,0.5439453125,0.0099530105517530582,-0.046109510086455335,0.53252745819824676,0.78386167146974062,282.5,218.5,299.5,245.5},
	{227,0.5439453125,0.0099530105517530582,-0.046109510086455335,0.53252745819824676,0.78386167146974062,287.5,185.5,304.5,212.5},
	{228,0.5439453125,0.0099530105517530582,-0.046109510086455335,0.53252745819824676,0.75312199807877034,2.5,154.5,19.5,180.5},
	{229,0.5439453125,0.0099530105517530582,-0.046109510086455335,0.53252745819824676,0.84534101825168106,224.5,253.5,241.5,282.5},
	{230,0.84423828125,-0.0060390212235831436,-0.046109510086455335,0.85467183372358302,0.59942363112391928,24.5,35.5,52.5,56.5},
	{231,0.5234375,0.0062909011767530582,-0.26128722382324687,0.52886534882324676,0.59942363112391928,91.5,217.5,108.5,245.5},
	{232,0.52978515625,0.0082440261767530582,-0.046109510086455335,0.53081847382324676,0.78386167146974062,24.5,185.5,41.5,212.5},
	{233,0.52978515625,0.0082440261767530582,-0.046109510086455335,0.53081847382324676,0.78386167146974062,46.5,185.5,63.5,212.5},
	{234,0.52978515625,0.0082440261767530582,-0.046109510086455335,0.53081847382324676,0.78386167146974062,165.5,185.5,182.5,212.5},
	{235,0.52978515625,0.0082440261767530582,-0.046109510086455335,0.53081847382324676,0.75312199807877034,116.5,92.5,133.5,118.5},
	{236,0.2470703125,-0.06484220213436602,-0.046109510086455335,0.21181485838436598,0.78386167146974062,139.5,218.5,148.5,245.5},
	{237,0.2470703125,0.036720297865633994,-0.046109510086455335,0.31337735838436598,0.78386167146974062,230.5,185.5,239.5,212.5},
	{238,0.2470703125,-0.060658743470821327,-0.046109510086455335,0.30821733722082134,0.78386167146974062,221.5,218.5,233.5,245.5},
	{239,0.2470703125,-0.075052017666306439,-0.046109510086455335,0.32456373641630643,0.75312199807877034,93.5,123.5,106.5,149.5},
	{240,0.5859375,0.030460823051753058,-0.046109510086455335,0.55303527069824676,0.81460134486071079,47.5,217.5,64.5,245.5},
	{241,0.5517578125,0.03020565974723817,-0.046109510086455335,0.52204043400276179,0.78386167146974062,244.5,185.5,260.5,212.5},
	{242,0.5703125,0.0082550488562679603,-0.046109510086455335,0.56156916989373196,0.78386167146974062,110.5,185.5,128.5,212.5},
	{243,0.5703125,0.0082550488562679603,-0.046109510086455335,0.56156916989373196,0.78386167146974062,238.5,218.5,256.5,245.5},
	{244,0.5703125,0.0082550488562679603,-0.046109510086455335,0.56156916989373196,0.78386167146974062,198.5,218.5,216.5,245.5},
	{245,0.5703125,0.0082550488562679603,-0.046109510086455335,0.56156916989373196,0.78386167146974062,153.5,218.5,171.5,245.5},
	{246,0.5703125,0.0082550488562679603,-0.046109510086455335,0.56156916989373196,0.75312199807877034,200.5,154.5,218.5,180.5},
	{247,0.57080078125,0.0016632519812679603,0.046109510086455321,0.55497737301873196,0.63016330451488956,23.5,11.5,41.5,30.5},
	{248,0.56640625,0.0082550488562679603,-0.10758885686839577,0.56156916989373196,0.63016330451488944,251.5,63.5,269.5,87.5},
	{249,0.55126953125,0.02849667537223817,-0.046109510086455335,0.52033144962776179,0.78386167146974062,209.5,185.5,225.5,212.5},
	{250,0.55126953125,0.02849667537223817,-0.046109510086455335,0.52033144962776179,0.78386167146974062,304.5,218.5,320.5,245.5},
	{251,0.55126953125,0.02849667537223817,-0.046109510086455335,0.52033144962776179,0.78386167146974062,261.5,218.5,277.5,245.5},
	{252,0.55126953125,0.02849667537223817,-0.046109510086455335,0.52033144962776179,0.75312199807877034,223.5,154.5,239.5,180.5},
	{253,0.47314453125,-0.025447380073246942,-0.26128722382324687,0.49712706757324676,0.78386167146974073,56.5,327.5,73.5,361.5},
	{254,0.576171875,0.034611213676753058,-0.26128722382324687,0.55718566132324676,0.78386167146974073,34.5,327.5,51.5,361.5},
	{255,0.47314453125,-0.025447380073246942,-0.26128722382324687,0.49712706757324676,0.75312199807877034,213.5,328.5,230.5,361.5},
}

DEFAULT_FONT_IMAGE :: #load("font.png", []u8)
