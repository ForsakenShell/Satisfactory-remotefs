-- Sets of NetworkComponent and PCIDevice classes commonly used
-- Classes in a set should really share common functions and properties

-- Why?  Because magic numbers/strings/etc are evil

-- It would be REALLY nice if Lua did proper typing and class heirarcy.
-- Subsequently we can't just do object is type, we need a complete list of
-- every class to compare against.


if _G[ "____ClassGroup" ] ~= nil then return _G[ "____ClassGroup" ] end
local ClassGroup = {}
_G[ "____ClassGroup" ] = ClassGroup




--[[
ClassGroup.Foo = buildSet(
    {
        "Build_Bar_C",
        "Build_Bar2_C",
    }
)
-- foo now has individual elements where:
--    key=value=class
-- such that one can:
--    -- Get by this specific class
--    local bar = component.proxy( component.findComponent( findClass( ClassGroup.Foo.Build_Bar_C ) )[ 1 ] )
--    print( bar.id )
-- or:
--    -- Get by this specific class
--    local bar2 = component.getComponentsByClass( ClassGroup.Foo.Build_Bar2_C )[ 1 ]
--    print( bar2.id )
-- or:
--    -- Get by all the classes in ClassGroup.Foo
--    local barAny = component.getComponentsByClass( ClassGroup.Foo.All )[ 1 ]
--    print( barAny.id )
]]


local function generateAllFromClasses( set )
    local all = {}
    for _, class in pairs( set ) do
        table.insert( all, class )
    end
    return all
end


local function buildSet( classes )
    local set = {}
    for _, class in pairs( classes ) do
        set[ class ] = class
    end
    set.All = generateAllFromClasses( set )
    set.isInSet = function( this, class )
        if this[ "All" ] == nil then return false end
        local ctype = findClass( class )
        if ctype == nil then return false end
        for _, setClass in pairs( this.All ) do
            if type( setClass ) == "string" then
                local sctype = findClass( setClass )
                if sctype == ctype then
                    return true
                end
            end
        end
        return false
    end
    return set
end



-- Build the global table
ClassGroup.CircuitSwitches = buildSet(
    {
        "CircuitSwitch",
    }
)




ClassGroup.ProductionMachines = buildSet(
    {
        "Manufacturer",                         -- Smelter, Constructor, Refinery, etc
        "FGBuildableResourceExtractorBase",     -- Miner, Water Pump, Oil Extractor, etc
    }
)


--TODO:  Fill this with the proper buildable classes
ClassGroup.CodeableSplitters = buildSet(
    {
        "CodeableSplitter",
    }
)


--TODO:  Fill this with the proper buildable classes
ClassGroup.CodeableMergers = buildSet(
    {
        "CodeableMerger",
    }
)




--TODO:  Fill this with the proper buildable classes
ClassGroup.TrainStations = buildSet(
    {
        "RailroadStation",
    }
)




ClassGroup.Displays = {}


ClassGroup.Displays.GPUs = buildSet(
    {
        "GPU_T1_C",
    }
)


ClassGroup.Displays.Signs = {}


