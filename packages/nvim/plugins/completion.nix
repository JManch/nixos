{ lib, ... }:
let
  inherit (lib.generators) mkLuaInline;
in
{
  vim.autocomplete = {
    enableSharedCmpSources = lib.mkForce false;
    blink-cmp = {
      enable = true;
      friendly-snippets.enable = true;

      setupOpts = {
        appearance.use_nvim_cmp_as_default = true;
        signature.enabled = true;
        signature.window.show_documentation = true;
        completion = {
          trigger.show_in_snippet = false;
          list.selection.preselect = false;
          menu = {
            scrollbar = false;
            draw = {
              components.client_name.text = mkLuaInline ''
                function(ctx)
                  return '[' .. (ctx.item.client_name or ctx.source_id or ctx.source_name) .. ']'
                end
              '';
              columns = [
                [
                  "label"
                  "label_description"
                  (mkLuaInline "gap = 1")
                ]
                [
                  "kind_icon"
                  (mkLuaInline "gap = 1")
                  "kind"
                ]
                [ "client_name" ]
              ];
            };
          };
        };

        cmdline = {
          keymap.preset = "inherit";
          completion = {
            list.selection.preselect = false;
            menu.auto_show = mkLuaInline ''
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
          "<C-s>" = [
            "show_signature"
            "hide_signature"
            "fallback"
          ];
          "<C-e>" = [
            "hide"
            "fallback"
          ];
          "<C-y>" = [
            "select_and_accept"
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
            "scroll_signature_up"
            "fallback"
          ];
          "<S-Down>" = [
            "scroll_documentation_down"
            "scroll_signature_down"
            "fallback"
          ];
        };

        sources = {
          providers = {
            path.opts.trailing_slash = false;
          };
        };
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
