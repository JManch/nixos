{ lib, pkgs, config, ... }:
let
  inherit (lib.hm.gvariant) mkTuple;
  cfg = config.modules.programs.rnote;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.rnote ];

  dconf.settings = {
    "com/github/flxzt/rnote" = {
      active-fill-color = mkTuple [ 0.0 0.0 0.0 0.0 ];
      active-stroke-color = mkTuple [ 0.0 0.0 0.0 1.0 ];
      engine-config = ''
        {"document":{"x":-2771.085,"y":-3552.537,"width":6864.794,"height":8896.596,"format":{"width":793.701,"height":1122.52,"dpi":96.0,"orientation":"portrait","border_color":{"r":0.871,"g":0.867,"b":0.855,"a":1.0},"show_borders":true,"show_origin_indicator":true},"background":{"color":{"r":1.0,"g":0.992,"b":0.903,"a":1.0},"pattern":"lines","pattern_size":[32.0,29.0],"pattern_color":{"r":0.753,"g":0.749,"b":0.737,"a":1.0}},"layout":"infinite","snap_positions":false},"pens_config":{"brush_config":{"builder_type":"modeled","style":"solid","marker_options":{"stroke_width":12.0,"stroke_color":{"r":0.0,"g":0.0,"b":0.0,"a":1.0},"fill_color":{"r":0.0,"g":0.0,"b":0.0,"a":0.0},"pressure_curve":"const"},"solid_options":{"stroke_width":1.8,"stroke_color":{"r":0.0,"g":0.0,"b":0.0,"a":1.0},"fill_color":{"r":0.0,"g":0.0,"b":0.0,"a":0.0},"pressure_curve":"linear"},"textured_options":{"seed":4831609229552868368,"stroke_width":6.0,"stroke_color":{"r":0.0,"g":0.0,"b":0.0,"a":1.0},"density":5.0,"distribution":"Normal","pressure_curve":"linear"}},"shaper_config":{"builder_type":"line","style":"smooth","smooth_options":{"stroke_width":2.0,"stroke_color":{"r":0.0,"g":0.0,"b":0.0,"a":1.0},"fill_color":{"r":0.0,"g":0.0,"b":0.0,"a":0.0},"pressure_curve":"linear"},"rough_options":{"stroke_color":{"r":0.0,"g":0.0,"b":0.0,"a":1.0},"stroke_width":2.4,"fill_color":{"r":0.0,"g":0.0,"b":0.0,"a":0.0},"fill_style":"hachure","hachure_angle":-0.716,"seed":16489422674812916241},"constraints":{"enabled":false,"ratios":["one_to_one","horizontal","vertical"]}},"typewriter_config":{"text_style":{"font_family":"serif","font_size":32.0,"font_weight":500,"font_style":"regular","color":{"r":0.0,"g":0.0,"b":0.0,"a":1.0},"max_width":null,"alignment":"start","ranged_text_attributes":[]},"text_width":600.0},"eraser_config":{"width":12.0,"style":"trash_colliding_strokes"},"selector_config":{"style":"rectangle","resize_lock_aspectratio":false},"tools_config":{"style":"offsetcamera"}},"penholder":{"shortcuts":{"drawing_pad_button_1":{"change_pen_style":{"style":"shaper","mode":"permanent"}},"stylus_secondary_button":{"change_pen_style":{"style":"tools","mode":"temporary"}},"touch_two_finger_long_press":{"change_pen_style":{"style":"eraser","mode":"toggle"}},"drawing_pad_button_0":{"change_pen_style":{"style":"brush","mode":"permanent"}},"drawing_pad_button_2":{"change_pen_style":{"style":"typewriter","mode":"permanent"}},"stylus_primary_button":{"change_pen_style":{"style":"eraser","mode":"temporary"}},"mouse_secondary_button":{"change_pen_style":{"style":"shaper","mode":"temporary"}},"drawing_pad_button_3":{"change_pen_style":{"style":"eraser","mode":"permanent"}},"keyboard_ctrl_space":{"change_pen_style":{"style":"tools","mode":"toggle"}}},"pen_mode_state":{"pen_mode":"pen","penmode_pen_style":"brush","penmode_eraser_style":"eraser"}},"import_prefs":{"pdf_import_prefs":{"page_width_perc":50.0,"page_spacing":"continuous","pages_type":"vector","bitmap_scalefactor":1.8,"page_borders":true,"adjust_document":false},"xopp_import_prefs":{"pages_type":96.0}},"export_prefs":{"doc_export_prefs":{"with_background":true,"with_pattern":true,"optimize_printing":false,"export_format":"pdf","page_order":"row_major"},"doc_pages_export_prefs":{"with_background":true,"with_pattern":true,"optimize_printing":false,"export_format":"svg","page_order":"row_major","bitmap_scalefactor":1.8,"jpg_quality":85},"selection_export_prefs":{"with_background":true,"with_pattern":false,"optimize_printing":false,"export_format":"svg","bitmap_scalefactor":1.8,"jpg_quality":85,"margin":12.0}},"pen_sounds":false}
      '';
      regular-cursor = "cursor-dot-large";
      sidebar-show = false;
    };
  };
}
