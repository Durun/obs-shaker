obs = obslua

-- Returns the description displayed in the Scripts window
function script_description()
    return [[Shaker
    ]]
end

-- Called on script startup
function script_load(_)
    obs.obs_register_source(source_info)
    obs.obs_register_source(getter_info)
    obs.obs_register_source(summarizer_info)
    -- Try to compile the effect every 3 seconds for debug
    obs.timer_add(
            function()
                source_info.need_compile = true
            end,
            3000
    )
end

getter_info = {
    id = 'durun.shaker.getter', -- Unique string identifier of the source type
    type = obs.OBS_SOURCE_TYPE_FILTER, -- INPUT or FILTER or TRANSITION
    output_flags = obs.OBS_SOURCE_VIDEO, -- Combination of VIDEO/AUDIO/ASYNC/etc
    get_name = function()
        -- Returns the name displayed in the list of filters
        return "Shaker.getter"
    end,

    texture = nil,

    -- Creates the implementation data for the source
    create = function(_, source)
        local data = {
            source = source, -- Keeps a reference to this filter as a source object
            width = 1, -- Dummy value during initialization phase
            height = 1,
        }

        -- Compiles the effect
        obs.obs_enter_graphics()
        local effect_file_path = script_path() .. 'projection.effect.hlsl'
        data.effect = obs.gs_effect_create_from_file(effect_file_path, nil)
        obs.obs_leave_graphics()

        -- Calls the destroy function if the effect was not compiled properly
        if not data.effect then
            obs.blog(obs.LOG_ERROR, "Effect compilation failed for " .. effect_file_path)
            print("Effect compilation failed for " .. effect_file_path)
            getter_info.destroy(data)
        end

        data.uniforms = {
            width = obs.gs_effect_get_param_by_name(data.effect, "width"),
            height = obs.gs_effect_get_param_by_name(data.effect, "height"),
        }
        return data
    end,

    -- Destroys and release resources linked to the custom data
    destroy = function(data)
        getter_info.texture = nil
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

    video_render = function(data)
        local parent = obs.obs_filter_get_parent(data.source)
        data.width = obs.obs_source_get_base_width(parent)

        obs.obs_source_process_filter_begin(data.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)
        -- Bind uniforms
        obs.gs_effect_set_int(data.uniforms.width, data.width)
        obs.gs_effect_set_int(data.uniforms.height, data.height)
        obs.obs_source_process_filter_end(data.source, data.effect, data.width, data.height)
        getter_info.texture = obs.gs_get_render_target()
    end
}

