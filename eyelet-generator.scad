// =====================================================================
// Eyelet Generator — Parametric Model Maker (PMM) Compatible
// Generates various eyelet types for outdoor & camping gear
//
// Author: Vilda (Vilém Kužel) & Klepeto
// License: CC-BY-SA-4.0
// Repository: https://github.com/vildakuzel/openscad-eyelet-generator
// =====================================================================

/* [Eyelet Type] */
// Select eyelet type
eyelet_type = 1; // [1:Simple O, 2:Simple 8, 3:Double O Egg, 4:Snowman, 5:Triangle, 6:Joined 8, 7:Joined Snowman, 8:Simple D, 9:Double D, 10:Simple S]

/* [Dimensions] */
// Wall thickness — thickness of the eyelet ring wall
wall_thickness = 3; // [1:1:10]

// Height — extrusion height of the eyelet
height = 3; // [1:1:10]

// Base inner diameter — inner diameter of the primary ring
base_o_diameter = 15; // [1:1:150]

// Second inner diameter — inner diameter of the second ring (Simple 8, Double O Egg, Snowman, Triangle, Joined 8, Simple S)
second_o_diameter = 5; // [1:1:150]

// Third inner diameter — inner diameter of the third ring (Snowman, Triangle)
third_o_diameter = 10; // [1:1:150]

/* [3D Edge Filleting] */
// Bottom edge radius — rounds the bottom edge of the eyelet
bottom_edge_fillet = 0; // [0:0.1:10]

// Top edge radius — rounds the top edge of the eyelet
top_edge_fillet = 0; // [0:0.1:10]

// Fillet resolution — number of layers for edge rounding (higher = smoother, slower)
fillet_steps = 10; // [1:1:30]

/* [2D Smoothing] */
// Connection fillet radius — rounds V-junctions where rings meet
fillet_radius = 2; // [0:0.1:10]

/* [S Shape — Hook 1] */
// Hook 1 — percentage of a full circle (larger = more closed loop)
s_arc_1_pct = 83; // [70:1:100]

/* [S Shape — Hook 2] */
// Hook 2 — percentage of a full circle (larger = more closed loop)
s_arc_2_pct = 83; // [70:1:100]

/* [Color] */
// Eyelet color
eyelet_color = "#2F80ED"; // color

/* [Hidden] */
$fn = 64;

// Derived radius values
inner_radius = base_o_diameter / 2;
outer_radius = inner_radius + wall_thickness;

second_inner_radius = second_o_diameter / 2;
second_outer_radius = second_inner_radius + wall_thickness;

third_inner_radius = third_o_diameter / 2;
third_outer_radius = third_inner_radius + wall_thickness;

// Ring center offsets (outer edges touching)
ring_offset_1 = inner_radius + wall_thickness + second_inner_radius;
ring_offset_2 = ring_offset_1 + second_inner_radius + wall_thickness + third_inner_radius;

// Joined offsets (centers closer, inner holes connected)
joined_offset_1 = inner_radius + second_inner_radius - wall_thickness;
joined_offset_2 = joined_offset_1 + second_inner_radius + third_inner_radius - wall_thickness;

// Triangle layout — pairwise distances and vertex coordinates
d12 = inner_radius + wall_thickness + second_inner_radius;
d13 = inner_radius + wall_thickness + third_inner_radius;
d23 = second_inner_radius + wall_thickness + third_inner_radius;
tri_x = (d12*d12 + d13*d13 - d23*d23) / (2 * d12);
tri_y = sqrt(max(0, d13*d13 - tri_x*tri_x));

// =====================================================================
// Geometry Helpers
// =====================================================================

// Smooth concave V-junctions by shrinking then growing the shape.
// Use on union() of touching circles to round the inner V where they meet.
// offset(-r) cuts the V tip, offset(+r) restores with a rounded curve.
module smooth_concave(r) {
    if (r > 0) { offset(r = -r) offset(r = r) children(); }
    else { children(); }
}

// Smooth convex sharp tips by growing then shrinking the shape.
// Use on shapes with outward-pointing corners (e.g. D-shape junctions).
// offset(+r) rounds the tip outward, offset(-r) shrinks back to size.
module smooth_convex(r) {
    if (r > 0) { offset(r = r) offset(r = -r) children(); }
    else { children(); }
}

// Simple ring (annulus) — outer cylinder minus inner cylinder
module ring(r_outer, r_inner, h) {
    difference() {
        cylinder(h = h, r = r_outer);
        translate([0, 0, -1]) cylinder(h = h + 2, r = r_inner);
    }
}

// Layered extrusion with independent top and bottom edge fillets.
// Takes a 2D children() shape and extrudes it with rounded top/bottom edges.
// Uses layered linear_extrude with cosine-eased 2D offset() per layer.
module stepped_fillet_extrusion(h, bot_r, top_r, steps) {
    safe_bot = min(bot_r, h / 2);
    safe_top = min(top_r, h / 2);
    mid_h = h - safe_bot - safe_top;

