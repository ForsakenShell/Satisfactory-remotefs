--[[
    
    RSSBuilder
    by 1000101
    March 4, 2023
    Use and abuse, just drop my online handle (1000101) somewhere in the credits for my contribution.
    
    
    
    
    IMPORTANT NOTE:
    
    The generated sign import strings will have mZIndex of all elements counting down
    from the last element index to 0.  This is due to the RSS Sign Builder re-indexing
    all elements when pasting based on their mZIndex.  To preserve the intended order,
    the import string is therefore generated with mZIndexes in this descending eIndex
    order.  Once the import string has been pasted onto the sign with the RSS Sign
    Builder, SignLayout:apply() can be called on the sign to insure the
    elements are properly scaled to the sign itself as well as setting the correct
    mZIndex of all elements.
    
]]




----------------------------------------------------------------
-- Requirements


local Color = require( "/lib/Colors.lua", ____RemoteCommonLib )
local Vector2d = require( "/lib/Vector2d.lua", ____RemoteCommonLib )
local Vector2f = require( "/lib/Vector2f.lua", ____RemoteCommonLib )
local Vector4F = require( "/lib/Vector4F.lua", ____RemoteCommonLib )

local ClassMeta = require( "/lib/ClassMeta.lua", ____RemoteCommonLib )




----------------------------------------------------------------


---Round a number
---@param a number
local function round( a )
    return math.floor( a + 0.5 )
end




----------------------------------------------------------------


local function unpackSerializeFieldMetaExtra( ... )
    local extra = { ... }
    local scale = extra[ 1 ]
    local eIndex = extra[ 2 ]
    local lIndex = extra[ 3 ]
    return scale, eIndex, lIndex
end


local function unpackApplyFieldMetaExtra( ... )
    local extra = { ... }
    local scale = extra[ 1 ]
    local eIndex = extra[ 2 ]
    local sign = extra[ 3 ]
    return scale, eIndex, sign
end


local function FieldMeta_Serialize_Scaled_Integer( meta, value, ... )
    local pattern = meta.pattern or ClassMeta.FieldMeta.Common.Pattern_Integer
    local scale, eIndex, lIndex = unpackSerializeFieldMetaExtra( ... )
    return string.format( pattern, meta.name, round( value * scale ) )
end

local function FieldMeta_Serialize_Scaled_Number( meta, value, ... )
    local pattern = meta.pattern or ClassMeta.FieldMeta.Common.Pattern_Number
    local scale, eIndex, lIndex = unpackSerializeFieldMetaExtra( ... )
    return string.format( pattern, meta.name, value * scale )
end

local function FieldMeta_Serialize_Scaled_Vector2d( meta, value, ... )
    local pattern = meta.pattern or ClassMeta.FieldMeta.Common.Pattern_Vector2d
    local scale, eIndex, lIndex = unpackSerializeFieldMetaExtra( ... )
    return string.format( pattern, meta.name, round( value.x * scale ), round( value.y * scale ) )
end

local function FieldMeta_Serialize_Scaled_Vector2f( meta, value, ... )
    local pattern = meta.pattern or ClassMeta.FieldMeta.Common.Pattern_Vector2f
    local scale, eIndex, lIndex = unpackSerializeFieldMetaExtra( ... )
    return string.format( pattern, meta.name, value.x * scale, value.y * scale )
end

local function FieldMeta_Serialize_Scaled_Vector3f( meta, value, ... )
    local pattern = meta.pattern or ClassMeta.FieldMeta.Common.Pattern_Vector3f
    local scale, eIndex, lIndex = unpackSerializeFieldMetaExtra( ... )
    return string.format( pattern, meta.name, value.x * scale, value.y * scale, value.z * scale )
end

local function FieldMeta_Serialize_Scaled_Vector4F( meta, value, ... )
    local pattern = meta.pattern or ClassMeta.FieldMeta.Common.Pattern_Vector4F
    local scale, eIndex, lIndex = unpackSerializeFieldMetaExtra( ... )
    return string.format( pattern, meta.name, value.X * scale, value.Y * scale, value.Z * scale, value.W * scale )
end




----------------------------------------------------------------
local DefaultTextBackgroundColor = Color.new( 0.067708, 0.067708, 0.067708, 1.000000 )
local DefaultTextPadding = Vector4F.new( 20, 10, 20, 10 )
local DefaultTextJustify = 2
local DefaultTextFont = 0

local DefaultImageSize = Vector2f.new( 1.0, 0.0 )   -- Image size is actually X = Zoom, Y = Fill sign (0.0 = false, 1.0 = true)




----------------------------------------------------------------
-- The main RSSBuilder class


---@class RSSBuilder:table
---@field Text table
---@field Text.Type.Normal integer Default
---@field Text.Type.Background integer
---@field Text.Justification enumeration
---@field Text.Justification.Left integer
---@field Text.Justification.Middle integer Default
---@field Text.Justification.Right integer
---@field Text.Font enumeration
---@field Text.Font.Allan integer
---@field Text.Font.Amatic integer
---@field Text.Font.Antonio integer
---@field Text.Font.CourierPrime integer
---@field Text.Font.OpenSans integer Default
---@field Text.Font.Orbitron integer
---@field Text.Font.Rajdhani integer
---@field Text.Font.Roboto integer
---@field Text.BackgroundColor Color Default
---@field Text.Padding Vector4F Default
---@field Sign table
---@field Sign.Type enumeration
---@field Sign.Size enumeration
---@field Sign.Class enumeration
---@field SignLayout SignLayout
---@field SignLayout.HologramData HologramData
---@field SignLayout.FlatData FlatData
---@field SignLayout.MaterialData MaterialData
---@field SignLayout.ElementData ElementData
---@field SignLayout.ElementData.SharedData SharedData
---@field SignLayout.ElementData.TextData TextData
---@field SignLayout.ElementData.ImageData ImageData
local RSSBuilder = {
    Text = {
        Type = {
            Normal = 0,
            Background = 1,
        },
        Justification = {
            Left = 0,
            Middle = 1,
            Right = 2,
        },
        Font = {
            Allan = 1,
            Amatic = 2,
            Antonio = 3,
            CourierPrime = 4,
            OpenSans = 0,
            Orbitron = 5,
            Rajdhani = 6,
            Roboto = 7,
        },
        BackgroundColor = DefaultTextBackgroundColor,
        Padding = DefaultTextPadding,
    },
    Sign = {
        Type = {
            -- Maps:
            --  Type[ id:integer ] -> import:string, eg: RSS_Normal
            --  Type[ Name:string ] -> import:string, eg: RSS_Normal
            -- Functions:
            --  Type.GetDataByID( id:integer ):SignType
            --  Type.GetDataByType( type:string ):SignType
            --  Type.GetDataByImport( import:string ):SignType
        },
        Size = {
            -- Maps:
            --  Size[ size:string ] -> import:string, eg: RSS_1x1
            -- Functions:
            --  Size.GetDataBySize( size:string ):SignSize
            --  Size.GetDataByImport( import:string ):SignSize
        },
        Class =  {    -- "classname" is returned by tostring( sign ) where sign is a NetworkComponent proxy
            -- Maps:
            --  Class[ classname:string ] -> classname:string
            -- Functions:
            --  Class.GetSignClassByClassName():SignClass
        },
    },
    SignLayout = {    -- Public API to the template classes
        HologramData = {},
        FlatData = {},
        MaterialData = {},
        ElementData = {
            SharedData = {},
            TextData = {},
            ImageData = {},
        }
    },
}

---@field SignTypes SignType array
---@field SignSizes SignSize array
---@field SignClasses SignClass array
---@field ElementTypes ElementType array
local __internals = {
    DebugMode = true,
    SignTypes = {},
    SignSizes = {},
    SignClasses = {},
    ElementTypes = {},
}




----------------------------------------------------------------
-- enumeration


---@class enumeration table
local enumeration = {}







----------------------------------------------------------------
-- The SharedData table
-- used for import string building


---@class SharedData:table
---@field mElementName string Required: Name
---@field mPosition Vector2f Optional: Position, offset from centre of the sign; default: Vector2f.Zero (centre)
---@field mColourOverwrite Color Optional: Color/tinting; default: Color.WHITE
---@field mZIndex integer Optional: z sorting order; default: 0
---@field mOpacity number Optional: 0.0 = Fully transparent, 1.0 = Fully solid; default: 1.0
---@field mRotation number Optional: Rotation, in degrees; default 0.0
---@field mTexture string Required*: Texture to use for Image/Effect elements; default: nil
---@field mUrl string Optional: url to a custom texture to use for the element, mTexture must still be supplied; default: nil
---@field mIsUsingCustom boolean Required*: if mUrl is not nil then this must be true; default: nil/false
local SharedData = {
    mElementName = '',
    mPosition = nil,
    mColourOverwrite = nil,
    mZIndex = nil,
    mOpacity = 1.0,
    mRotation = nil,
    mTexture = nil,
    mUrl = nil,
    mIsUsingCustom = nil,
}
SharedData.__index = SharedData


