lib: ns:
let
  inherit (lib)
    attrNames
    filterAttrs
    elem
    head
    tail
    hasSuffix
    mkIf
    mkMerge
    mkEnableOption
    removeAttrs
    functionArgs
    mapAttrs
    isAttrs
    getAttrFromPath
    attrByPath
    setAttrByPath
    splitString
    all
    singleton
    concatStringsSep
    flatten
    recursiveUpdate
    optionalAttrs
    substring
    stringLength
    hasPrefix
    intersectAttrs
    pathExists
    optional
    optionals
    zipAttrsWithNames
    isBool
    isFunction
    isString
    isList
    assertMsg
    concatStrings
    imap0
    ;
  inherit (lib.${ns})
    upperFirstChar
    importCategories
    mkCategory
    mkModule
    asserts
    ;

  # Overview
  # This is a convenience wrapper that aims to reduce boilerplate when creating
  # a custom conditional module system. It recursively imports all modules
  # under a directory and creates category-based options under the configured
  # namespace `ns`.

  # Modules
  # --- Module Arguments ---
  # Additional arguments `args`, `cfg`, and `categoryCfg` are passed to
  # modules. `args` is just the args variable from doing { ... }@args in the
  # normal module system. `cfg` is equivalent to
  # `config.${ns}.<category>.<name>`. For the module alacritty.nix at
  # programs/desktop/alacritty.nix `cfg` would be equivalent to
  # `config.${ns}.programs.desktop.alacritty`. `categoryCfg` is the same but
  # without the module name. In root modules `cfg` == `categoryCfg`.

  # --- Module Config ---
  # The body of the module is always treated as the config. This means options
  # like `options` and `imports` from the normal module system will not work.
  # Instead we define our own set of "additional" module options whose default
  # values are listed below:
  defaultModuleOpts = {
    # All examples will use the module defined at
    # `programs/desktop/gaming/mangohud.nix`. This module is in category
    # `programs.desktop.gaming` and has the name `mangohud`.
    #
    #
    # When set to `true`, a boolean enable option will be created under the
    # module's namespace. The module's config will only be enabled if the
    # created enable option is set to `true`. This option has no effect in root
    # modules.
    #
    # Would create `${ns}.programs.desktop.gaming.mangohud.enable`
    enableOpt = true;

    # Guard type determines how config in the module is `mkIf` guarded with the
    # module conditions. Options such as `enableOpt` and `conditions` determine
    # the module conditions. Possible types:

    # full   - All config is guarded with the module conditions regardless of
    #          whether the module is a list or a single attribute set.
    # first  - The same as 'full' except when a list of configs is provided. In
    #          this case only the first list element (primary config set) is
    #          guarded by the module conditions.
    # custom - Module is not guarded by module conditions at all. Guard
    #          implemention is completely left to the module. With this guard
    #          type module options that create additional config such as
    #          `asserts`, `categoryConfig` and `nsConfig` do not work.
    guardType = "full";

    # This is equivalent to `options` from the NixOS module system except all
    # opts defined in this set have their path prefixed with the category and
    # name of the module.
    #
    # `opts.showFps = mkOption ...` would create an option at path
    # `${ns}.programs.desktop.gaming.mangohud.showFps`
    opts = { };

    # Options to define at the root of our namespace.
    #
    # `nsOpts.backups = mkOption ...` would create an option at path
    # `${ns}.backups`
    nsOpts = { };

    # Configuration to be set under the module's category's namespace.
    #
    # In the mangohud module `categoryConfig.gameClasses = ...` would be
    # equivalent to `${ns}.programs.desktop.gaming.gameClasses`
    categoryConfig = { };

    # Configuration to be set under the root namespace.
    #
    # `nsConfig.services = ...` would be equivalent to `${ns}.services = ...`
    nsConfig = { };

    # List of string|bool conditions that must all eval to `true` to enable the
    # module. Strings are modified to be prefixed with the custom namespace and
    # suffixed with the enable option. String conditions can be prefixed with
    # the special keyword "osConfig" to refer to os config options from Home
    # Manager modules. Bools are evaluated as they are.
    #
    # In the case of standalone Home Manager deployments where `osConfig` is
    # null, conditions with the prefix "osConfig" will eval to `true` unless
    # the prefix "osConfigStrict" is used in which case they will eval to
    # `false`.
    #
    # For example, conditions = [ "osConfig.programs.desktop.gaming"
    # "programs.alacritty" ]; would pass if `osConfig.${ns}.programs.desktop.gaming.enable`
    # and `${ns}.programs.alacritty.enable` are enabled
    conditions = [ ];

    # List of strings in the same form as conditions. An assertion is created
    # for each condition. The only difference to conditions is that
    # requirements will notify the user and fail to eval when the condition is
    # not met.
    #
    # If `osConfig` is null requirements with prefix "osConfig" will by ignored
    # as they eval to `true`. The prefix "osConfigStrict" can be used to eval
    # to `false` and enforce the requirement.
    requirements = [ ];

    # List of alternating bools and strings that are converted to { assertion =
    # ...; message = ...; } assertions.
    asserts = [ ];

    # Same NixOS module imports `imports`. Imports are always defined even if
    # the module is disable.
    imports = [ ];
  };

  # Category-specific options can only be defined in the root (root.nix) module
  # of a category. Root modules are optional. Other than having the added
  # ability of defining category options, root modules are identical to normal
  # modules.
  defaultCategoryOpts = {
    # When set to `true` a boolean enable option will be created under the root
    # module's category. The option guards both the root module itself and all
    # other modules in the category.
    #
    # For example, if module programs/desktop/gaming/root.nix had `enableOpt =
    # true`, the config in both the root module and all other modules in the
    # programs.desktop.gaming category be disabled if `${ns}.programs.desktop.gaming.enable`
    # is not set to true.
    enableOpt = false;

    # A special subset of the available module options that, when set,
    # propogate to both all modules in the category (excluding the root module
    # they are set in) and all sub-categories. `defaultOpts` values are always
    # merged with the set module opts. They are not merged when a sub-category
    # root module defines `defaultOpts` in which case the new values will
    # override the parent category `defaultOpts`.
    #
    # Note: when a root module overrides the `defaultOpts` this causes the root
    # module itself to ignore `defaultOpts` from the parent category. The
    # `defaultOpts` it sets also won't apply to itself.
    #
    # e.g. setting defaultOpts.conditions = [ "osConfig.desktop" ] in
    # programs/desktop/root.nix will ensure that all modules and sub-catagories
    # will only enable if the os desktop option is enabled.
    defaultOpts = {
      conditions = [ ];
      requirements = [ ];
      asserts = [ ];
    };

    # When set to `true` modules in the category will not add their module name
    # to the category namespace. This option implies enableOpt = false for all
    # modules.
    #
    # For example, if programs/desktop/root.nix set noChildren = true and
    # programs/desktop/alacritty.nix defined opts.fontSize = mkOption ...,
    # rather than creating option ${ns}.programs.desktop.alacritty.fontSize it
    # would create ${ns}.programs.desktop.fontSize.
    noChildren = false;
  };

  mergeDefaultOpts =
    a: b:
    zipAttrsWithNames (attrNames defaultCategoryOpts.defaultOpts) (name: values: flatten values) [
      a
      b
    ];