ClassGroup.Displays.Signs.ReallySimpleSigns = buildSet(
    {
        "Build_RSS_1x1_Ceiling_C",
        "Build_RSS_1x2_Ceiling_C",
        "Build_RSS_2x1_Ceiling_C",
        "Build_RSS_7x1_Ceiling_C",
        "Build_RSS_1x1_Conv_C",
        "Build_RSS_1x1_Conv_1side_C",
        "Build_RSS_1x2_Conv_C",
        "Build_RSS_1x2_Conv_1side_C",
        "Build_RSS_1x1_Pipe_C",
        "Build_RSS_1x1_Pipe_1side_C",
        "Build_RSS_1x2_Pipe_C",
        "Build_RSS_1x2_Pipe_1side_C",
        "Build_RSS_2x1_Pipe_C",
        "Build_RSS_2x1_Pipe_1side_C",
        "Build_RSS_7x1_Pipe_C",
        "Build_RSS_7x1_Pipe_1side_C",
        "Build_RSS_1x1_Stand_C",
        "Build_RSS_1x2_Stand_C",
        "Build_RSS_2x1_Stand_C",
        "Build_RSS_7x1_Stand_C",
        "Build_RSS_1x1_Wall_C",
        "Build_RSS_1x2_Wall_C",
        "Build_RSS_1x7_Wall_C",
        "Build_RSS_2x1_Wall_C",
        "Build_RSS_7x1_Wall_C",
        "Build_RSS_1x1_C",
        "Build_RSS_1x2_C",
        "Build_RSS_2x1_C",
        "Build_RSS_7x1_NEW_C",
        "Build_RSS_Holoscreen_1x1_Ceiling_C",
        "Build_RSS_Holoscreen_1x2_Ceiling_C",
        "Build_RSS_Holoscreen_2x1_Ceiling_C",
        "Build_RSS_Holoscreen_7x1_Ceiling_C",
        "Build_RSS_Holoscreen_1x1_Conv_C",
        "Build_RSS_Holoscreen_1x1_Conv_1side_C",
        "Build_RSS_Holoscreen_1x2_Conv_C",
        "Build_RSS_Holoscreen_1x2_Conv_1side_C",
        "Build_RSS_Holoscreen_1x1_Pipe_C",
        "Build_RSS_Holoscreen_1x1_Pipe_1side_C",
        "Build_RSS_Holoscreen_1x2_Pipe_C",
        "Build_RSS_Holoscreen_1x2_Pipe_1side_C",
        "Build_RSS_Holoscreen_2x1_Pipe_C",
        "Build_RSS_Holoscreen_2x1_Pipe_1side_C",
        "Build_RSS_Holoscreen_7x1_Pipe_C",
        "Build_RSS_Holoscreen_7x1_Pipe_1side_C",
        "Build_RSS_Holoscreen_1x1_Stand_C",
        "Build_RSS_Holoscreen_1x2_Stand_C",
        "Build_RSS_Holoscreen_2x1_Stand_C",
        "Build_RSS_Holoscreen_7x1_Stand_C",
        "Build_RSS_Holoscreen_1x1_Wall_C",
        "Build_RSS_Holoscreen_1x2_Wall_C",
        "Build_RSS_Holoscreen_1x7_Wall_C",
        "Build_RSS_Holoscreen_2x1_Wall_C",
        "Build_RSS_Holoscreen_7x1_Wall_C",
        "Build_RSS_Holoscreen_1x1_C",
        "Build_RSS_Holoscreen_1x2_C",
        "Build_RSS_Holoscreen_2x1_C",
        "Build_RSS_Holoscreen_7x1_C",
        "Build_RssRounded_Flat_C",
        "Build_RssRounded_Holo_C",
        "Build_RSS_05x05_Vanilla_C",
        "Build_RSS_16x8_Vanilla_C",
        "Build_RSS_1x1_Vanilla_C",
        "Build_RSS_2x05_Vanilla_C",
        "Build_RSS_2x1_Vanilla_C",
        "Build_RSS_2x2_Vanilla_C",
        "Build_RSS_2x3_Vanilla_C",
        "Build_RSS_3x05_Vanilla_C",
        "Build_RSS_4x05_Vanilla_C",
        "Build_RSS_8x4_Vanilla_C",
        "Build_FoundationSign_8x8x1_C",
        "Build_RssDrohne_Flat_1x1_C",
        "Build_RssDrohne_Flat_1x2_C",
        "Build_RssDrohne_Flat_2x1_C",
        "Build_RssDrohne_Flat_7x1_C",
    }
)


ClassGroup.Displays.Signs.WidgetSigns = buildSet(
    {
        "WidgetSign",
        "Build_StandaloneWidgetSign_Huge_C",
        "Build_StandaloneWidgetSign_Large_C",
        "Build_StandaloneWidgetSign_Medium_C",
        "Build_StandaloneWidgetSign_Portrait_C",
        "Build_StandaloneWidgetSign_Small_C",
        "Build_StandaloneWidgetSign_SmallVeryWide_C",
        "Build_StandaloneWidgetSign_SmallWide_C",
        "Build_StandaloneWidgetSign_Square_C",
        "Build_StandaloneWidgetSign_Square_Small_C",
        "Build_StandaloneWidgetSign_Square_Tiny_C",
    }
)


ClassGroup.Displays.Screens = buildSet(
    {
        "ModuleScreen_C",
        "ScreenDriver_C",
        "Build_Screen_C",
    }
)




ClassGroup.Displays.TextDisplays = buildSet(
    {
        "ModuleTextDisplay_C",
    }
)


ClassGroup.Displays.Labels = buildSet(
    {
        "Module_Label_1x1_C",
        "Module_Label_2x1_C",
    }
)




ClassGroup.FluidPumps = buildSet(
    {
        "PipelinePump",
    }
)




ClassGroup.Networking = {}

ClassGroup.Networking.InterNet = buildSet(
    {
        "InternetCard_C",
    }
)

ClassGroup.Networking.IntraNet = buildSet(
    {
        "NetworkCard_C",
    }
)

ClassGroup.Networking.Routers = buildSet(
    {
        "NetworkRouter_C",
    }
)

