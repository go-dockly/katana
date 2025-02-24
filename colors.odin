package vgo

Gray :: proc(shade: f32) -> Color {return{
		u8(shade * 255.0),
		u8(shade * 255.0),
		u8(shade * 255.0),
		255,
	}}

BlenderGray :: Color{135, 136, 136, 255}
BlenderDarkGray :: Color{58, 58, 58, 255}
BlenderWire :: Color{78, 78, 78, 255}

// CSS 1 Colors
White :: Color{ 255, 255, 255, 255}
Silver :: Color{ 192, 192, 192, 255}
Black :: Color{ 0, 0, 0, 255}
Red :: Color{ 255, 0, 0, 255}
Maroon :: Color{ 128, 0, 0, 255}
Lime :: Color{ 0, 255, 0, 255}
Green :: Color{ 0, 128, 0, 255}
Blue :: Color{ 0, 0, 255, 255}
DeepBlue :: Color{0, 0, 255, 255}
Navy :: Color{ 0, 0, 128, 255}
Yellow :: Color{ 255, 255, 0, 255}
Orange :: Color{ 255, 165, 0, 255}
Olive :: Color{ 128, 128, 0, 255}
Purple :: Color{ 128, 0, 128, 255}
Fuchsia :: Color{ 255, 0, 255, 255}
Teal :: Color{ 0, 128, 128, 255}
Aqua :: Color{ 0, 255, 255, 255}

// CSS3 colors

// Reds
IndianRed :: Color{ 205, 92, 92, 255}
LightCoral :: Color{ 240, 128, 128, 255}
Salmon :: Color{ 250, 128, 114, 255}
DarkSalmon :: Color{ 233, 150, 122, 255}
LightSalmon :: Color{ 255, 160, 122, 255}
Crimson :: Color{ 220, 20, 60, 255}
FireBrick :: Color{ 178, 34, 34, 255}
DarkRed :: Color{ 139, 0, 0, 255}                                         

// Pinks 
Pink :: Color{ 255, 192, 203, 255}
LightPink :: Color{ 255, 182, 193, 255}
HotPink :: Color{ 255, 105, 180, 255}
DeepPink :: Color{ 255, 20, 147, 255}
MediumVioletRed :: Color{ 199, 21, 133, 255}
PaleVioletRed :: Color{ 219, 112, 147, 255}

// Oranges
Coral :: Color{ 255, 127, 80, 255}
Tomato :: Color{ 255, 99, 71, 255}
OrangeRed :: Color{ 255, 69, 0, 255}
DarkOrange :: Color{ 255, 140, 0, 255}       

// Yellows           
Gold :: Color{ 255, 215, 0, 255}
LightYellow :: Color{ 255, 255, 224, 255}
LemonChiffon :: Color{ 255, 250, 205, 255}
LightGoldenrodYellow :: Color{ 250, 250, 210, 255}
PapayaWhip :: Color{ 255, 239, 213, 255}
Moccasin :: Color{ 255, 228, 181, 255}
PeachPuff :: Color{ 255, 218, 185, 255}
PaleGoldenrod :: Color{ 238, 232, 170, 255}
Khaki :: Color{ 240, 230, 140, 255}
DarkKhaki :: Color{ 189, 183, 107, 255}

// Purples   
Lavender :: Color{ 230, 230, 250, 255}
Thistle :: Color{ 216, 191, 216, 255}
Plum :: Color{ 221, 160, 221, 255}
Violet :: Color{ 238, 130, 238, 255}
Orchid :: Color{ 218, 112, 214, 255}
Magenta :: Color{ 255, 0, 255, 255}
MediumOrchid :: Color{ 186, 85, 211, 255}
MediumPurple :: Color{ 147, 112, 219, 255}
BlueViolet :: Color{ 138, 43, 226, 255}
DarkViolet :: Color{ 148, 0, 211, 255}
DarkOrchid :: Color{ 153, 50, 204, 255}
DarkMagenta :: Color{ 139, 0, 139, 255}
RebeccaPurple :: Color{ 102, 51, 153, 255}
Indigo :: Color{ 75, 0, 130, 255}
MediumSlateBlue :: Color{ 123, 104, 238, 255}
SlateBlue :: Color{ 106, 90, 205, 255}
DarkSlateBlue :: Color{ 72, 61, 139, 255}