in
{
  importCategories =
    {
      args,
      rootDir,
      categoryPath ? [ ],
      categoryOpts ? defaultCategoryOpts,
      exclude ? [ ],
    }:
    flatten (
      map
        (
          categoryDir:
          let
            newCategoryPath = categoryPath ++ [
              (builtins.unsafeDiscardStringContext (builtins.baseNameOf categoryDir))
            ];

            category = mkCategory {
              inherit args categoryOpts exclude;
              dir = categoryDir;
              categoryPath = newCategoryPath;
            };
          in
          (importCategories {
            inherit args exclude;
            inherit (category) categoryOpts;
            rootDir = categoryDir;
            categoryPath = newCategoryPath;
          })
          ++ category.modules
        )
        (
          map (dir: rootDir + "/${dir}") (
            attrNames (
              filterAttrs (
                path: type:
                type == "directory"
                && path != "disable" # special case for debugging
                && !elem (concatStringsSep "/" (categoryPath ++ [ path ])) exclude
              ) (builtins.readDir rootDir)
            )
          )
        )
    );

  mkCategory =
    {
      args,
      dir,
      categoryPath,
      categoryOpts,
      exclude,
    }:
    let
      rootModule =
        if pathExists (dir + "/root.nix") then
          mkModule {
            inherit args categoryPath;
            categoryOpts' = categoryOpts;
            name = "root";
            moduleBody = import (dir + "/root.nix");
          }
        else
          {
            module = null;
            inherit categoryOpts;
          };
    in
    {
      inherit (rootModule) categoryOpts;
      modules =
        (optional (rootModule.module != null) rootModule.module)
        ++ (map
          (
            modulePath:
            mkModule {
              inherit args categoryPath;
              inherit (modulePath) name;
              categoryOpts' = rootModule.categoryOpts;
              moduleBody = import modulePath.path;
            }
          )
          (
            map
              (f: {
                # It's important to make sure these are treated as paths instead of
                # strings. The rule is to never do string interpolation with path objects e.g.
                # instead of "${dir}/${f}" do dir + "/${f}". Also never use self in paths
                # as self + "/${f}" or "$${self}/${f}". I don't understand why but self
                # always seems to be cast to a string in these scenarios.
                #
                # The problem with using strings instead of paths is that rather that copying
                # each individual file to the store, the files will be referenced in the store
                # relative to a directory. This completly breaks relative imports in modules
                # and (I think) causes all files in my module system to get copied to the store
                # whenever a single file changes. It's also a problem when applying patches, as
                # using a string path to the patch changes the derivation after every small change
                # in the flake, causing many unnecessary rebuilts of patched packages. So for
                # patches it's safe to do ../../../patches/example.patch but NOT safe to do
                # self + "/patches/examples.patch". This is due to the weirdness of self being
                # a string not a path.
                #
                # patches = [
                #   ../../../../../patches/waybarDisableReload.patch
                #   "${self}/patches/waybarDisableReload.patch"
                #   (self + "/patches/waybarDisableReload.patch")
                # ]
                #
                # Produces:
                # {
                #   type = "path";
                #   value = /nix/store/xayrvkck3gxdwbgwx7kbxkcvibxibs1s-source/patches/waybarDisableReload.patch;
                # }
                # {
                #   type = "string";
                #   value = "/nix/store/xayrvkck3gxdwbgwx7kbxkcvibxibs1s-source/patches/waybarDisableReload.patch";
                # }
                # {
                #   type = "string";
                #   value = "/nix/store/xayrvkck3gxdwbgwx7kbxkcvibxibs1s-source/patches/waybarDisableReload.patch";
                # }
                path = dir + "/${f}";
                name = substring 0 ((stringLength f) - 4) f;
              })
              (
                attrNames (
                  filterAttrs (
                    path: type:
                    type == "regular"
                    && (path != "root.nix")
                    && hasSuffix ".nix" path
                    && !elem (concatStringsSep "/" (categoryPath ++ [ path ])) exclude
                  ) (builtins.readDir dir)
                )
              )
          )
        );
    };

  mkModule =
    {
      args,
      categoryPath,
      name,
      moduleBody,
      categoryOpts',
    }:
    let
      isRoot = name == "root";
      isHomeManager = args.config ? home.stateVersion;
      moduleOptionName = concatStrings (
        imap0 (i: s: if i == 0 then s else upperFirstChar s) (splitString "-" name)
      );

      categoryPathString = concatStringsSep "." categoryPath;
      categoryCfg = attrByPath categoryPath { } args.config.${ns};
      cfg =
        if isRoot || categoryOpts.noChildren then categoryCfg else categoryCfg.${moduleOptionName} or null;

      extraArgs = { inherit args cfg categoryCfg; };
      moduleArgs = mapAttrs (
        # https://discourse.nixos.org/t/some-args-in-nixos-module-are-not-visible-but-you-can-still-use-them/28021
        name: _: (extraArgs.${name} or args.${name} or args.config._module.args.${name} or null)
      ) (functionArgs moduleBody);

      configRaw = if isFunction moduleBody then moduleBody moduleArgs else moduleBody;
      configPrimarySetRaw = if isAttrs configRaw then configRaw else head configRaw;
      configPrimarySet =
        if configPrimarySetRaw ? _type then
          assert assertMsg (configPrimarySetRaw._type == "if") "The primary config set cannot use mkMerge";
          configPrimarySetRaw.contents
        else
          configPrimarySetRaw;

      setCategoryOpts = intersectAttrs defaultCategoryOpts configPrimarySet;
      categoryOpts =
        if isRoot then
          recursiveUpdate (defaultCategoryOpts // { inherit (categoryOpts') defaultOpts; }) setCategoryOpts
        else
          categoryOpts';

      setModuleOpts = intersectAttrs defaultModuleOpts configPrimarySet;
      mergedModuleOpts =
        if !isRoot then mergeDefaultOpts setModuleOpts categoryOpts.defaultOpts else setModuleOpts;
      moduleOpts = (defaultModuleOpts // setModuleOpts) // mergedModuleOpts;

      strippedConfig =
        let
          strippedPrimarySet' = removeAttrs configPrimarySet (
            attrNames (moduleOpts // optionalAttrs isRoot categoryOpts)
          );
          strippedPrimarySet =
            if configPrimarySetRaw ? _type then
              configPrimarySetRaw // { contents = strippedPrimarySet'; }
            else
              strippedPrimarySet';
        in
        if isAttrs configRaw then
          strippedPrimarySet
        else if isList configRaw then
          [ strippedPrimarySet ] ++ tail configRaw
        else
          throw "configRaw has unexpected type ${builtins.typeOf configRaw}";

      throwMsg = ''
        ${
          if isHomeManager then "Home Manager module" else "NixOS module"
        } '${name}' in category '${categoryPathString}'
      '';

      conditionsResult = all (
        condition:
        if isString condition then
          if hasPrefix "osConfig" condition then
            if !isHomeManager then
              throw ''
                ${throwMsg} contains a condition using 'osConfig'. This is only supported in Home Manager modules.
              ''
            else if args.osConfig or null == null then
              !hasPrefix "osConfigStrict" condition
            else
              getAttrFromPath ([ ns ] ++ (tail (splitString "." condition)) ++ [ "enable" ]) args.osConfig
          else
            getAttrFromPath ([ ns ] ++ (splitString "." condition) ++ [ "enable" ]) args.config
        else if isBool condition then
          condition
        else
          throw ''
            ${throwMsg} defines a condition with unsupported type '${builtins.typeOf condition}'.
          ''
      ) moduleOpts.conditions;

      requirementAssertions = map (
        requirement:
        if isString requirement then
          let
            message = ''
              ${throwMsg} requires '${requirement}' to be enabled
            '';
          in
          if hasPrefix "osConfig" requirement then
            if !isHomeManager then
              throw ''
                ${throwMsg} contains a requirement using 'osConfig'. This is only supported in Home Manager modules.
              ''
            else if args.osConfig == null then
              {
                assertion = !hasPrefix "osConfigStrict" requirement;
                message = "";
              }
            else
              {
                assertion = getAttrFromPath (
                  [ ns ] ++ (tail (splitString "." requirement)) ++ [ "enable" ]
                ) args.osConfig;
                inherit message;
              }
          else
            {
              assertion = getAttrFromPath ([ ns ] ++ (splitString "." requirement) ++ [ "enable" ]) args.config;
              inherit message;
            }
        else
          throw ''
            ${throwMsg} contains a requirement with unsupported type '${builtins.typeOf requirement}'.
          ''
      ) moduleOpts.requirements;

      module =
        { ... }:
        {
          imports = moduleOpts.imports;

          options.${ns} =
            let
              options' =
                (optionalAttrs
                  (
                    (!isRoot && moduleOpts.enableOpt && !categoryOpts.noChildren) || (isRoot && categoryOpts.enableOpt)
                  )
                  {
                    enable = mkEnableOption name;
                  }
                )
                // moduleOpts.opts;
            in
            moduleOpts.nsOpts
            // (optionalAttrs (options' != { }) (
              setAttrByPath (
                if isRoot || categoryOpts.noChildren then categoryPath else categoryPath ++ [ moduleOptionName ]
              ) options'
            ));

          config =
            let
              extraConfig =
                singleton {
                  assertions =
                    requirementAssertions
                    ++ (asserts (map (a: if isString a then "[${throwMsg}] ${a}" else a) moduleOpts.asserts));
                }
                ++ (optional (moduleOpts.categoryConfig != { }) (
                  setAttrByPath ([ ns ] ++ categoryPath) moduleOpts.categoryConfig
                ))
                ++ (optional (moduleOpts.nsConfig != { }) (setAttrByPath [ ns ] moduleOpts.nsConfig));

              primarySetEnabled = (cfg.enable or true) && (categoryCfg.enable or true) && conditionsResult;

              guardTypeImpls = {
                full = mkIf primarySetEnabled (mkMerge (flatten [ strippedConfig ] ++ extraConfig));

                first = (
                  mkMerge (
                    singleton (
                      mkIf primarySetEnabled (
                        mkMerge (
                          singleton (
                            if (isAttrs strippedConfig) then
                              strippedConfig
                            else if (isList strippedConfig) then
                              head strippedConfig
                            else
                              throw "Stripped config has unexpected type ${builtins.typeOf strippedConfig}"
                          )
                          ++ extraConfig
                        )
                      )
                    )
                    ++ optionals (isList strippedConfig) (tail strippedConfig)
                  )
                );

                # WARN: Since extraConfig is not applied when guardType is custom we must
                # assert that module options generating this config are not used.
                custom =
                  let
                    assertIncompat =
                      option:
                      assertMsg (
                        moduleOpts.guardType == "custom" -> moduleOpts.${option} == defaultModuleOpts.${option}
                      ) "${throwMsg} uses `${option}` which is not compatible with `guardType` 'custom'";
                  in
                  assert assertIncompat "asserts";
                  assert assertIncompat "categoryConfig";
                  assert assertIncompat "nsConfig";
                  mkMerge (flatten [ strippedConfig ]);
              };
            in
            guardTypeImpls.${moduleOpts.guardType};
        };
    in
    if isRoot then { inherit module categoryOpts; } else module;
}