ClassGroup.Networking.WirelessAccessPoints = buildSet(
    {
        "WirelessAccessPoint_C",
    }
)




ClassGroup.ModulePanels = buildSet(
    {
        "LargeControlPanel",
        "LargeVerticalControlPanel",
        "MCP_1Point_C",
        "MCP_1Point_Center_C",
        "MCP_2Point_C",
        "MCP_3Point_C",
        "MCP_6Point_C",
        "SizeableModulePanel",
    }
)




ClassGroup.Modules            = {}


-- These all have:
-- properties:
-- functions:
--  Trigger()
-- signals:
--  Trigger
ClassGroup.Modules.Buttons = buildSet(
    {
        "ModuleButton",
        "ModuleStopButton",
        "PushbuttonModule",
        "MushroomPushbuttonModule",
    }
)


-- These all have:
-- properties:
-- functions:
--  setColor()
-- signals:
--  valueChanged
ClassGroup.Modules.Encoders = buildSet(
    {
        "MCP_Mod_Encoder_C",
    }
)


-- These all have:
-- properties:
--  state
-- functions:
-- signals:
--  ChangeState
ClassGroup.Modules.Levers = buildSet(
    {
        "ModuleSwitch_C",
    }
)


-- These all have:
-- properties:
--  limit
--  percent
-- functions:
--  setColor()
-- signals:
ClassGroup.Modules.Gauges = buildSet(
    {
        "MCP_Mod_Gauge_C",
        "Module_BigGauge_C",
    }
)


-- These all have:
-- properties:
-- functions:
--  setColor()
-- signals:
ClassGroup.Modules.Indicators = buildSet(
    {
        "IndicatorModule",
    }
)


-- These all can be bound to a GPU for rendering
ClassGroup.Modules.Screens = buildSet(
    {
        "ModuleScreen_C",
    }
)


-- These all have:
-- properties:
--  monospace
--  size
--  text
-- functions:
-- signals:
ClassGroup.Modules.TextDisplays = buildSet(
    {
        "ModuleTextDisplay_C",
    }
)


-- These all have: ???
ClassGroup.Modules.Labels = buildSet(
    {
        "Module_Label_1x1_C",
        "Module_Label_2x1_C",
    }
)


-- These all have:
-- properties:
-- functions:
--  setColor()
--  setText()
-- signals:
ClassGroup.Modules.MicroDisplays = buildSet(
    {
        "LargeMicroDisplayModule",
        "MicroDisplayModule",
    }
)


ClassGroup.Modules.Potentiometers = {}


-- These all have:
-- properties:
-- functions:
--  rotate()
-- signals:
--  PotRotate
ClassGroup.Modules.Potentiometers.Simple = buildSet(
    {
        "ModulePotentiometer",
    }
)


-- These all have:
-- properties:
--  value
--  max
--  min
-- functions:
--  setColor()
-- signals:
--  valueChanged
ClassGroup.Modules.Potentiometers.Complex = buildSet(
    {
        "MCP_Mod_Potentiometer_C",
        
        -- These all have:
        -- properties:
        --  autovalue
        -- functions:
        --  setText() -- Doesn't do anything though; text is autogenerated internally from value
        -- signals:
        "MCP_Mod_PotWNum_C",
        
    }
)


-- These all have:
-- properties:
--  state
-- functions:
-- signals:
--  ChangeState
ClassGroup.Modules.Switches = buildSet(
    {
        "ModuleSwitch_C",
        
        -- These all have:
        -- properties:
        -- functions:
        --  setColor()
        -- signals:
        "MCP_Mod_2Pos_Switch_C",
        "MCP_Mod_3Pos_Switch_C",
    }
)




ClassGroup.Storage = {}


ClassGroup.Storage.Solids = buildSet(
    {
        "FGBuildableStorage",
        "Build_StorageContainerMk1_C",
        "Build_StorageContainerMk2_C",
        "Build_BBus_C",
        "Build_BBus_2_C",
        "BP_X3_CompactStorage_C",
        "BP_X3Storage_Mk1_C",
        "BP_X3Storage_Mk1plus_C",
        "BP_X3Storage_Mk2plus_C",
        "BP_X3Storage_Mk3plus_C",
    }
)


-- These all have:
-- properties:
--  fluidContent
--  maxFluidContent
--  flowFill
--  flowDrain
--  flowLimit
-- functions:
-- signals:
ClassGroup.Storage.Fluids = buildSet(
    {
        "PipeReservoir",
        "Build_PipeStorageTank_C",
        "Build_IndustrialTank_C",
        "Build_CeilBuff_C",
    }
)




return ClassGroup