summarizer_info = {
    id = 'durun.shaker.summarizer', -- Unique string identifier of the source type
    type = obs.OBS_SOURCE_TYPE_FILTER, -- INPUT or FILTER or TRANSITION
    output_flags = obs.OBS_SOURCE_VIDEO, -- Combination of VIDEO/AUDIO/ASYNC/etc
    get_name = function()
        -- Returns the name displayed in the list of filters
        return "Shaker.summarizer"
    end,

    texture = nil,

    -- Creates the implementation data for the source
    create = function(_, source)
        local data = {
            source = source, -- Keeps a reference to this filter as a source object
            width = 32,
            height = 32,
        }

        -- Compiles the effect
        obs.obs_enter_graphics()
        local effect_file_path = script_path() .. 'summarize.effect.hlsl'
        data.effect = obs.gs_effect_create_from_file(effect_file_path, nil)
        obs.obs_leave_graphics()

        -- Calls the destroy function if the effect was not compiled properly
        if not data.effect then
            obs.blog(obs.LOG_ERROR, "Effect compilation failed for " .. effect_file_path)
            print("Effect compilation failed for " .. effect_file_path)
            summarizer_info.destroy(data)
        end

        data.uniforms = {
            width = obs.gs_effect_get_param_by_name(data.effect, "width"),
            height = obs.gs_effect_get_param_by_name(data.effect, "height"),
            f1 = obs.gs_effect_get_param_by_name(data.effect, "f1"),
        }
        summarizer_info.update(data, settings)
        return data
    end,

    -- Destroys and release resources linked to the custom data
    destroy = function(data)
        summarizer_info.texture = nil
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

    video_render = function(data)
        obs.obs_source_process_filter_begin(data.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)
        -- Bind uniforms
        obs.gs_effect_set_int(data.uniforms.width, data.width)
        obs.gs_effect_set_int(data.uniforms.height, data.height)
        obs.gs_effect_set_float(data.uniforms.f1, data.f1)
        obs.obs_source_process_filter_end(data.source, data.effect, data.width, data.height)
        summarizer_info.texture = obs.gs_get_render_target()
    end,

    get_properties = function(_)
        local props = obs.obs_properties_create()
        obs.obs_properties_add_float_slider(props, "f1", "freq lo-hi", 0, 1.0, 0.01)
        return props
    end,

    update = function(data, settings)
        data.f1 = obs.obs_data_get_double(settings, "f1")
    end,
}

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
        if not data.effect then
            obs.blog(obs.LOG_ERROR, "Effect compilation failed for " .. effect_file_path)
            print("Effect compilation failed for " .. effect_file_path)
            source_info.destroy(data)
        end

        -- Retrieves the shader uniform variables
        data.uniforms = {
            width = obs.gs_effect_get_param_by_name(data.effect, "width"),
            height = obs.gs_effect_get_param_by_name(data.effect, "height"),
            offset = obs.gs_effect_get_param_by_name(data.effect, "offset"),
            amplitude_color = obs.gs_effect_get_param_by_name(data.effect, "amplitude_color"),
            pow_all = obs.gs_effect_get_param_by_name(data.effect, "pow_all"),
            pow_lo = obs.gs_effect_get_param_by_name(data.effect, "pow_lo"),
            spectrum = obs.gs_effect_get_param_by_name(data.effect, "spectrum"),
        }
        return data
    end,

    -- Creates the implementation data for the source
    create = function(settings, source)
        local data = {
            source = source, -- Keeps a reference to this filter as a source object
            width = 1, -- Dummy value during initialization phase
            height = 1,
            offset = obs.vec2(),
        }
        -- Initializes the custom data table
        source_info.update(data, settings)
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

        -- Bind Audio spectrum texture
        obs.gs_effect_set_texture(data.uniforms.spectrum, summarizer_info.texture)

        -- Bind uniforms
        obs.gs_effect_set_int(data.uniforms.width, data.width)
        obs.gs_effect_set_int(data.uniforms.height, data.height)
        obs.vec2_set(data.offset,
                data.amplitude_all * math.sin(os.clock() * data.freqX * math.pi),
                data.amplitude_all * math.sin(os.clock() * data.freqY * math.pi)
        )
        obs.gs_effect_set_vec2(data.uniforms.offset, data.offset)
        obs.gs_effect_set_float(data.uniforms.amplitude_color, data.amplitude_color)
        obs.gs_effect_set_float(data.uniforms.pow_all, data.pow_all)
        obs.gs_effect_set_float(data.uniforms.pow_lo, data.pow_lo)

        obs.obs_source_process_filter_end(data.source, data.effect, data.width, data.height)
    end,

    get_properties = function(_)
        local props = obs.obs_properties_create()
        obs.obs_properties_add_float_slider(props, "amplitude_all", "Amplitude(all)", 0, 10, 0.0001)
        obs.obs_properties_add_float_slider(props, "freqX", "freqX", 0, 50, 0.01)
        obs.obs_properties_add_float_slider(props, "freqY", "freqY", 0, 50, 0.01)
        obs.obs_properties_add_float_slider(props, "pow_all", "pow(all)", 0, 4, 0.01)
        obs.obs_properties_add_float_slider(props, "amplitude_color", "Amplitude(color)", 0, 10, 0.01)
        obs.obs_properties_add_float_slider(props, "pow_lo", "pow(lo)", 0, 4, 0.01)
        return props
    end,

    update = function(data, settings)
        data.amplitude_all = obs.obs_data_get_double(settings, "amplitude_all")
        data.freqX = obs.obs_data_get_double(settings, "freqX")
        data.freqY = obs.obs_data_get_double(settings, "freqY")
        data.pow_all = obs.obs_data_get_double(settings, "pow_all")
        data.amplitude_color = obs.obs_data_get_double(settings, "amplitude_color")
        data.pow_lo = obs.obs_data_get_double(settings, "pow_lo")
    end,
}
