{ lib, ... }:
{
  vim.autocomplete = {
    enableSharedCmpSources = lib.mkForce false;
    blink-cmp = {
      enable = true;

      setupOpts = {
        completion = {
          trigger.show_in_snippet = false;
          list.selection.preselect = false;
        };

        cmdline = {
          keymap.preset = "inherit";
          completion = {
            list.selection.preselect = false;
            menu.auto_show = lib.generators.mkLuaInline ''
              function(ctx)
                return vim.fn.getcmdtype() == ':'
              end
            '';
          };
        };

        keymap = {
          preset = "none";
          "<C-space>" = [
            "show"
            "show_documentation"
            "hide_documentation"
          ];
          "<C-e>" = [
            "hide"
            "fallback"
          ];
          "<Tab>" = [
            (lib.generators.mkLuaInline ''
              function(cmp)
                if cmp.snippet_active() then
                  return cmp.accept()
                else
                  return cmp.select_next()
                end
              end
            '')
            "snippet_forward"
            "fallback"
          ];
          "<Up>" = [
            "select_prev"
            "fallback"
          ];
          "<Down>" = [
            "select_next"
            "fallback"
          ];
          "<C-p>" = [
            "select_prev"
            "fallback_to_mappings"
          ];
          "<C-n>" = [
            "select_next"
            "fallback_to_mappings"
          ];
          "<S-Up>" = [
            "scroll_documentation_up"
            "fallback"
          ];
          "<S-Down>" = [
            "scroll_documentation_down"
            "fallback"
          ];
        };

        sources.providers = {
          path.opts.trailing_slash = false;
          ripgrep.opts.score_offset = -5;
        };
      };

      sourcePlugins = {
        ripgrep.enable = true;
      };

      mappings = {
        close = null;
        complete = null;
        confirm = null;
        next = null;
        previous = null;
        scrollDocsDown = null;
        scrollDocsUp = null;
      };
    };
  };
}