    if (safe_bot == 0 && safe_top == 0) {
        linear_extrude(h) children();
    } else {
        // Bottom fillet — profile shrinks toward the bottom edge
        if (safe_bot > 0)
            for (i = [0 : steps - 1]) {
                z_start = i * safe_bot / steps;
                z_end = z_start + safe_bot / steps;
                z_mid = (z_start + z_end) / 2;
                t = z_mid / safe_bot;
                off = safe_bot * (1 - sin(t * 90));
                translate([0, 0, z_start])
                    linear_extrude(safe_bot / steps + 0.001)
                        offset(r = -off) children();
            }
        // Middle zone — full profile, no offset
        if (mid_h > 0)
            translate([0, 0, safe_bot])
                linear_extrude(mid_h + 0.001) children();
        // Top fillet — mirrored bottom fillet for convex rounding
        if (safe_top > 0)
            mirror([0, 0, 1])
                translate([0, 0, -h])
                for (i = [0 : steps - 1]) {
                    z_start = i * safe_top / steps;
                    z_end = z_start + safe_top / steps;
                    z_mid = (z_start + z_end) / 2;
                    t = z_mid / safe_top;
                    off = safe_top * (1 - sin(t * 90));
                    translate([0, 0, z_start])
                        linear_extrude(safe_top / steps + 0.001)
                            offset(r = -off) children();
                }
    }
}

// Generate points along a circular arc (used for S-shape polygon paths)
function arc_points(center, r, start_angle, direction, sweep, n = 48) =
    [for (i = [0 : n]) let(a = start_angle + direction * sweep * i / n)
        [center[0] + r * cos(a), center[1] + r * sin(a)]];

// =====================================================================
// Eyelet Types
// =====================================================================

// Type 1: Simple O — a single ring with inner and outer diameter
module simple_o_eyelet() {
    stepped_fillet_extrusion(height, bottom_edge_fillet, top_edge_fillet, fillet_steps)
    difference() { circle(r = outer_radius); circle(r = inner_radius); }
}

// Type 2: Simple 8 — two rings side by side, outer edges touching
// Connection fillet smooths the V-junction on the outer perimeter
module simple_8_eyelet() {
    stepped_fillet_extrusion(height, bottom_edge_fillet, top_edge_fillet, fillet_steps)
    difference() {
        smooth_concave(fillet_radius)
        union() {
            circle(r = outer_radius);
            translate([ring_offset_1, 0]) circle(r = second_outer_radius);
        }
        circle(r = inner_radius);
        translate([ring_offset_1, 0]) circle(r = second_inner_radius);
    }
}

// Type 3: Double O Egg — two rings inside a smooth egg-shaped envelope
// hull() creates a tangent bridge between the two outer circles
module double_o_egg_eyelet() {
    stepped_fillet_extrusion(height, bottom_edge_fillet, top_edge_fillet, fillet_steps)
    difference() {
        hull() {
            circle(r = outer_radius);
            translate([ring_offset_1, 0]) circle(r = second_outer_radius);
        }
        circle(r = inner_radius);
        translate([ring_offset_1, 0]) circle(r = second_inner_radius);
    }
}

// Type 4: Snowman — three rings in a row, outer edges touching
module snowman_eyelet() {
    stepped_fillet_extrusion(height, bottom_edge_fillet, top_edge_fillet, fillet_steps)
    difference() {
        smooth_concave(fillet_radius)
        union() {
            circle(r = outer_radius);
            translate([ring_offset_1, 0]) circle(r = second_outer_radius);
            translate([ring_offset_2, 0]) circle(r = third_outer_radius);
        }
        circle(r = inner_radius);
        translate([ring_offset_1, 0]) circle(r = second_inner_radius);
        translate([ring_offset_2, 0]) circle(r = third_inner_radius);
    }
}

// Type 5: Triangle — three rings at triangle vertices, outer edges touching
// Ring positions computed via law of cosines from pairwise distances
module triangle_eyelet() {
    stepped_fillet_extrusion(height, bottom_edge_fillet, top_edge_fillet, fillet_steps)
    difference() {
        smooth_concave(fillet_radius)
        union() {
            circle(r = outer_radius);
            translate([d12, 0]) circle(r = second_outer_radius);
            translate([tri_x, tri_y]) circle(r = third_outer_radius);
        }
        circle(r = inner_radius);
        translate([d12, 0]) circle(r = second_inner_radius);
        translate([tri_x, tri_y]) circle(r = third_inner_radius);
    }
}

// Type 6: Joined 8 — two rings with centers closer, inner holes connected
// Fillet applied to both outer and inner junctions
module joined_8_eyelet() {
    stepped_fillet_extrusion(height, bottom_edge_fillet, top_edge_fillet, fillet_steps)
    difference() {
        smooth_concave(fillet_radius)
        union() {
            circle(r = outer_radius);
            translate([joined_offset_1, 0]) circle(r = second_outer_radius);
        }
        smooth_concave(fillet_radius)
        union() {
            circle(r = inner_radius);
            translate([joined_offset_1, 0]) circle(r = second_inner_radius);
        }
    }
}

