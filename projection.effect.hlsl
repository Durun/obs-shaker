// OBS-specific syntax adaptation to HLSL standard to avoid errors reported by the code editor
#define SamplerState sampler_state
#define Texture2D texture2d

// Uniform variables set by OBS (required)
uniform float4x4 ViewProj; // View-projection matrix used in the vertex shader
uniform Texture2D image;   // Texture containing the source picture// Constants

// Size of the source picture
uniform int width;
uniform int height;

// Interpolation method and wrap mode for sampling a texture
SamplerState linear_clamp
{
    Filter      = Linear;   // Anisotropy / Point / Linear
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

// Pixel shader used to compute an RGBA color at a given pixel position
float4 pixel_shader(pixel_data pixel) : TARGET
{
    const int resolution = 128;
    float dv = 1.0 / resolution;
    float3 color = float3(0, 0, 0);
    for (int i = 0; i < resolution; i++) {
        color += image.Sample(linear_clamp, float2(pixel.uv.x, i * dv)).xyz;
    }
    return float4(color.xyz / float3(resolution, resolution, resolution), 1);
}

technique Draw
{
    pass
    {
        vertex_shader = vertex_shader(vertex);
        pixel_shader  = pixel_shader(pixel);
    }
}
