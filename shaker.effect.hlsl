// OBS-specific syntax adaptation to HLSL standard to avoid errors reported by the code editor
#define SamplerState sampler_state
#define Texture2D texture2d
#define PI 3.141592653589793238

// Uniform variables set by OBS (required)
uniform float4x4 ViewProj; // View-projection matrix used in the vertex shader
uniform Texture2D image;   // Texture containing the source picture// Constants

// Size of the source picture
uniform int width;
uniform int height;
uniform int history_height;

// General properties
uniform int resolution_blur;
uniform Texture2D spectrum;
uniform float2 offset_hi;
uniform float2 offset_lo;
uniform float amplitude_color;
uniform float pow_shake_hi;
uniform float pow_shake_lo;
uniform float pow_color;
uniform float zoom;
uniform float color_zoom;
uniform float pow_zoom;

// Interpolation method and wrap mode for sampling a texture
SamplerState linear_clamp
{
    Filter      = Linear;   // Anisotropy / Point / Linear
    AddressU    = Clamp;    // Wrap / Clamp / Mirror / Border / MirrorOnce
    AddressV    = Clamp;    // Wrap / Clamp / Mirror / Border / MirrorOnce
    BorderColor = 00000000; // Used only with Border edges (optional)
};
SamplerState point_clamp
{
    Filter      = Point;    // Anisotropy / Point / Linear
    AddressU    = Clamp;    // Wrap / Clamp / Mirror / Border / MirrorOnce
    AddressV    = Clamp;    // Wrap / Clamp / Mirror / Border / MirrorOnce
    BorderColor = 00000000; // Used only with Border edges (optional)
};

// Data type of the input of the vertex shader
struct vertex_data
{
    float4 pos : POSITION;  // Homogeneous space coordinates XYZW
    float2 uv  : TEXCOORD0; // UV coordinates in the source picture
};

// Data type of the output returned by the vertex shader, and used as input
// for the pixel shader after interpolation for each pixel
struct pixel_data
{
    float4 pos : POSITION;  // Homogeneous screen coordinates XYZW
    float2 uv  : TEXCOORD0; // UV coordinates in the source picture
};

// Vertex shader used to compute position of rendered pixels and pass UV
pixel_data vertex_shader(vertex_data vertex)
{
    pixel_data pixel;
    pixel.pos = mul(float4(vertex.pos.xyz, 1.0), ViewProj);
    pixel.uv  = vertex.uv;
    return pixel;
}

struct Band
{
    float hi;
    float lo;
};

Band decodeSpectrum(Texture2D spectrum, int history)
{
    float dy = 1.0 / history_height;
    Band band;
    band.hi = spectrum.Sample(point_clamp, float2(0.9, history * dy)).r;
    band.lo = spectrum.Sample(point_clamp, float2(0.1, history * dy)).r;
    return band;
}

struct Coord_rgb
{
    float2 r;
    float2 g;
    float2 b;
};

Coord_rgb shake(pixel_data pixel, int history) {
    Coord_rgb coord;
    Band band = decodeSpectrum(spectrum, history);
    float3 th = (2*PI/3)*float3(0, 1, 2);
    float2 er = float2(cos(th.r), sin(th.r));
    float2 eg = float2(cos(th.g), sin(th.g));
    float2 eb = float2(cos(th.b), sin(th.b));
    er.x = er.x * height / width;
    eg.x = eg.x * height / width;
    eb.x = eb.x * height / width;
    float2 offset_shake = pow(band.hi, pow_shake_hi)*offset_hi + pow(band.lo, pow_shake_lo)*offset_lo;
    float amp_color = amplitude_color * pow(band.lo, pow_color);
    float2 e_zoom = pixel.uv - float2(0.5, 0.5);
    e_zoom.x = e_zoom.x * height / width;
    e_zoom *= e_zoom * e_zoom;
    e_zoom.x = e_zoom.x * width / height ;
    float amp_zoom = zoom * pow(band.lo, pow_zoom);
    float amp_color_zoom = color_zoom * pow(band.lo, pow_zoom);
    coord.r = pixel.uv - offset_shake - amp_color*er - amp_zoom * e_zoom;
    coord.g = pixel.uv - offset_shake - amp_color*eg - (amp_zoom + amp_color_zoom*0.5) * e_zoom;
    coord.b = pixel.uv - offset_shake - amp_color*eb - (amp_zoom + amp_color_zoom) * e_zoom;
    return coord;
}

// Pixel shader used to compute an RGBA color at a given pixel position
float4 pixel_shader(pixel_data pixel) : TARGET
{
    // return spectrum.Sample(point_clamp, pixel.uv); // for Debug
    Coord_rgb coord_now = shake(pixel, 0);
    Coord_rgb coord_prev = shake(pixel, 1);

    float3 color = float3(0, 0, 0);
    for (int i=0; i<resolution_blur; i++) {
        Coord_rgb coord;
        float blend = float(i)/resolution_blur;
        coord.r = coord_now.r + blend*(coord_prev.r - coord_now.r);
        coord.g = coord_now.g + blend*(coord_prev.g - coord_now.g);
        coord.b = coord_now.b + blend*(coord_prev.b - coord_now.b);
        color += float3(
            image.Sample(linear_clamp, coord.r).r,
            image.Sample(linear_clamp, coord.g).g,
            image.Sample(linear_clamp, coord.b).b
        );
    }
    color /= resolution_blur;
    return float4(color, 1);
}

technique Draw
{
    pass
    {
        vertex_shader = vertex_shader(vertex);
        pixel_shader  = pixel_shader(pixel);
    }
}