// Type 7: Joined Snowman — three rings in a row, inner holes connected
module joined_snowman_eyelet() {
    stepped_fillet_extrusion(height, bottom_edge_fillet, top_edge_fillet, fillet_steps)
    difference() {
        smooth_concave(fillet_radius)
        union() {
            circle(r = outer_radius);
            translate([joined_offset_1, 0]) circle(r = second_outer_radius);
            translate([joined_offset_2, 0]) circle(r = third_outer_radius);
        }
        smooth_concave(fillet_radius)
        union() {
            circle(r = inner_radius);
            translate([joined_offset_1, 0]) circle(r = second_inner_radius);
            translate([joined_offset_2, 0]) circle(r = third_inner_radius);
        }
    }
}

// Type 8: Simple D — half ring with a flat closing wall (D-shape)
// Convex fillet rounds the corners where the curve meets the flat wall
module simple_d_eyelet() {
    eps = 0.01;
    stepped_fillet_extrusion(height, bottom_edge_fillet, top_edge_fillet, fillet_steps)
    difference() {
        smooth_convex(fillet_radius)
        union() {
            // Right half of outer circle
            intersection() {
                circle(r = outer_radius);
                translate([-eps, -outer_radius - 1])
                    square([outer_radius + 1 + eps, (outer_radius + 1) * 2]);
            }
            // Flat closing wall on the left
            translate([-wall_thickness, -outer_radius])
                square([wall_thickness + eps, outer_radius * 2]);
        }
        // Right half of inner hole
        smooth_convex(fillet_radius)
        intersection() {
            circle(r = inner_radius);
            translate([0, -inner_radius - 1])
                square([inner_radius + 1, (inner_radius + 1) * 2]);
        }
    }
}

// Type 9: Double D — ring split in half by a center dividing wall
// Two D-shaped openings with wall_thickness gap between them
module double_d_eyelet() {
    stepped_fillet_extrusion(height, bottom_edge_fillet, top_edge_fillet, fillet_steps)
    difference() {
        circle(r = outer_radius);
        // Left half of inner hole
        smooth_convex(fillet_radius)
        intersection() {
            circle(r = inner_radius);
            translate([-inner_radius - 1, -inner_radius - 1])
                square([inner_radius + 1 - wall_thickness / 2, inner_radius * 2 + 2]);
        }
        // Right half of inner hole
        smooth_convex(fillet_radius)
        intersection() {
            circle(r = inner_radius);
            translate([wall_thickness / 2, -inner_radius - 1])
                square([inner_radius + 1, inner_radius * 2 + 2]);
        }
    }
}

// Type 10: Simple S — S-shaped curve made of two arcs sharing a point
// Each arc is a partial circle (70–100%), built as hull() of circles along the path
// Arc 1 curves left-up, Arc 2 curves right-down, forming an S-shape
module simple_s_eyelet() {
    tube_radius = wall_thickness / 2;
    step = 4; // Angular step in degrees

    // Convert percentage to sweep angle
    arc_1_angle = s_arc_1_pct / 100 * 360;
    arc_2_angle = s_arc_2_pct / 100 * 360;

    stepped_fillet_extrusion(height, bottom_edge_fillet, top_edge_fillet, fillet_steps)
    union() {
        // Hook 1: curve to the left and up (center at [-inner_radius, 0])
        for (i = [0 : step : arc_1_angle - step]) {
            hull() {
                translate([-inner_radius + inner_radius * cos(i), inner_radius * sin(i)])
                    circle(r = tube_radius);
                translate([-inner_radius + inner_radius * cos(i + step), inner_radius * sin(i + step)])
                    circle(r = tube_radius);
            }
        }
        // Hook 2: curve to the right and down (center at [second_inner_radius, 0])
        for (i = [180 : step : 180 + arc_2_angle - step]) {
            hull() {
                translate([second_inner_radius + second_inner_radius * cos(i), second_inner_radius * sin(i)])
                    circle(r = tube_radius);
                translate([second_inner_radius + second_inner_radius * cos(i + step), second_inner_radius * sin(i + step)])
                    circle(r = tube_radius);
            }
        }
    }
}

// =====================================================================
// Output — route by eyelet type
// =====================================================================

color(eyelet_color)
    if (eyelet_type == 1) { simple_o_eyelet(); }
    else if (eyelet_type == 2) { simple_8_eyelet(); }
    else if (eyelet_type == 3) { double_o_egg_eyelet(); }
    else if (eyelet_type == 4) { snowman_eyelet(); }
    else if (eyelet_type == 5) { triangle_eyelet(); }
    else if (eyelet_type == 6) { joined_8_eyelet(); }
    else if (eyelet_type == 7) { joined_snowman_eyelet(); }
    else if (eyelet_type == 8) { simple_d_eyelet(); }
    else if (eyelet_type == 9) { double_d_eyelet(); }
    else if (eyelet_type == 10) { simple_s_eyelet(); }