// Greens
GreenYellow :: Color{ 173, 255, 47, 255}
Chartreuse :: Color{ 127, 255, 0, 255}
LawnGreen :: Color{ 124, 252, 0, 255}
LimeGreen :: Color{ 50, 205, 50, 255}
PaleGreen :: Color{ 152, 251, 152, 255}                                
LightGreen :: Color{ 144, 238, 144, 255}
MediumSpringGreen :: Color{ 0, 250, 154, 255}
SpringGreen :: Color{ 0, 255, 127, 255}
MediumSeaGreen :: Color{ 60, 179, 113, 255}
SeaGreen :: Color{ 46, 139, 87, 255}
ForestGreen :: Color{ 34, 139, 34, 255}
DarkGreen :: Color{ 0, 100, 0, 255}
YellowGreen :: Color{ 154, 205, 50, 255}
OliveDrab :: Color{ 107, 142, 35, 255}
DarkOliveGreen :: Color{ 85, 107, 47, 255}
MediumAquamarine :: Color{ 102, 205, 170, 255}
DarkSeaGreen :: Color{ 143, 188, 143, 255}
LightSeaGreen :: Color{ 32, 178, 170, 255}
DarkCyan :: Color{ 0, 139, 139, 255}

// Blues            
Cyan :: Color{ 0, 255, 255, 255}
LightCyan :: Color{ 224, 255, 255, 255}
PaleTurquoise :: Color{ 175, 238, 238, 255}
Aquamarine :: Color{ 127, 255, 212, 255}
Turquoise :: Color{ 64, 224, 208, 255}
MediumTurquoise :: Color{ 72, 209, 204, 255}
DarkTurquoise :: Color{ 0, 206, 209, 255}
CadetBlue :: Color{ 95, 158, 160, 255}
SteelBlue :: Color{ 70, 130, 180, 255}
LightSteelBlue :: Color{ 176, 196, 222, 255}
PowderBlue :: Color{ 176, 224, 230, 255}
LightBlue :: Color{ 173, 216, 230, 255}
SkyBlue :: Color{ 135, 206, 235, 255}
LightSkyBlue :: Color{ 135, 206, 250, 255}
DeepSkyBlue :: Color{ 0, 191, 255, 255}
DodgerBlue :: Color{ 30, 144, 255, 255}
CornflowerBlue :: Color{ 100, 149, 237, 255}
RoyalBlue :: Color{ 65, 105, 225, 255}
MediumBlue :: Color{ 0, 0, 205, 255}
DarkBlue :: Color{ 0, 0, 139, 255}
MidnightBlue :: Color{ 25, 25, 112, 255}

// Browns       
Cornsilk :: Color{ 255, 248, 220, 255}
BlanchedAlmond :: Color{ 255, 235, 205, 255}
Bisque :: Color{ 255, 228, 196, 255}
NavajoWhite :: Color{ 255, 222, 173, 255}
Wheat :: Color{ 245, 222, 179, 255}                                 
BurlyWood :: Color{ 222, 184, 135, 255}
Tan :: Color{ 210, 180, 140, 255}
RosyBrown :: Color{ 188, 143, 143, 255}
SandyBrown :: Color{ 244, 164, 96, 255}
Goldenrod :: Color{ 218, 165, 32, 255}
DarkGoldenrod :: Color{ 184, 134, 11, 255}
Peru :: Color{ 205, 133, 63, 255}
Chocolate :: Color{ 210, 105, 30, 255}
SaddleBrown :: Color{ 139, 69, 19, 255}
Sienna :: Color{ 160, 82, 45, 255}
Brown :: Color{ 165, 42, 42, 255}

// Whites
Snow :: Color{ 255, 250, 250, 255}
Honeydew :: Color{ 240, 255, 240, 255}
MintCream :: Color{ 245, 255, 250, 255}
Azure :: Color{ 240, 255, 255, 255}
AliceBlue :: Color{ 240, 248, 255, 255}
GhostWhite :: Color{ 248, 248, 255, 255}
WhiteSmoke :: Color{ 245, 245, 245, 255}
Seashell :: Color{ 255, 245, 238, 255}
Beige :: Color{ 245, 245, 220, 255}
OldLace :: Color{ 253, 245, 230, 255}
FloralWhite :: Color{ 255, 250, 240, 255}
Ivory :: Color{ 255, 255, 240, 255}
AntiqueWhite :: Color{ 250, 235, 215, 255}
Linen :: Color{ 250, 240, 230, 255}
LavenderBlush :: Color{ 255, 240, 245, 255}
MistyRose :: Color{ 255, 228, 225, 255}

// Grays
Gainsboro :: Color{ 220, 220, 220, 255}
LightGray :: Color{ 211, 211, 211, 255}
LightGrey :: Color{ 211, 211, 211, 255}
DarkGray :: Color{ 169, 169, 169, 255}
Grey :: Color{ 128, 128, 128, 255}                                     
DimGray :: Color{ 105, 105, 105, 255}
LightSlateGray :: Color{ 119, 136, 153, 255}
SlateGray :: Color{ 112, 128, 144, 255}
DarkSlateGray :: Color{ 47, 79, 79, 255}

