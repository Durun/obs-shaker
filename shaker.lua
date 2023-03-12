obs = obslua

-- Returns the description displayed in the Scripts window
function script_description()
    return [[Shaker
    ]]
end

-- Called on script startup
function script_load(_)
    obs.obs_register_source(source_info)
    -- Try to compile the effect every 3 seconds for debug
    obs.timer_add(
            function()
                source_info.need_compile = true
            end,
            3000
    )
end

-- Definition of the global variable containing the source_info structure
source_info = {
    id = 'durun.shaker', -- Unique string identifier of the source type
    type = obs.OBS_SOURCE_TYPE_FILTER, -- INPUT or FILTER or TRANSITION
    output_flags = obs.OBS_SOURCE_VIDEO, -- Combination of VIDEO/AUDIO/ASYNC/etc
    get_name = function()
        -- Returns the name displayed in the list of filters
        return "Shaker"
    end,

    compile = function(data)
        if data.effect then
            source_info.destroy(data)
        end

        -- Compiles the effect
        obs.obs_enter_graphics()
        local effect_file_path = script_path() .. 'shaker.effect.hlsl'
        data.effect = obs.gs_effect_create_from_file(effect_file_path, nil)
        obs.obs_leave_graphics()

        -- Calls the destroy function if the effect was not compiled properly
        if data.effect then
            print("Compiled.")
        else
            obs.blog(obs.LOG_ERROR, "Effect compilation failed for " .. effect_file_path)
            print("Effect compilation failed for " .. effect_file_path)
            source_info.destroy(data)
        end

        -- Retrieves the shader uniform variables
        data.params = {
            width = obs.gs_effect_get_param_by_name(data.effect, "width"),
            height = obs.gs_effect_get_param_by_name(data.effect, "height"),
            amplitude = obs.gs_effect_get_param_by_name(data.effect, "amplitude"),
        }
        return data
    end,

    -- Creates the implementation data for the source
    create = function(_, source)
        -- Initializes the custom data table
        local data = {
            source = source, -- Keeps a reference to this filter as a source object
            width = 1, -- Dummy value during initialization phase
            height = 1,
            amplitude = 1,
        }
        return source_info.compile(data)
    end,

    -- Destroys and release resources linked to the custom data
    destroy = function(data)
        if data.effect ~= nil then
            obs.obs_enter_graphics()
            obs.gs_effect_destroy(data.effect)
            data.effect = nil
            obs.obs_leave_graphics()
        end
    end,

    get_width = function(data)
        return data.width
    end,
    get_height = function(data)
        return data.height
    end,

    need_compile = false,
    -- Called when rendering the source with the graphics subsystem
    video_render = function(data)
        if source_info.need_compile then
            source_info.need_compile = false
            source_info.destroy(data)
            data = source_info.compile(data)
        end
        local parent = obs.obs_filter_get_parent(data.source)
        data.width = obs.obs_source_get_base_width(parent)
        data.height = obs.obs_source_get_base_height(parent)

        obs.obs_source_process_filter_begin(data.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

        -- Bind params
        obs.gs_effect_set_int(data.params.width, data.width)
        obs.gs_effect_set_int(data.params.height, data.height)
        obs.gs_effect_set_float(data.params.amplitude, data.amplitude)

        obs.obs_source_process_filter_end(data.source, data.effect, data.width, data.height)
    end,

    get_properties = function(_)
        local props = obs.obs_properties_create()
        obs.obs_properties_add_float_slider(props, "amplitude", "Amplitude", -1.0, 1.0, 0.01)
        return props
    end,

    update = function(data, settings)
        data.amplitude = obs.obs_data_get_double(settings, "amplitude")
    end,
}
