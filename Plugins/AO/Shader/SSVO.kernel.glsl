
/*

SSVO - Screen Space Volumetric Obscurance

This algorithm casts rays to a sphere arround the current point in view space,
and approximates the spheres volume by using line intetrals. The percentage
of the spheres volume is then used to compute AO.

*/


const int num_samples = GET_SETTING(AO, ssvo_sample_count);
vec2 sphere_radius = GET_SETTING(AO, ssvo_sphere_radius) * pixel_size;
float max_depth_diff = GET_SETTING(AO, ssvo_max_distance);

float accum = 0.0;
float pixel_linz = getLinearZFromZ(pixel_depth);

for (int i = 0; i < num_samples; ++i) {

    // Get random offset in screen space
    vec2 offset = poisson_disk_2D_32[i];
    offset += noise_vec.xy * 0.5;
    vec2 offc = offset * sphere_radius * 6.0 * kernel_scale;

    // Use paired samples, this enables us to hide depth buffer discontinuities
    vec2 offcoord_a = texcoord + offc;
    vec2 offcoord_b = texcoord - offc;

    // Compute the sphere height at the sample location
    float sphere_height = sqrt( 1 - dot(offset, offset) );

    // Get the depth at the sample locations
    float depth_a = get_depth_at(offcoord_a);
    float depth_b = get_depth_at(offcoord_b);

    // Make the depth linear, this enables us to compare them better
    float depth_linz_a = getLinearZFromZ(depth_a);
    float depth_linz_b = getLinearZFromZ(depth_b);

    // Clamp both differences to the maximum depth difference
    float diff_a = (pixel_linz - depth_linz_a) / max_depth_diff;
    float diff_b = (pixel_linz - depth_linz_b) / max_depth_diff;

    // Compute the line integrals of boths, this is simply the height of the
    // line divided by the sphere height. However, we need to substract the
    // sphere height once, since we didn't start at the sphere top, but at
    // the sphere mid (since we took the depth of point p which is the center
    // of the sphere).
    float volume_a = (sphere_height - diff_a) / (2.0 * sphere_height);
    float volume_b = (sphere_height - diff_b) / (2.0 * sphere_height);

    // Check if the volumes are valid
    bool valid_a = diff_a <= sphere_height && diff_a >= -sphere_height;
    bool valid_b = diff_b <= sphere_height && diff_b >= -sphere_height;

    // In case either the first or second sample is valid, we can weight them
    if (valid_a || valid_b) {

        // Because we use paired samples, we can easily account for discontinuities:
        // If a is invalid, we can take the inverse of b as value for a, and vice-versa.
        // This works out quite well, even if not mathematically correct.
        accum += valid_a ? volume_a : 1 - volume_b;
        accum += valid_b ? volume_b : 1 - volume_a;

    // In case both samples are invalid, theres nothing we can do. Just increase
    // the integral in this case.
    } else {
        accum += 1.0;
    }

}

// No bent normal supported yet, use pixel normal
vec3 bent_normal = pixel_world_normal;

// Normalize occlusion factor
accum /= num_samples;

// Sphere-Line integrals seem to suffer from under-occlusion, so account for that
// here:
accum = pow(accum, 3.8);

result = vec4(bent_normal, saturate(accum));

