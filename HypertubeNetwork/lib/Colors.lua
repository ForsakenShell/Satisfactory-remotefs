-- Colors!

local Color = require( "/lib/Colors.lua", ____RemoteCommonLib )



Color.ORANGE_SIGN_HIGH      = Color.new( 0.783538                       , 0.296138                       , 0.059511                       , 1.0 )
Color.ORANGE_SIGN_LOW       = Color.new( Color.ORANGE_SIGN_HIGH.r * 0.25, Color.ORANGE_SIGN_HIGH.g * 0.25, Color.ORANGE_SIGN_HIGH.b * 0.25, 1.0 )
Color.ORANGE_BUTTON_HIGH    = Color.new( Color.ORANGE_SIGN_HIGH.r       , Color.ORANGE_SIGN_HIGH.g       , Color.ORANGE_SIGN_HIGH.b       , 0.5 )
Color.ORANGE_BUTTON_LOW     = Color.new( Color.ORANGE_SIGN_LOW .r       , Color.ORANGE_SIGN_LOW .g       , Color.ORANGE_SIGN_LOW .b       , 0.0 )

Color.RED_SIGN_HIGH         = Color.new( 0.496933                       , 0.021219                       , 0.021219                       , 1.0 )
Color.RED_SIGN_LOW          = Color.new( Color.RED_SIGN_HIGH.r * 0.25   , Color.RED_SIGN_HIGH.g * 0.25   , Color.RED_SIGN_HIGH.b * 0.25   , 1.0 )
Color.RED_BUTTON_HIGH       = Color.new( Color.RED_SIGN_HIGH.r          , Color.RED_SIGN_HIGH.g          , Color.RED_SIGN_HIGH.b          , 0.5 )
Color.RED_BUTTON_LOW        = Color.new( Color.RED_SIGN_LOW .r          , Color.RED_SIGN_LOW .g          , Color.RED_SIGN_LOW .b          , 0.0 )

Color.GREEN_SIGN_HIGH       = Color.new( 0.102242                       , 0.473531                       , 0.012983                       , 1.0 )
Color.GREEN_SIGN_LOW        = Color.new( Color.GREEN_SIGN_HIGH.r * 0.25 , Color.GREEN_SIGN_HIGH.g * 0.25 , Color.GREEN_SIGN_HIGH.b * 0.25 , 1.0 )
Color.GREEN_BUTTON_HIGH     = Color.new( Color.GREEN_SIGN_HIGH.r        , Color.GREEN_SIGN_HIGH.g        , Color.GREEN_SIGN_HIGH.b        , 0.5 )
Color.GREEN_BUTTON_LOW      = Color.new( Color.GREEN_SIGN_LOW .r        , Color.GREEN_SIGN_LOW .g        , Color.GREEN_SIGN_LOW .b        , 0.0 )

Color.BLUE_SIGN_HIGH        = Color.new( 0.000000                       , 0.025136                       , 0.494350                       , 1.0 )
Color.BLUE_SIGN_LOW         = Color.new( Color.BLUE_SIGN_HIGH.r * 0.25  , Color.BLUE_SIGN_HIGH.g * 0.25  , Color.BLUE_SIGN_HIGH.b * 0.25  , 1.0 )
Color.BLUE_BUTTON_HIGH      = Color.new( Color.BLUE_SIGN_HIGH.r         , Color.BLUE_SIGN_HIGH.g         , Color.BLUE_SIGN_HIGH.b         , 0.5 )
Color.BLUE_BUTTON_LOW       = Color.new( Color.BLUE_SIGN_LOW .r         , Color.BLUE_SIGN_LOW .g         , Color.BLUE_SIGN_LOW .b         , 0.0 )

Color.CYAN_SIGN_HIGH        = Color.new( 0.109804                       , 0.427451                       , 0.564706                       , 1.0 )
Color.CYAN_SIGN_LOW         = Color.new( Color.CYAN_SIGN_HIGH.r * 0.25  , Color.CYAN_SIGN_HIGH.g * 0.25  , Color.CYAN_SIGN_HIGH.b * 0.25  , 1.0 )
Color.CYAN_BUTTON_HIGH      = Color.new( Color.CYAN_SIGN_HIGH.r         , Color.CYAN_SIGN_HIGH.g         , Color.CYAN_SIGN_HIGH.b         , 0.5 )
Color.CYAN_BUTTON_LOW       = Color.new( Color.CYAN_SIGN_LOW.r          , Color.CYAN_SIGN_LOW.g          , Color.CYAN_SIGN_LOW.b          , 0.0 )

Color.CYAN_SIGN_BACKGROUND  = Color.new( 0.109804                       , 0.427451                       , 0.564706                       , 1.0 )
Color.YELLOW_SIGN_BRDRTEXT  = Color.new( 0.496933                       , 0.021219                       , 0.021219                       , 1.0 )



return Color