local function SharedData_Test_mOpacity( meta, value )
    if value < 0.0 or value > 1.0 then
        return false, string.format( "%s must be in the range of 0.0 to 1.0 - got %1.6f", meta.name, value )
    end
    return true, nil
end


local function SharedData_Import_mZIndex( meta, value, ... )
    local pattern = meta.pattern or ClassMeta.FieldMeta.Common.Pattern_Integer
    local scale, eIndex, lIndex = unpackSerializeFieldMetaExtra( ... )
    return string.format( pattern, meta.name, lIndex - eIndex )
end


local function SharedData_Apply_mZIndex( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetZIndex( value, eIndex )
end

local function SharedData_Apply_mPosition( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetPosition( value, eIndex )
end

local function SharedData_Apply_mColourOverwrite( meta, value, ... )
    value = value or Color.WHITE
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetColor( value, eIndex )
end

local function SharedData_Apply_mOpacity( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetOpacity( value, eIndex )
end


local SharedData_MetaData = ClassMeta.new( {
    metatablename = "SharedData",
    metatable = SharedData,
    fields = {
        ClassMeta.FieldMeta.new( { name = "mElementName", ftype = "string", valuetest = ClassMeta.FieldMeta.Common.Test_String_NotEmpty, serialize = ClassMeta.FieldMeta.Common.Serialize_String, pattern = '%s=INVTEXT("%s")' } ),
        ClassMeta.FieldMeta.new( { name = "mPosition", ftype = "table", allownil = true, metatable = Vector2f, metatablename = "Vector2f", serialize = FieldMeta_Serialize_Scaled_Vector2f, apply = SharedData_Apply_mPosition } ),
        ClassMeta.FieldMeta.new( { name = "mColourOverwrite", ftype = "table", allownil = true, metatable = Color, metatablename = "Color", serialize = ClassMeta.FieldMeta.Common.Serialize_Color, apply = SharedData_Apply_mColourOverwrite } ),
        ClassMeta.FieldMeta.new( { name = "mZIndex", ftype = "number", allownil = true, serialize = SharedData_Import_mZIndex, apply = SharedData_Apply_mZIndex } ),
        ClassMeta.FieldMeta.new( { name = "mOpacity", ftype = "number", allownil = true, valuetest = SharedData_Test_mOpacity, serialize = ClassMeta.FieldMeta.Common.Serialize_Number, apply = SharedData_Apply_mOpacity } ),
        ClassMeta.FieldMeta.new( { name = "mRotation", ftype = "number", allownil = true, serialize = ClassMeta.FieldMeta.Common.Serialize_Number } ),
        ClassMeta.FieldMeta.new( { name = "mTexture", ftype = "string", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_String_NotEmpty, serialize = ClassMeta.FieldMeta.Common.Serialize_String, pattern = '%s=Texture2D\'"%s"\'' } ),
        ClassMeta.FieldMeta.new( { name = "mUrl", ftype = "string", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_String_NotEmpty, serialize = ClassMeta.FieldMeta.Common.Serialize_String, pattern = '%s="%s"' } ),
        ClassMeta.FieldMeta.new( { name = "mIsUsingCustom", ftype = "boolean", allownil = true, serialize = ClassMeta.FieldMeta.Common.Serialize_Boolean, pattern = '%s=%s' } ),
    }
} )



local function FieldMeta_Test_SharedData( meta, value )
    return SharedData_MetaData:isValid( meta.name, value, true )
end


---Create a new SharedData table for the ElementData.mSharedData
---@param o table Table to use initialize SharedData, must pass SharedData_MetaData:isValid( o, false )
---@return SharedData, string SharedData, nil on success; nil, reason on error
function SharedData.new( o )
    if __internals.DebugMode then
        local result, reason = SharedData_MetaData:isValid( 'o', o, false )
        if not result then return nil, reason end
    end
    setmetatable( o, { __index = SharedData } )
    return o, nil
end




----------------------------------------------------------------
-- The TextData table
-- used for import string building


---@class TextData:table
---@field mText string Optional: Text displayed; default = LOCTABLE("/KUI/StringTables/KUI_WidgetWords.KUI_WidgetWords", "RSS_DefaultTextElementText")
---@field mTextType RSSBuilder.Text.Type Optional: How the text should be rendered by the sign; default: RSSBuilder.Text.Type.Normal
---@field mBackgroundColor Color Only used for RSSBuilder.Text.Type.Background: Background color of the text, this includes the padded area; default = { R = 0.067708, G = 0.067708, B = 0.067708, A = 1.000000 }
---@field mIsBold boolean Optional: Render text as bold (if the font supports it); default: false
---@field mIsUppercase boolean Optional: Render text in full uppercase; default: false
---@field mTextSize integer Optional: Font size; default: 30
---@field mLetterSpacing integer Optional: Spacing between text characters, units = ?; default: 0
---@field mLineHeight number Optional: Spacing between lines?, units = ?; default = 1.0
---@field mPadding Vector4F Optional: Padding around mText, units = ?; default = RSSBuilder.Text.DefaultPadding
---@field mTextJustify RSSBuilder.Text.Justification Optional: Text alignment; default = RSSBuilder.Text.Justification.Right
---@field mFont RSSBuilder.Text.Font Optional: Font for text; default: RSSBuilder.Text.Font.OpenSans
local TextData = {
    mText = '',
    mTextType = 0,
    mBackgroundColor = nil,
    mIsBold = nil,
    mIsUppercase = nil,
    mTextSize = 30,
    mLetterSpacing = nil,
    mLineHeight = nil,
    mPadding = nil,
    mTextJustify = DefaultTextJustify,
    mFont = DefaultTextFont,
}
TextData.__index = TextData


local function TextData_Test_mTextType( meta, value )
    if value ~= RSSBuilder.Text.Type.Normal
    and value ~= RSSBuilder.Text.Type.Background then
        return false, string.format( "%s must be a valid RSSBuilder.Text.Type - got %d", meta.name, value )
    end
    return true, nil
end
local function TextData_Test_mTextJustify( meta, value )
    if value < RSSBuilder.Text.Justification.Left
    or value > RSSBuilder.Text.Justification.Right then
        return false, string.format( "%s must be a valid RSSBuilder.Text.Justification - got %d", meta.name, value )
    end
    return true, nil
end
local function TextData_Test_mFont( meta, value )
    if value < RSSBuilder.Text.Font.OpenSans
    or value > RSSBuilder.Text.Font.Roboto then
        return false, string.format( "%s must be a valid RSSBuilder.Text.Justification - got %d", meta.name, value )
    end
    return true, nil
end


local function TextData_Import_mText( meta, value, ... )
    local pattern = meta.pattern
    if value == nil then
        pattern = ClassMeta.FieldMeta.Common.Pattern_String
        value = 'LOCTABLE("/KUI/StringTables/KUI_WidgetWords.KUI_WidgetWords", "RSS_DefaultTextElementText")'
    end
    return string.format( pattern, meta.name, value )
end

local function TextData_Import_mTextType( meta, value, ... )
    local pattern = meta.pattern or ClassMeta.FieldMeta.Common.Pattern_String
    if value ~= RSSBuilder.Text.Type.Background then return nil end
    return string.format( pattern, meta.name, 'BackgroundText' )
end

local function TextData_Import_mTextJustify( meta, value, ... )
    local pattern = meta.pattern or ClassMeta.FieldMeta.Common.Pattern_String
    value = RSSBuilder.Text.Justification.ToString( value )
    if value == nil or value == '' then return nil end
    return string.format( pattern, meta.name, value )
end

local function TextData_Import_mFont( meta, value, ... )
    value = RSSBuilder.Text.Font.ToString( value )
    if value == nil or value == '' then return nil end
    return string.format( meta.pattern, meta.name, value )
end


local function TextData_Apply_mText( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetText( value, eIndex )
end

local function TextData_Apply_mIsBold( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetIsBold( value, eIndex )
end

local function TextData_Apply_mIsUppercase( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetUppercase( value, eIndex )
end

local function TextData_Apply_mTextSize( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetTextSize( value, eIndex )
end

local function TextData_Apply_mTextJustify( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetJustify( value, eIndex )
end


local TextData_MetaData = ClassMeta.new( {
    metatablename = "TextData",
    metatable = TextData,
    allownil = true,
    fields = {
        ClassMeta.FieldMeta.new( { name = "mText", ftype = "string", allownil = true, serialize = TextData_Import_mText, pattern = '%s=INVTEXT("%s")', apply = TextData_Apply_mText } ),
        ClassMeta.FieldMeta.new( { name = "mTextType", ftype = "number", allownil = true, valuetest = TextData_Test_mTextType, serialize = TextData_Import_mTextType } ),
        ClassMeta.FieldMeta.new( { name = "mBackgroundColor", ftype = "table", allownil = true, metatable = Color, metatablename = "Color", serialize = ClassMeta.FieldMeta.Common.Serialize_Color } ),
        ClassMeta.FieldMeta.new( { name = "mIsBold", ftype = "boolean", allownil = true, serialize = ClassMeta.FieldMeta.Common.Serialize_Boolean, apply = TextData_Apply_mIsBold } ),
        ClassMeta.FieldMeta.new( { name = "mIsUppercase", ftype = "boolean", allownil = true, serialize = ClassMeta.FieldMeta.Common.Serialize_Boolean, apply = TextData_Apply_mIsUppercase } ),
        ClassMeta.FieldMeta.new( { name = "mTextSize", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Integer_Positive, serialize = FieldMeta_Serialize_Scaled_Integer, apply = TextData_Apply_mTextSize } ),
        ClassMeta.FieldMeta.new( { name = "mLetterSpacing", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Integer_NotNegative, serialize = FieldMeta_Serialize_Scaled_Integer } ),
        ClassMeta.FieldMeta.new( { name = "mLineHeight", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Number_NotNegative, serialize = FieldMeta_Serialize_Scaled_Number } ),
        ClassMeta.FieldMeta.new( { name = "mPadding", ftype = "table", allownil = true, metatable = Vector4F, metatablename = "Vector4F", serialize = FieldMeta_Serialize_Scaled_Vector4F } ),
        ClassMeta.FieldMeta.new( { name = "mTextJustify", ftype = "number", allownil = true, valuetest = TextData_Test_mTextJustify, serialize = TextData_Import_mTextJustify, apply = TextData_Apply_mTextJustify } ),
        ClassMeta.FieldMeta.new( { name = "mFont", ftype = "number", allownil = true, valuetest = TextData_Test_mFont, serialize = TextData_Import_mFont, pattern = '%s=Font\'"%s"\'' } ),
    }
} )


local function FieldMeta_Test_TextData( meta, value )
    return TextData_MetaData:isValid( meta.name, value, true )
end


---Create a new TextData table for the ElementData.mTextData
---@param o table Table to use initialize TextData, must pass TextData_MetaData:isValid( o, false )
---@return TextData, string TextData, nil on success; nil, reason on error
function TextData.new( o )
    if __internals.DebugMode then
        local result, reason = TextData_MetaData:isValid( 'o', o, false )
        if not result then return nil, reason end
    end
    setmetatable( o, { __index = TextData } )
    return o, nil
end




----------------------------------------------------------------
-- The ImageData table
-- used for import string building


---@class ImageData:table
---@field mImageSize Vector2f Required: Encapsulates Zoom and Fill Sign, X = Zoom, Y = Fill Sign (0.0 = false, 1.0 = true); default = { 1.0, 0.0 }
---@field mScaleMirrow Vector2f Optional: Texture UV coordinate multiplication, rotation comes from mSharedData.mRotation; default: nil; Mirror & Flip = { -1.0, -1.0 } - Note:  RSSImport encodes this as "mScaleMirrow"
---@field mOverwriteImageSize Vector2f Optional: Rescale texture to this pixel size; default = nil (mTexture.size)
---@field mUse9SliceMode Vector2f Optional: Encodes X = true (1.0), false (0.0), Y = 9 Slice Value
local ImageData = {
    mImageSize = DefaultImageSize,
    mScaleMirrow = nil,
    mOverwriteImageSize = nil,
    mUse9SliceMode = nil,
}
ImageData.__index = ImageData


local function ImageData_Apply_mImageSize( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetImageSize( value, eIndex )
end

local function ImageData_Apply_mOverwriteImageSize( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:Element_SetOverwriteImageSize( value, eIndex )
end


local ImageData_MetaData = ClassMeta.new( {
    metatablename = "ImageData",
    metatable = ImageData,
    fields = {
        ClassMeta.FieldMeta.new( { name = "mImageSize", ftype = "table", allownil = true, metatable = Vector2f, metatablename = "Vector2f", serialize = ClassMeta.FieldMeta.Common.Serialize_Vector2f, apply = ImageData_Apply_mImageSize } ), -- This is actually the Zoom and Fill Sign, see mOverwriteImageSize for the ACTUAL image size override
        ClassMeta.FieldMeta.new( { name = "mScaleMirrow", ftype = "table", allownil = true, metatable = Vector2f, metatablename = "Vector2f", serialize = ClassMeta.FieldMeta.Common.Serialize_Vector2f } ),
        ClassMeta.FieldMeta.new( { name = "mOverwriteImageSize", ftype = "table", allownil = true, metatable = Vector2f, metatablename = "Vector2f", serialize = FieldMeta_Serialize_Scaled_Vector2f, apply = ImageData_Apply_mOverwriteImageSize } ),
        ClassMeta.FieldMeta.new( { name = "mUse9SliceMode", ftype = "table", allownil = true, metatable = Vector2f, metatablename = "Vector2f", serialize = ClassMeta.FieldMeta.Common.Serialize_Vector2f } ),
    }
} )


local function FieldMeta_Test_ImageData( meta, value )
    return ImageData_MetaData:isValid( meta.name, value, true )
end


---Create a new ImageData table for the ElementData.mImageData
---@param o table Table to use initialize ImageData, must pass ImageData_MetaData:isValid( o, false )
---@return ImageData, string ImageData, nil on success; nil, reason on error
function ImageData.new( o )
    local result, reason = ImageData_MetaData:isValid( 'o', o, false )
    if not result then return nil, reason end
    setmetatable( o, { __index = ImageData } )
    return o, nil
end




----------------------------------------------------------------
-- The ElementData table
-- used for import string building


---@class ElementData:table
---@field eIndex integer Required: Unique Index of this Element
---@field mElementType string Required: "Type" - "Text", "Image" or, "Effect"
---@field mSharedData SharedData Required: RSS Sign Builder Meta data
local ElementData = {   -- All elements will resolve to this basic structure, further fields depend on mElementType
    
    eIndex = -1,
    mElementType = '',
    
    mSharedData = SharedData,
    mTextData = nil,
    mImageData = nil,
    --mEffectData = nil,
}
ElementData.__index = ElementData


local function ElementData_Test_mElementType( meta, value )
    local et = __internals.ElementTypes[ value ]
    if et == nil then
        return false, string.format( "%s must be a valid ElementType - got '%s'", meta.name, value )
    end
    return true, nil
end

local ElementData_MetaData = ClassMeta.new( {
    metatablename = "ElementData",
    metatable = ElementData,
    allownil = true,
    fields = {
        ClassMeta.FieldMeta.new( { name = "eIndex", ftype = "number", valuetest = ClassMeta.FieldMeta.Common.Test_Integer_NotNegative } ),
        ClassMeta.FieldMeta.new( { name = "mElementType", ftype = "string", valuetest = ElementData_Test_mElementType } ),
        ClassMeta.FieldMeta.new( { name = "mSharedData", ftype = "table", valuetest = FieldMeta_Test_SharedData, metatable = SharedData, metatablename = "SharedData" } ),
        ClassMeta.FieldMeta.new( { name = "mTextData", ftype = "table", allownil = true, valuetest = FieldMeta_Test_TextData, metatable = TextData, metatablename = "TextData" } ),
        ClassMeta.FieldMeta.new( { name = "mImageData", ftype = "table", allownil = true, valuetest = FieldMeta_Test_ImageData, metatable = ImageData, metatablename = "ImageData" } ),
        --ClassMeta.FieldMeta.new( { name = "mEffectData", ftype = "table", allownil = true, valuetest = FieldMeta_Test_EffectData, metatable = EffectData, metatablename = "EffectData" } ),
    }
} )


---Create a new Element table for the SignLayout.elements
---@param o table Table to use initialize ElementData, must pass ElementData_MetaData:isValid( o, false )
---@return ElementData, string ElementData, nil on success; nil, reason on error
function ElementData.new( o )
    if __internals.DebugMode then
        local result, reason = ElementData_MetaData:isValid( 'o', o, false )
        if not result then return nil, reason end
    end
    setmetatable( o, { __index = ElementData } )
    return o, nil
end




----------------------------------------------------------------
-- The HologramData
-- used for import string building


---@class HologramData:table
---@field mEnable boolean
---@field mDistortionIntensity number
---@field mScanlineIntensity number
---@field mBorderIntensity number
local HologramData = {
    mEnable = false,
    mDistortionIntensity = nil,
    mScanlineIntensity = nil,
    mBorderIntensity = nil,
}
HologramData.__index = HologramData


local HologramData_MetaData = ClassMeta.new( {
    metatablename = "HologramData",
    metatable = HologramData,
    fields = {
        ClassMeta.FieldMeta.new( { name = "mEnable", ftype = "boolean", serialize = ClassMeta.FieldMeta.Common.Serialize_Boolean } ),
        ClassMeta.FieldMeta.new( { name = "mDistortionIntensity", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Number_NotNegative, serialize = ClassMeta.FieldMeta.Common.Serialize_Number } ),
        ClassMeta.FieldMeta.new( { name = "mScanlineIntensity", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Number_NotNegative, serialize = ClassMeta.FieldMeta.Common.Serialize_Number } ),
        ClassMeta.FieldMeta.new( { name = "mBorderIntensity", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Number_NotNegative, serialize = ClassMeta.FieldMeta.Common.Serialize_Number } ),
    }
} )


local function FieldMeta_Test_HologramData( meta, value )
    return HologramData_MetaData:isValid( meta.name, value, true )
end


---Create a new HologramData for SignLayout.mHologramData
---@param o table Table to use initialize HologramData, must pass HologramData_MetaData:isValid( o, false )
---@return HologramData, string HologramData, nil on success; nil, reason on error
function HologramData.new( o )
    if __internals.DebugMode then
        local result, reason = HologramData_MetaData:isValid( 'o', o, false )
        if not result then return nil, reason end
    end
    setmetatable( o, { __index = HologramData } )
    return o, nil
end

local fHologram = HologramData.new( { mEnable = false } )
local tHologram = HologramData.new( { mEnable = true, mDistortionIntensity = 0.0, mScanlineIntensity = 1.0, mBorderIntensity = 20.0 } )




----------------------------------------------------------------
-- The RoundedData
-- used for import string building


---@class RoundedData:table
---@field mEnable boolean
local RoundedData = {
    mEnable = false,
}
RoundedData.__index = RoundedData


local RoundedData_MetaData = ClassMeta.new( {
    metatablename = "RoundedData",
    metatable = RoundedData,
    allownil = true,
    fields = {
        ClassMeta.FieldMeta.new( { name = "mEnable", ftype = "boolean", serialize = ClassMeta.FieldMeta.Common.Serialize_Boolean } ),
    }
} )


local function FieldMeta_Test_RoundedData( meta, value )
    return RoundedData_MetaData:isValid( meta.name, value, true )
end


---Create a new RoundedData for SignLayout.mRoundedDataRoundedData.new(
---@param o table Table to use initialize RoundedData, must pass RoundedData_MetaData:isValid( o, false )
---@return RoundedData, string RoundedData, nil on success; nil, reason on error
function RoundedData.new( o )
    if __internals.DebugMode then
        local result, reason = RoundedData_MetaData:isValid( 'o', o, false )
        if not result then return nil, reason end
    end
    setmetatable( o, { __index = RoundedData } )
    return o, nil
end

local fRounded = RoundedData.new( { mEnable = false } )
local tRounded = RoundedData.new( { mEnable = true } )




----------------------------------------------------------------
-- The FlatData
-- used for import string building


---@class FlatData:table
---@field mEnable boolean
---@field mUseParallax boolean
---@field mUseArrowMaterial boolean
---@field mOverwriteParalaxVerticalRatio number
---@field mOverwriteParalaxHorizontalRatio number
local FlatData = {
    mEnable = false,
    mUseParallax = nil,
    mUseArrowMaterial = nil,
    mOverwriteParalaxVerticalRatio = nil,
    mOverwriteParalaxHorizontalRatio = nil,
}
FlatData.__index = FlatData


local FlatData_MetaData = ClassMeta.new( {
    metatablename = "FlatData",
    metatable = FlatData,
    fields = {
        ClassMeta.FieldMeta.new( { name = "mEnable", ftype = "boolean", serialize = ClassMeta.FieldMeta.Common.Serialize_Boolean } ),
        ClassMeta.FieldMeta.new( { name = "mUseParallax", ftype = "boolean", allownil = true, serialize = ClassMeta.FieldMeta.Common.Serialize_Boolean } ),
        ClassMeta.FieldMeta.new( { name = "mUseArrowMaterial", ftype = "boolean", allownil = true, serialize = ClassMeta.FieldMeta.Common.Serialize_Boolean } ),
        ClassMeta.FieldMeta.new( { name = "mOverwriteParalaxVerticalRatio", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Number_NotNegative, serialize = ClassMeta.FieldMeta.Common.Serialize_Number } ),
        ClassMeta.FieldMeta.new( { name = "mOverwriteParalaxHorizontalRatio", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Number_NotNegative, serialize = ClassMeta.FieldMeta.Common.Serialize_Number } ),
    }
} )


local function FieldMeta_Test_FlatData( meta, value )
    return FlatData_MetaData:isValid( meta.name, value, true )
end


---Create a new FlatData for SignLayout.mFlatData
---@param o table Table to use initialize FlatData, must pass FlatData_MetaData:isValid( o, false )
---@return FlatData, string FlatData, nil on success; nil, reason on error
function FlatData.new( o )
    if __internals.DebugMode then
        local result, reason = FlatData_MetaData:isValid( 'o', o, false )
        if not result then return nil, reason end
    end
    setmetatable( o, { __index = FlatData } )
    return o, nil
end




----------------------------------------------------------------
-- The MaterialData
-- used for import string building


---@class MaterialData:table
---@field mEmissiveIntensity number Default: 0.3
---@field mDistortionIntensity number
---@field mScanlineIntensity number
---@field mBorderIntensity number
---@field mBackgroundColor Color
---@field mRotation Vector4F
local MaterialData = {
    mEmissiveIntensity = nil,
    mDistortionIntensity = nil,
    mScanlineIntensity = nil,
    mBorderIntensity = nil,
    mBackgroundColor = nil,
    mRotation = nil,
}
MaterialData.__index = MaterialData


local function MaterialData_Apply_mBackgroundColor( meta, value, ... )
    if value == nil then return end
    local scale, eIndex, sign = unpackApplyFieldMetaExtra( ... )
    sign:SetSignBackgroundColor( value )
end


local MaterialData_MetaData = ClassMeta.new( {
    metatablename = "MaterialData",
    metatable = MaterialData,
    fields = {
        ClassMeta.FieldMeta.new( { name = "mEmissiveIntensity", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Number_NotNegative, serialize = ClassMeta.FieldMeta.Common.Serialize_Number } ),
        ClassMeta.FieldMeta.new( { name = "mDistortionIntensity", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Number_NotNegative, serialize = ClassMeta.FieldMeta.Common.Serialize_Number } ),
        ClassMeta.FieldMeta.new( { name = "mScanlineIntensity", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Number_NotNegative, serialize = ClassMeta.FieldMeta.Common.Serialize_Number } ),
        ClassMeta.FieldMeta.new( { name = "mBorderIntensity", ftype = "number", allownil = true, valuetest = ClassMeta.FieldMeta.Common.Test_Number_NotNegative, serialize = ClassMeta.FieldMeta.Common.Serialize_Number } ),
        ClassMeta.FieldMeta.new( { name = "mBackgroundColor", ftype = "table", allownil = true, metatable = Color, metatablename = "Color", serialize = ClassMeta.FieldMeta.Common.Serialize_Color, apply = MaterialData_Apply_mBackgroundColor } ),
        ClassMeta.FieldMeta.new( { name = "mRotation", ftype = "table", allownil = true, metatable = Vector4F, metatablename = "Vector4F", serialize = ClassMeta.FieldMeta.Common.Serialize_Vector4f } ),
    }
} )


local function FieldMeta_Test_MaterialData( meta, value )
    return MaterialData_MetaData:isValid( meta.name, value, true )
end


---Create a new MaterialData for SignLayout.mMaterialData
---@param o table Table to use initialize MaterialData, must pass MaterialData_MetaData:isValid( o, false )
---@return MaterialData, string MaterialData, nil on success; nil, reason on error
function MaterialData.new( o )
    if __internals.DebugMode then
        local result, reason = MaterialData_MetaData:isValid( 'o', o, false )
        if not result then return nil, reason end
    end
    setmetatable( o, { __index = MaterialData } )
    return o, nil
end




----------------------------------------------------------------
-- The SignType internal table
-- used internally for import string building


---@class SignType:table
---@field mSignType string Required: import string value
---@field id integer Required: As returned by sign:GetSignType() where sign is a component.proxy()
---@field mHologramData HologramData
local SignType = {
    mSignType = nil,
    id = nil,
    mHologramData = nil,
}
SignType.__index = SignType


local SignType_MetaData = ClassMeta.new( {
    metatablename = "SignType",
    metatable = SignType,
    fields = {
        ClassMeta.FieldMeta.new( { name = "mSignType", ftype = "string", valuetest = ClassMeta.FieldMeta.Common.Test_String_NotEmpty } ),
        ClassMeta.FieldMeta.new( { name = "id", ftype = "number", valuetest = ClassMeta.FieldMeta.Common.Test_Integer_Positive } ),
        ClassMeta.FieldMeta.new( { name = "mHologramData", ftype = "table", valuetest = FieldMeta_Test_HologramData, metatable = HologramData, metatablename = "HologramData" } ),
    }
} )


---Create a new SignType
---@param o table
---@return SignType
function SignType.new( o )
    if __internals.DebugMode then
        local result, reason = SignType_MetaData:isValid( 'o', o, false )
        if not result then
            computer.panic( string.format( "%s\n%s", reason, debug.traceback() ) )
        end
    end
    setmetatable( o, { __index = SignType } )
    return o
end




----------------------------------------------------------------
-- The SignSize internal table
-- used internally for import string building


---@class SignSize:table
---@field mSignTypeSize string Required: import string value
---@field resolution Vector2d Required: Pixel resolution of the sign
local SignSize = {
    mSignTypeSize = nil,
    resolution = nil,
}
SignSize.__index = SignSize

local SignSize_MetaData = ClassMeta.new( {
    metatablename = "SignSize",
    metatable = SignSize,
    fields = {
        ClassMeta.FieldMeta.new( { name = "mSignTypeSize", ftype = "string", valuetest = ClassMeta.FieldMeta.Common.Test_String_NotEmpty } ),
        ClassMeta.FieldMeta.new( { name = "resolution", ftype = "table", metatable = Vector2d, metatablename = "Vector2d" } ),
    }
} )


---Create a new SignSize
---@param o table
---@return SignSize
function SignSize.new( o )
    if __internals.DebugMode then
        local result, reason = SignSize_MetaData:isValid( 'o', o, false )
        if not result then
            computer.panic( string.format( "%s\n%s", reason, debug.traceback() ) )
        end
    end
    setmetatable( o, { __index = SignSize } )
    return o
end




----------------------------------------------------------------
-- The SignClass internal table
-- used internally for import string building


---@class SignClass:table
---@field signSize string Required: SignSize key, "1x1", etc
---@field signType string Required: SignType key, "Normal", etc
---@field mRoundedData RoundedData Required
---@field mHologramData HologramData Required
local SignClass = {
    signSize = nil,
    signType = nil,
    mRoundedData = nil,
    mHologramData = nil,
}
SignClass.__index = SignClass

local function SignClass_FieldMeta_Test_signSize( meta, value )
    if __internals.SignSizes[ value ] == nil then
        return false, string.format( "%s cannot be resolved to SignSize - '%s'", meta.name, value )
    end
    return true, nil
end

local function SignClass_FieldMeta_Test_signType( meta, value )
    if __internals.SignTypes[ value ] == nil then
        return false, string.format( "%s cannot be resolved to SignType - '%s'", meta.name, value )
    end
    return true, nil
end

local SignClass_MetaData = ClassMeta.new( {
    metatablename = "SignClass",
    metatable = SignClass,
    fields = {
        ClassMeta.FieldMeta.new( { name = "signSize", ftype = "string", valuetest = SignClass_FieldMeta_Test_signSize } ),
        ClassMeta.FieldMeta.new( { name = "signType", ftype = "string", valuetest = SignClass_FieldMeta_Test_signType } ),
        ClassMeta.FieldMeta.new( { name = "mRoundedData", ftype = "table", valuetest = FieldMeta_Test_RoundedData, metatable = RoundedData, metatablename = "RoundedData" } ),
        ClassMeta.FieldMeta.new( { name = "mHologramData", ftype = "table", valuetest = FieldMeta_Test_HologramData, metatable = HologramData, metatablename = "HologramData" } ),
    }
} )


---Create a new SignClass
---@param o table
---@return SignClass
function SignClass.new( o )
    if __internals.DebugMode then
        local result, reason = SignClass_MetaData:isValid( 'o', o, false )
        if not result then
            computer.panic( string.format( "%s\n%s", reason, debug.traceback() ) )
        end
    end
    setmetatable( o, { __index = SignClass } )
    return o
end




----------------------------------------------------------------
-- The SignLayout table
-- used for import string building


---@class SignLayout:table
---@field signSize string Required: "1x1", "2x1", etc
---@field elements array ElementData Required: Complete list of all elements for the sign
---@field mFlatData FlatData FlatData Required: TODO: Recheck me
---@field mMaterialData MaterialData MaterialData Required: TODO: Recheck me
---@field mHologramData HologramData HologramData Optional: Override data for sign
local SignLayout = {
    signSize = nil,
    elements = nil,
    mFlatData = FlatData,
    mMaterialData = MaterialData,
    mHologramData = nil,
}
SignLayout.__index = SignLayout


local function SignLayout_Test_signSize( meta, value )
    local signSize = __internals.SignSizes[ value ]
    if signSize == nil then
        return false, string.format( "%s must be a valid SignSize - got '%s'", meta.name, value )
    end
    return true, nil
end

local function SignLayout_Test_elements( meta, value )
    for _, element in pairs( value ) do
        local result, reason = ElementData_MetaData:isValid( meta.name, element, true )
        if not result then return result, reason end
    end
    return true, nil
end

local SignLayout_MetaData = ClassMeta.new( {
    metatablename = "SignLayout",
    metatable = SignLayout,
    fields = {
        ClassMeta.FieldMeta.new( { name = "signSize", ftype = "string", valuetest = SignLayout_Test_signSize } ),
        ClassMeta.FieldMeta.new( { name = "elements", ftype = "table", allownil = true, valuetest = SignLayout_Test_elements } ),
        ClassMeta.FieldMeta.new( { name = "mFlatData", ftype = "table", allownil = true, valuetest = FieldMeta_Test_FlatData, metatable = FlatData, metatablename = "FlatData" } ),
        ClassMeta.FieldMeta.new( { name = "mMaterialData", ftype = "table", allownil = true, valuetest = FieldMeta_Test_MaterialData, metatable = MaterialData, metatablename = "MaterialData" } ),
        ClassMeta.FieldMeta.new( { name = "mHologramData", ftype = "table", allownil = true, valuetest = FieldMeta_Test_HologramData, metatable = HologramData, metatablename = "HologramData" } ),
    }
} )


function SignLayout.isSignLayout( o )
    if o == nil or type( o ) ~= 'table' then return false end
    if __internals.DebugMode then
        local result, reason = SignLayout_MetaData:isValid( 'o', o, true )
        return result
    end
    -- Lazy test
    return  o.getmetatable() ~= nil
    and     o.getmetatable().__index == SignLayout
end

---Create a new SignLayout table to hold the ElementData and describe the basic canvas
---@param o table Table to use initialize SignLayout, must pass SignLayout_MetaData:isValid( o, false )
---@return SignLayout, string SignLayout, nil on success; nil, reason on error
function SignLayout.new( o )
    if __internals.DebugMode then
        local result, reason = SignLayout_MetaData:isValid( 'o', o, false )
        if not result then return nil, reason end
    end
    o.elements = o.elements or {}
    setmetatable( o, { __index = SignLayout } )
    return o, nil
end


---Add an Element to the Sign
---@param element mImageData Element to add to the sign
---@return boolean, string true, nil on success, false, reason otherwise
function SignLayout:addElement( element )
    if __internals.DebugMode then
        local result, reason = ElementData_MetaData:isValid( "element", element, true )
        if not result then return false, reason end
    end
    self.elements = self.elements or {}
    table.insert( self.elements, element )
    return true, nil
end




----------------------------------------------------------------
-- The ElementType internal table
-- used internally for import string building

---@class ElementType:table
---@field mElementType string Required: Import string field value
---@field iElementType integer Required: The ElementType on the RSSSign
---@field bIncludeElementType boolean Optional: Include the mElementType field in the import string; default: true
---@field mElementName string Required: Field name in the element
---@field metatable ClassMeta Required: ClassMeta table describing the ElementType
local ElementType = {
    mElementType = '',
    iElementType = -1,
    bIncludeElementType = true,
    mElementName = nil,
    metatable = nil,
}
ElementType.__index = ElementType


local function ElementType_Test_iElementType( meta, value )
    if value < 0 or value > 2 then
        return false, string.format( "%s must be a valid integer matching the return of sign:GetIndexType() - got %d", meta.name, value )
    end
    return true, nil
end


local ElementType_MetaData = ClassMeta.new( {
    metatablename = "ElementType",
    metatable = ElementType,
    fields = {
        ClassMeta.FieldMeta.new( { name = "mElementType", ftype = "string", valuetest = ClassMeta.FieldMeta.Common.Test_String_NotEmpty } ),
        ClassMeta.FieldMeta.new( { name = "iElementType", ftype = "number", valuetest = ElementType_Test_iElementType } ),
        ClassMeta.FieldMeta.new( { name = "bIncludeElementType", ftype = "boolean", allownil = true } ),
        ClassMeta.FieldMeta.new( { name = "mElementName", ftype = "string", valuetest = ClassMeta.FieldMeta.Common.Test_String_NotEmpty } ),
        ClassMeta.FieldMeta.new( { name = "metatable", ftype = "table", metatable = ClassMeta, metatablename = "ClassMeta" } ),
    }
} )




----------------------------------------------------------------
-- Fixup the main RSSBuilder class


-- Map the internal static classes and templates to the public API
RSSBuilder.SignLayout                             = SignLayout
RSSBuilder.SignLayout.HologramData                = HologramData
RSSBuilder.SignLayout.FlatData                    = FlatData
RSSBuilder.SignLayout.MaterialData                = MaterialData
RSSBuilder.SignLayout.RoundedData                 = RoundedData
RSSBuilder.SignLayout.ElementData                 = ElementData
RSSBuilder.SignLayout.ElementData.SharedData      = SharedData
RSSBuilder.SignLayout.ElementData.TextData        = TextData
RSSBuilder.SignLayout.ElementData.ImageData       = ImageData




----------------------------------------------------------------
-- Some helper functions


---Find the element in an unordered table by it's eIndex
---@param elements array array of ElementData
local function findElementByIndex( elements, eIndex )
    for _, element in pairs( elements ) do
        if element.eIndex == eIndex then return element end
    end
    return nil
end




---Calculate the scale factor for elements for the difference in sign resolutions
local function scaleTo( targetSize, sourceSize )
    --print( targetSize, targetSize.mSignTypeSize )
    --print( sourceSize, sourceSize.mSignTypeSize )
    
    local tRes = targetSize.resolution
    local sRes = sourceSize.resolution
    local scaleX = tRes.x / sRes.x
    local scaleY = tRes.y / sRes.y
    if scaleX < scaleY then return scaleX end
    return scaleY
end




----------------------------------------------------------------

---Get the Text Element import string replacement for the RSSBuilder.Text.Type, if nil is returned mTextType should not be added to the import string
---@param type RSSBuilder.Text.Type
---@return string
function RSSBuilder.Text.Type.ToString( type )
    if type == RSSBuilder.Text.Type.Background then return "BackgroundText" end
    return nil
end

---Get the Text Element import string replacement for the RSSBuilder.Text.Justification, if nil is returned mTextJustify should not be added to the import string
---@param justification RSSBuilder.Text.Justification
---@return string
function RSSBuilder.Text.Justification.ToString( justification )
    if justification == RSSBuilder.Text.Justification.Left then return "RSS_Left" end
    if justification == RSSBuilder.Text.Justification.Middle then return "RSS_Middle" end
    return nil
end

---Get the Text Element import string replacement for the RSSBuilder.Text.Font
---@param font RSSBuilder.Text.Font
---@return string
function RSSBuilder.Text.Font.ToString( font )
    if font == RSSBuilder.Text.Font.Allan           then return "/KUI/Fonts/Allan/KUI_Allan.KUI_Allan"                          end
    if font == RSSBuilder.Text.Font.Amatic          then return "/KUI/Fonts/Amatic/KUI_Amatic.KUI_Amatic"                       end
    if font == RSSBuilder.Text.Font.Antonio         then return "/KUI/Fonts/Antonio/KUI_Antonio.KUI_Antonio"                    end
    if font == RSSBuilder.Text.Font.CourierPrime    then return "/KUI/Fonts/CourierPrime/KUI_CourierPrime.KUI_CourierPrime"     end
    if font == RSSBuilder.Text.Font.Orbitron        then return "/KUI/Fonts/Orbitron/KUI_Orbitron.KUI_Orbitron"                 end
    if font == RSSBuilder.Text.Font.Rajdhani        then return "/KUI/Fonts/Rajdhani/KUI_Rajdhani.KUI_Rajdhani"                 end
    if font == RSSBuilder.Text.Font.Roboto          then return "/KUI/Fonts/Roboto/KUI_Roboto.KUI_Roboto"                       end
    return "/KUI/Fonts/OpenSans/KUI_OpenSans.KUI_OpenSans"
end






----------------------------------------------------------------
-- Use sign:GetSignType() to RSSBuilder.Sign.Type.GetDataByID()


---Add a new sign type to the tables
---@param type string The sign type as it is used to build the mSignType, eg "Normal" for "mSignType=RSS_Normal"
---@param id integer The value as returned by sign:GetSignType() for this sign type
---@param hologram HologramData As appropriate for type
local function addSignType( stype, id, hologram )
    if __internals.DebugMode then
        if stype == nil or type( stype ) ~= "string" or stype == '' then
            computer.panic( "stype must be a valid string\n" .. debug.traceback() )
        end
    end
    
    local mSignType = "RSS_" .. stype
    
    -- SignType will be valid or the computer will panic
    local signType = SignType.new( { mSignType = mSignType, id = id, mHologramData = hologram } )
    
    RSSBuilder.Sign.Type[ stype ] = mSignType
    RSSBuilder.Sign.Type[ id ] = mSignType
    
    __internals.SignTypes[ stype ] = signType
end


---Get the table of data describing this sign type
---@param id integer The value as returned by sign:GetSignType() to get the SignType of
---@return SignType nil or SignType
function RSSBuilder.Sign.Type.GetDataByID( id )
    if id == nil or type( id ) ~= "number" then return nil end
    for _, signType in pairs( __internals.SignTypes ) do
        if signType.id == id then return signType end
    end
    return nil
end


---Get the table of data describing this sign type
---@param stype string The sign type, "Normal", etc
---@return SignType nil or SignType
function RSSBuilder.Sign.Type.GetDataByType( stype )
    if stype == nil or type( stype ) ~= "string" then return nil end
    return __internals.SignTypes[ stype ]
end


---Get the table of data describing this sign type
---@param import string The mSignType import string, "RSS_Normal", etc
---@return SignType nil or SignType
function RSSBuilder.Sign.Type.GetDataByImport( import )
    if import == nil or type( import ) ~= "string" then return nil end
    for _, signType in pairs( __internals.SignTypes ) do
        if signType.mSignType == import then return signType end
    end
    return nil
end




-- Add all known RSS Sign Types to the SignType table
local function addRSSSignTypes()
    addSignType( "Normal", 1, fHologram )
    addSignType( "Hologram", 2, tHologram )
end




----------------------------------------------------------------

---Add a new size to the internal table
---@param signSize string The size as it is used to build the mSignTypeSize, eg "1x1" for "RSS_1x1", etc
---@param resolution Vector2d The resolution of this sign size
local function addSignSize( signSize, resolution )
    if __internals.DebugMode then
        if signSize == nil or type( signSize ) ~= "string" or signSize == '' then
            computer.panic( string.format( 'signSize is nil or invalid type\n%s', debug.traceback() ) )
        end
        if not Vector2d.isVector2d( resolution ) then
            computer.panic( string.format( 'resolution is nil or invalid type\n%s', debug.traceback() ) )
        end
    end
    
    local mSignTypeSize = "RSS_" .. signSize
    
    -- SignSize will be valid or the computer will panic
    local size = SignSize.new( { mSignTypeSize = mSignTypeSize, resolution = resolution } )
    
    RSSBuilder.Sign.Size[ signSize ] = mSignTypeSize
    __internals.SignSizes[ signSize ] = size
end


---Get the table of data describing this sign size
---@param signSize string The "size" of the sign - "1x1", "2x05", etc
---@return SignSize nil or SignSize
function RSSBuilder.Sign.Size.GetDataBySize( signSize )
    if signSize == nil or type( signSize ) ~= "string" then return nil end
    return __internals.SignSizes[ signSize ]
end


---Get the table of data describing this sign size
---@param mSignTypeSize string The mSignTypeSize of the sign - "RSS_1x1", "RSS_2x05", etc
---@return SignSize nil or SignSize
function RSSBuilder.Sign.Size.GetDataByImport( mSignTypeSize )
    if mSignTypeSize == nil or type( mSignTypeSize ) ~= "string" then return nil end
    for _, signSize in pairs( __internals.SignSizes ) do
        if signSize.mSignTypeSize == mSignTypeSize then return signSize end
    end
    return nil
end




-- Add all known RSS Sign Sizes and resolutions to the SignSize table
local function addRSSSignSizes()
    addSignSize( "05x05", Vector2d.new(  256,  256 ) )
    addSignSize( "2x05" , Vector2d.new( 1024,  256 ) )
    addSignSize( "3x05" , Vector2d.new(  768,  128 ) )
    addSignSize( "4x05" , Vector2d.new( 1024,  128 ) )
    addSignSize( "1x1"  , Vector2d.new(  512,  512 ) )
    addSignSize( "2x1"  , Vector2d.new( 1024,  512 ) )
    addSignSize( "7x1"  , Vector2d.new( 1792,  256 ) )
    addSignSize( "1x2"  , Vector2d.new(  512, 1024 ) )
    addSignSize( "2x2"  , Vector2d.new( 1024, 1024 ) )
    addSignSize( "25x2" , Vector2d.new( 2500,  200 ) )
    addSignSize( "2x3"  , Vector2d.new( 1024, 1536 ) )
    addSignSize( "8x4"  , Vector2d.new( 1536,  768 ) )
    addSignSize( "16x8" , Vector2d.new( 2048, 1024 ) )
end




----------------------------------------------------------------
-- There is sign:GetSignType() but there is no sign:GetSignSize()
-- So we'll fake it by building a table of all known signs and their sizes
-- TODO:  Need additional sign class information, mainly: mRoundedData is on the sign class
--[[
mRoundedData = nil,
ClassMeta.FieldMeta.new( { name = "mRoundedData", ftype = "table", valuetest = SignType_Test_mRoundedData, metatable = RoundedData, metatablename = "RoundedData" } ),
]]

local function addSignClass( classname, signSize, signType, mRoundedData, mHologramData )
    if __internals.DebugMode then
        if classname == nil or type( classname ) ~= "string" or classname == '' then return end
    end
    
    -- SignClass will be valid or the computer will panic
    local signClass = SignClass.new( { signSize = signSize, signType = signType, mRoundedData = mRoundedData, mHologramData = mHologramData } )
    
    RSSBuilder.Sign.Class[ classname ] = classname
    __internals.SignClasses[ classname ] = signClass
    
end


---Get the SignClass for the given sign class
---@param classname string The class of the sign - tostring( sign )
---@return SignClass nil or SignClass
function RSSBuilder.Sign.Class.GetDataByClass( classname )
    if classname == nil or type( classname ) ~= "string" or classname == '' then return nil end
    return __internals.SignClasses[ classname ]
end




-- Add all known RSS Sign Classes to the internal SignClasses table
local function addRSSSignClasses()
    addSignClass( "Build_RSS_1x1_Ceiling_C", "1x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x2_Ceiling_C", "1x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_2x1_Ceiling_C", "2x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_7x1_Ceiling_C", "7x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x1_Conv_C", "1x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x1_Conv_1side_C", "1x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x2_Conv_C", "1x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x2_Conv_1side_C", "1x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x1_Pipe_C", "1x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x1_Pipe_1side_C", "1x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x2_Pipe_C", "1x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x2_Pipe_1side_C", "1x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_2x1_Pipe_C", "2x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_2x1_Pipe_1side_C", "2x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_7x1_Pipe_C", "7x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_7x1_Pipe_1side_C", "7x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x1_Stand_C", "1x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x2_Stand_C", "1x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_2x1_Stand_C", "2x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_7x1_Stand_C", "7x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x1_Wall_C", "1x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x2_Wall_C", "1x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x7_Wall_C", "7x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_2x1_Wall_C", "2x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_7x1_Wall_C", "7x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x1_C", "1x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x2_C", "1x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_2x1_C", "2x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_7x1_NEW_C", "7x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_Holoscreen_1x1_Ceiling_C", "1x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x2_Ceiling_C", "1x2", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_2x1_Ceiling_C", "2x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_7x1_Ceiling_C", "7x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x1_Conv_C", "1x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x1_Conv_1side_C", "1x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x2_Conv_C", "1x2", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x2_Conv_1side_C", "1x2", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x1_Pipe_C", "1x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x1_Pipe_1side_C", "1x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x2_Pipe_C", "1x2", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x2_Pipe_1side_C", "1x2", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_2x1_Pipe_C", "2x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_2x1_Pipe_1side_C", "2x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_7x1_Pipe_C", "7x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_7x1_Pipe_1side_C", "7x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x1_Stand_C", "1x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x2_Stand_C", "1x2", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_2x1_Stand_C", "2x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_7x1_Stand_C", "7x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x1_Wall_C", "1x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x2_Wall_C", "1x2", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x7_Wall_C", "7x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_2x1_Wall_C", "2x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_7x1_Wall_C", "7x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x1_C", "1x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_1x2_C", "1x2", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_2x1_C", "2x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RSS_Holoscreen_7x1_C", "7x1", "Hologram", fRounded, tHologram )
    addSignClass( "Build_RssRounded_Flat_C", "25x2", "Normal", tRounded, fHologram )
    addSignClass( "Build_RssRounded_Holo_C", "25x2", "Hologram", tRounded, tHologram )
    addSignClass( "Build_RSS_05x05_Vanilla_C", "05x05", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_16x8_Vanilla_C", "16x8", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_1x1_Vanilla_C", "1x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_2x05_Vanilla_C", "2x05", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_2x1_Vanilla_C", "2x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_2x2_Vanilla_C", "2x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_2x3_Vanilla_C", "2x3", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_3x05_Vanilla_C", "3x05", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_4x05_Vanilla_C", "4x05", "Normal", fRounded, fHologram )
    addSignClass( "Build_RSS_8x4_Vanilla_C", "8x4", "Normal", fRounded, fHologram )
    addSignClass( "Build_FoundationSign_8x8x1_C", "2x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RssDrohne_Flat_1x1_C", "1x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RssDrohne_Flat_1x2_C", "1x2", "Normal", fRounded, fHologram )
    addSignClass( "Build_RssDrohne_Flat_2x1_C", "2x1", "Normal", fRounded, fHologram )
    addSignClass( "Build_RssDrohne_Flat_7x1_C", "7x1", "Normal", fRounded, fHologram )
end




----------------------------------------------------------------


local function tryApplySignElementFunction( sign, func, index, value, vtype )
    if value == nil or type( value ) ~= vtype then return end
    local f = sign[ func ]
    if f == nil or type( f ) ~= "function" then return end
    f( sign, value, index )
end


local function addElementType( o )
    if __internals.DebugMode then
        local result, reason = ElementType_MetaData:isValid( 'o', o, false )
        if not result then
            computer.panic( string.format( "%s\n%s", reason, debug.traceback() ) )
        end
    end
    setmetatable( o, { __index = ElementType } )
    __internals.ElementTypes[ o.mElementType ] = o
end




-- Add all known RSS Sign Element Types to the ElementTypes table
local function addRSSSignElementTypes()
    addElementType( {
        mElementType = "Text",
        iElementType = 0,
        bIncludeElementType = false,
        mElementName = "mTextData",
        metatable = TextData_MetaData } )
    addElementType( {
        mElementType = "Image",
        iElementType = 2,
        mElementName = "mImageData",
        metatable = ImageData_MetaData } )
    --TODO:  Effect
end




----------------------------------------------------------------


---Generate the sign import string from the layout
---@param layout SignLayout must be valid before entry
---@param targetType SignType must be valid before entry
---@param targetSize SignSize must be valid before entry
---@param mRoundedData RoundedData Required
---@param mHologramData HologramData Required
------@return boolean, string true and import string or false and error string
local function generateImportEx( layout, targetType, targetSize, mRoundedData, mHologramData )
    
    -- Find the first and last element indexes
    local lastIndex = -1
    local firstIndex = math.huge  -- For cereals, how many do you have?
    for _, element in pairs( layout.elements ) do
        if element.eIndex < firstIndex then firstIndex = element.eIndex end
        if element.eIndex > lastIndex then lastIndex = element.eIndex end
    end
    
    -- Make sure there are no missing element indexes
    if firstIndex ~= 0 then return false, "Missing element 0!" end
    if lastIndex < firstIndex then return false, "Missing last element!  This should never happen." end
    if lastIndex > firstIndex then
        for i = firstIndex, lastIndex do
            if findElementByIndex( layout.elements, i ) == nil then return false, "Missing indexed element, all eIndexes in layout.elements must be continuous from " .. tostring( firstIndex ) .. " to " .. tostring( lastIndex ) .. " - First missing eIndex " .. tostring( i ) end
        end
    end
    
    
    -- Get the scale for the target
    local sourceSize = __internals.SignSizes[ layout.signSize ]
    local scale = scaleTo( targetSize, sourceSize )
    
    
    -- Start generating the serialization data
    local imports = {}
    
    table.insert( imports, string.format( '%s=%s', 'mSignType', targetType.mSignType ) )
    table.insert( imports, string.format( '%s=%s', 'mSignTypeSize', targetSize.mSignTypeSize ) )
    
    local function tryImportTable( imports, source, name, meta, ... )
        if source == nil or type( source ) ~= "table" then return end
        if meta == nil or type( meta ) ~= "table" or meta.serialize == nil or type( meta.serialize ) ~= "function" then return end
        local result, import = meta:serialize( name, source, ... )
        if import == nil then import = '' end
        if result then
            if import ~= '' then
                --print( string.sub( import, 1, math.min( string.len( import ), 15 ) ) )
                table.insert( imports, import )
            end
        else
            computer.panic( string.format( "%s\n%s", import, debug.traceback() ) )
        end
    end
    
    local function tryImportChildTable( imports, source, field, meta, ... )
        if source == nil or type( source ) ~= "table" then return end
        if field == nil or type( field ) ~= "string" or field == '' then return end
        tryImportTable( imports, source[ field ], field, meta, ... ) -- Let tryImportTable handle source[ field ] testing
    end
    
    mRoundedData = layout.mRoundedData or mRoundedData
    mHologramData = layout.mHologramData or targetType.mHologramData or mHologramData
    
    tryImportTable( imports, mHologramData, "mHologramData", HologramData_MetaData )
    tryImportTable( imports, mRoundedData, "mRoundedData", RoundedData_MetaData )
    tryImportChildTable( imports, layout, "mFlatData", FlatData_MetaData )
    tryImportChildTable( imports, layout, "mMaterialData", MaterialData_MetaData )
    
    local eimports = {}
    
    for _, element in pairs( layout.elements ) do
        
        local elport = {}
        
        local et = __internals.ElementTypes[ element.mElementType ]
        
        if et.bIncludeElementType then
            table.insert( elport, string.format( '%s=%s', 'mElementType', element.mElementType ) )
        end
        tryImportChildTable( elport, element, "mSharedData", SharedData_MetaData, scale, element.eIndex, lastIndex )
        
        tryImportChildTable( elport, element, et.mElementName, et.metatable, scale, element.eIndex, lastIndex )
        
        if #elport ~= 0 then
            eimports[ 1 + element.eIndex ] = string.format( '(%s)', table.concat( elport, ',' ) )
            --print( element.eIndex, eimports[ 1 + element.eIndex ] )
        end
        
    end
    
    -- Add the elements in index order
    if #eimports ~= 0 then
        table.insert( imports, string.format( '%s=(%s)', 'mElements', table.concat( eimports, ',' ) ) )
    end
    
    import = string.format( '(%s)', table.concat( imports, ',' ) )
    return true, import
end


---Generate the sign import string from the layout
---@param targetType SignType Required: Target SignType
---@param targetSize SignSize Required: Target SignSize
---@param targetRounded RoundedData Required: Target RoundedData
---@param targetHologram HologramData Optional: Target HologramData override of layout HologramData
---@return boolean, string true and import string or false and error string
function SignLayout:generateImportExEx( targetType, targetSize, targetRounded, targetHologram )
    
    local result, reason = SignType_MetaData:isValid( 'targetType', targetType, true )
    if not result then return result, reason end
    
    result, reason = SignSize_MetaData:isValid( 'targetSize', targetSize, true )
    if not result then return result, reason end
    
    result, reason = RoundedData_MetaData:isValid( "targetRounded", targetRounded, true )
    if not result then return result, reason end
    
    targetHologram = targetHologram or self.mHologramData
    result, reason = HologramData_MetaData:isValid( "targetHologram", targetHologram, true )
    if not result then return result, reason end
    
    return generateImportEx( self, targetType, targetSize, targetRounded, targetHologram )
end


---Generate the sign import string from the layout
---@param signType string Required: Target SignType key, "Normal", "Hologram"
---@param signSize string Required: Target SignSize key, "2x1", "8x4", etc
---@param targetRounded RoundedData Required: Target RoundedData
---@param targetHologram HologramData Optional: Target HologramData override of layout HologramData
---@return boolean, string true and import string or false and error string
function SignLayout:generateImportEx( signType, signSize, targetRounded, targetHologram )
    
    if signType == nil or type( signType ) ~= "string" then return false, "signType is nil or wrong type" end
    if signSize == nil or type( signSize ) ~= "string" then return false, "signSize is nil or wrong type" end
    
    local targetType = __internals.SignTypes[ signType ]
    if targetType == nil then return false, "signType could not be resolved - '" .. signType .. "'" end
    
    local targetSize = __internals.SignSizes[ signSize ]
    if targetSize == nil then return false, "signSize could not be resolved - '" .. signSize .. "'" end
    
    local result, reason = RoundedData_MetaData:isValid( "targetRounded", targetRounded, true )
    if not result then return result, reason end
    
    targetHologram = targetHologram or self.mHologramData
    if targetHologram ~= nil then
        local result, reason = HologramData_MetaData:isValid( "targetHologram", targetHologram, true )
        if not result then return result, reason end
    end
    
    return generateImportEx( self, targetType, targetSize, targetRounded, targetHologram )
end


---Generate the sign import string from the sign data table.
---This will use the layout mHologramData as an override of the signs default HologramData.
---@param sign userdata Target Sign NetworkComponent proxy
---@return boolean, string true and import string or false and error string
function SignLayout:generateImport( sign )
    
    if sign == nil or type( sign ) ~= "userdata" then return false, "sign is nil or wrong type" end
    
    local classname = tostring( sign )
    local signClass = RSSBuilder.Sign.Class.GetDataByClass( classname )
    if signClass == nil then return false, "Could not resolve SignClass from '" .. classname .. "'\n\tThis is an unknown SignClass and a new internal table entry needs to be created for it." end
    
    -- Don't need to sanity check these returns, they are checked when the internal tables are built, if we got a SignClass then it's valid
    local targetType = RSSBuilder.Sign.Type.GetDataByType( signClass.signType )
    local targetSize = RSSBuilder.getSignClassSize( signClass.signSize )
    
    local targetHologram = self.mHologramData or signClass.mHologramData
    if targetHologram ~= nil then
        -- We do need to check the layout HologramData as usercode can do silly things
        local result, reason = HologramData_MetaData:isValid( "mHologramData", targetHologram, true )
        if not result then return result, reason end
    end
    
    return generateImportEx( self, targetType, targetSize, signClass.mRoundedData, targetHologram )
end


---Apply the layout of the main elements to the sign.  Note, not all element properties can be set at runtime nor can elements be added or removed.
---@param sign userdata Target Sign NetworkComponent proxy
---@param force boolean Force the application of the sign, even if the element count doesn't match.  Element types must still match, however.
---@return boolean, string true and nil or false and error string
function SignLayout:apply( sign, force )
    if sign == nil or type( sign ) ~= "userdata" then return false, "sign is nil or wrong type" end
    
    local classname = tostring( sign )
    local signClass = RSSBuilder.Sign.Class.GetDataByClass( classname )
    if signClass == nil then return false, "Could not resolve SignClass from '" .. classname .. "'\n\tThis is an unknown SignClass and a new internal table entry needs to be created for it." end
    
    -- Element count match?
    if force == nil or type( force ) ~= "boolean" then force = false end
    if force then
        local sec = sign:GetNumOfElements()
        local lec = #self.elements
        if sec ~= lec then return false, string.format( "element count mismatch, expected %d got %d", lec, sec ) end
    end
    
    
    -- Don't need to sanity check these returns, they are checked when the internal tables are built, if we got a SignClass then it's valid
    local targetSize = RSSBuilder.Sign.Size.GetDataBySize( signClass.signSize )
    
    local mHologramData = self.mHologramData or signClass.mHologramData
    if mHologramData ~= nil then
        -- We do need to check the layout HologramData as usercode can do silly things
        local result, reason = HologramData_MetaData:isValid( "mHologramData", mHologramData, true )
        if not result then return result, reason end
    end
    
    
    -- Get the scale for the target
    local sourceSize = __internals.SignSizes[ self.signSize ]
    local scale = scaleTo( targetSize, sourceSize )
    
    
    -- Start applying the layout
    local function tryApplyTable( source, name, meta, ... )
        if source == nil or type( source ) ~= "table" then return end
        if meta == nil or type( meta ) ~= "table" or meta.apply == nil or type( meta.apply ) ~= "function" then return end
        meta:apply( name, source, ... )
    end
    
    
    local function tryApplyChildTable( source, field, meta, ... )
        if source == nil or type( source ) ~= "table" then return end
        if field == nil or type( field ) ~= "string" or field == '' then return end
        tryApplyTable( source[ field ], field, meta, ... ) -- Let tryApplyTable handle source[ field ] testing
    end
    
    
    tryApplyTable( mHologramData, "mHologramData", HologramData_MetaData )
    tryApplyChildTable( self, "mRoundedData", RoundedData_MetaData )
    tryApplyChildTable( self, "mFlatData", FlatData_MetaData )
    tryApplyChildTable( self, "mMaterialData", MaterialData_MetaData )
    
    local sec = sign:GetNumOfElements()
    for _, element in pairs( self.elements ) do
        local eIndex = element.eIndex
        if eIndex < sec then -- Have to test this lest we CTD
            local et = __internals.ElementTypes[ element.mElementType ]
            if et.iElementType == sign:GetIndexType( eIndex ) then -- Always a requirement
                tryApplyChildTable( element, "mSharedData", SharedData_MetaData, scale, element.eIndex, sign )
                tryApplyChildTable( element, et.mElementName, et.metatable, scale, element.eIndex, sign )
            end
        end
    end
    
    
    return true, nil
end




---Check whether the number of elements in the sign matches the layout as well as each elements type; unfortunately there are not the required getters (and setters!) to interrogate any further.
---@param sign userdata Target Sign NetworkComponent proxy
---@return boolean, string true and nil if the layout matches (as best we can) the sign or false and the first mismatch otherwise
function SignLayout:signMatches( sign )
    if sign == nil or type( sign ) ~= "userdata" then return false, "sign is nil or wrong type" end
    
    local classname = tostring( sign )
    local signClass = RSSBuilder.Sign.Class.GetDataByClass( classname )
    if signClass == nil then return false, "Could not resolve SignClass from '" .. classname .. "'\n\tThis is an unknown SignClass and a new internal table entry needs to be created for it." end
    
    local sec = sign:GetNumOfElements()
    local lec = #self.elements
    if sec ~= lec then return false, string.format( "element count mismatch, expected %d got %d", lec, sec ) end
    
    local result = true
    local reason = ''
    for _, element in pairs( self.elements ) do
        local eIndex = element.eIndex
        local et = __internals.ElementTypes[ element.mElementType ]
        
        local seValue = sign:GetIndexType( eIndex )
        if seValue ~= et.iElementType then
            result = false
            if reason ~= '' then reason = reason .. '\n' end
            reason = reason .. string.format( "iElementType mismatch for eIndex %d '%s', expected %d got %d", eIndex, element.mSharedData.mElementName, et.iElementType, seValue )
        end
        
    end
    
    return result, reason
end




----------------------------------------------------------------


local function initRSSBuilder()
    addRSSSignTypes()
    addRSSSignSizes()
    addRSSSignClasses()
    addRSSSignElementTypes()
end




----------------------------------------------------------------


initRSSBuilder()
return RSSBuilder