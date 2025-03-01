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
    setDefaultModuleLocation
    zipAttrsWithNames
    isBool
    isFunction
    isString
    isList
    assertMsg
    hasAttr
    concatMapStringsSep
    imap
    zipAttrsWith
    concatLists
    unique
    last
    ;
  inherit (lib.${ns})
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
    # created enable option is set to `true`. This option has a different
    # meaning in root modules.
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
    #          `asserts`, `categoryConfig` and `ns` do not work.
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
    # `ns.services = ...` would be equivalent to `${ns}.services = ...`
    ns = { };

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

    # List of file names or directories in the current category to not import.
    # Does not use paths relative to the root import dir like importCategories
    # exclude does.
    #
    # e.g. exclude = [ "raspberry-pi.nix" "special" ];
    exclude = [ ];
  };

  optTypes = {
    # Option that can only be used in the primary config set
    primary = {
      enableOpt = true;
      guardType = true;
      conditions = true;
      noChildren = true;
      defaultOpts = true;
    };

    # Options that can will be merged when defined in multiple config sets
    merge = {
      opts = true;
      nsOpts = true;
      imports = true;
      exclude = true;
    };

    # Options that are just aliases and will be applied to the config set they
    # were defined in
    alias = {
      ns = true;
      categoryConfig = true;
      asserts = true;
      requirements = true;
    };
  };

  mergeDefaultOpts =
    a: b:
    zipAttrsWithNames (attrNames defaultCategoryOpts.defaultOpts) (name: values: flatten values) [
      a
      b
    ];

  # source: https://stackoverflow.com/questions/54504685/nix-function-to-merge-attributes-records-recursively-and-concatenate-arrays/54505212#54505212
  recursiveMerge =
    attrList:
    let
      f =
        attrPath:
        zipAttrsWith (
          n: values:
          if tail values == [ ] then
            head values
          else if all isList values then
            unique (concatLists values)
          else if all isAttrs values then
            f (attrPath ++ [ n ]) values
          else
            last values
        );
    in
    f [ ] attrList;
in
{
  importCategories =
    {
      args,
      rootDir,
      isHomeManager ? false,
      categoryPath ? [ ],
      categoryOpts ? defaultCategoryOpts,
      exclude ? [ ], # list of paths relative to the rootDir
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
              inherit
                args
                categoryOpts
                isHomeManager
                exclude
                ;
              dir = categoryDir;
              categoryPath = newCategoryPath;
            };
          in
          (importCategories {
            inherit args isHomeManager exclude;
            inherit (category) categoryOpts;
            rootDir = categoryDir;
            categoryPath = newCategoryPath;
          })
          ++ category.modules
        )
        (
          map (dir: rootDir + "/${dir}") (
            attrNames (
              let
                allExcludes =
                  exclude ++ (map (c: concatStringsSep "/" (categoryPath ++ [ c ])) categoryOpts.exclude);
              in
              filterAttrs (
                path: type:
                type == "directory" && !elem (concatStringsSep "/" (categoryPath ++ [ path ])) allExcludes
              ) (builtins.readDir rootDir)
            )
          )
        )
    );

  mkCategory =
    {
      args,
      dir,
      isHomeManager,
      categoryPath,
      categoryOpts,
      exclude,
    }:
    let
      rootModule =
        if pathExists (dir + "/root.nix") then
          mkModule {
            inherit args categoryPath isHomeManager;
            categoryOpts' = categoryOpts;
            name = "root";
            path = dir + "/root.nix";
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
            moduleFile:
            mkModule {
              inherit args categoryPath isHomeManager;
              inherit (moduleFile) name path;
              categoryOpts' = rootModule.categoryOpts;
              moduleBody = import moduleFile.path;
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
                    && !elem path rootModule.categoryOpts.exclude
                  ) (builtins.readDir dir)
                )
              )
          )
        );
    };

  mkModule =
    {
      args,
      path,
      categoryPath,
      isHomeManager,
      name,
      moduleBody,
      categoryOpts',
    }:
    let
      isRoot = name == "root";

      categoryPathString = concatStringsSep "." categoryPath;
      categoryCfg = attrByPath categoryPath { } args.config.${ns};
      cfg = if isRoot || categoryOpts.noChildren then categoryCfg else categoryCfg.${name} or null;

      extraArgs = { inherit args cfg categoryCfg; };
      moduleArgs = mapAttrs (
        # https://discourse.nixos.org/t/some-args-in-nixos-module-are-not-visible-but-you-can-still-use-them/28021
        name: _: (extraArgs.${name} or args.${name} or args.config._module.args.${name} or null)
      ) (functionArgs moduleBody);

      configRaw = if isFunction moduleBody then moduleBody moduleArgs else moduleBody;

      processedConfigSets = imap (
        i: configSet:
        let
          isPrimary = i == 1;
          content = configSet.content or configSet;
          setModuleOpts = intersectAttrs defaultModuleOpts content;

          moduleOpts =
            if isPrimary && !isRoot then
              (defaultModuleOpts // setModuleOpts) // (mergeDefaultOpts setModuleOpts categoryOpts.defaultOpts)
            else
              defaultModuleOpts // setModuleOpts;

          setPrimaryOpts = intersectAttrs optTypes.primary setModuleOpts;

          setCategoryOpts = intersectAttrs defaultCategoryOpts content;
          categoryOpts =
            if isRoot then
              recursiveUpdate (defaultCategoryOpts // { inherit (categoryOpts') defaultOpts; }) setCategoryOpts
            else
              categoryOpts';

          strippedContent = removeAttrs content (attrNames (defaultModuleOpts // defaultCategoryOpts));

          extraContent =
            singleton {
              assertions =
                (mkRequirementAssertions moduleOpts.requirements)
                ++ (asserts (map (a: if isString a then "[${throwMsg}] ${a}" else a) moduleOpts.asserts));
            }
            ++ (optional (moduleOpts.ns != { }) (setAttrByPath [ ns ] moduleOpts.ns))
            ++ (optional (moduleOpts.categoryConfig != { }) (
              setAttrByPath ([ ns ] ++ categoryPath) moduleOpts.categoryConfig
            ));

          processedConfig =
            if content ? _type then
              configSet
            else if configSet ? _type then
              assert assertMsg (configSet._type == "if") "This only support mkIf";
              configSet
              // {
                content = mkMerge ([ strippedContent ] ++ extraContent);
              }
            else
              mkMerge ([ strippedContent ] ++ extraContent);
        in
        assert assertMsg (
          isPrimary -> configSet._type or "if" == "if"
        ) "${throwMsg} uses mkMerge in the primary config set.";

        assert assertMsg (!isPrimary -> setPrimaryOpts == { })
          "${throwMsg} uses primary module opt(s) in a non-primary config set: ${
            concatMapStringsSep ", " (s: "`${s}`") (attrNames setPrimaryOpts)
          }.";

        assert assertMsg (
          isPrimary -> configSet._type or "if" == "if"
        ) "${throwMsg} uses mkMerge in the primary config set.";
        # Only parse config sets that use mkIf and do not have nested
        # mkMerge/mkIfs. Trying to process nested sets would be quite complex
        # and is such a rare case that it isn't worth it
        if content ? _type then
          {
            setModuleOpts = { };
            moduleOpts = defaultModuleOpts;
            inherit processedConfig;
          }
        else
          {
            inherit
              setModuleOpts
              setCategoryOpts
              moduleOpts
              categoryOpts
              processedConfig
              ;
          }
      ) (flatten [ configRaw ]);

      inherit (head processedConfigSets) categoryOpts;
      primaryModuleOpts = (head processedConfigSets).moduleOpts;

      # WARN: Not all merged options are correct to use. Some do not support
      # merging because they depend on conditional guards of the primary config set.
      mergedModuleOpts = recursiveMerge (map (configSet: configSet.moduleOpts) processedConfigSets);

      throwMsg = "${
        if isHomeManager then "Home Manager module" else "NixOS module"
      } '${name}' in category '${categoryPathString}'";

      conditionsResult = all (
        condition:
        if isString condition then
          if hasPrefix "osConfig" condition then
            if !isHomeManager then
              throw "${throwMsg} contains a condition using 'osConfig'. This is only supported in Home Manager modules."
            else if args.osConfig or null == null then
              !hasPrefix "osConfigStrict" condition
            else
              getAttrFromPath ([ ns ] ++ (tail (splitString "." condition)) ++ [ "enable" ]) args.osConfig
          else
            getAttrFromPath ([ ns ] ++ (splitString "." condition) ++ [ "enable" ]) args.config
        else if isBool condition then
          condition
        else
          throw "${throwMsg} defines a condition with unsupported type '${builtins.typeOf condition}'."
      ) primaryModuleOpts.conditions;

      mkRequirementAssertions =
        requirements:
        map (
          requirement:
          if isString requirement then
            let
              message = "${throwMsg} requires '${requirement}' to be enabled.";
            in
            if hasPrefix "osConfig" requirement then
              if !isHomeManager then
                throw "${throwMsg} contains a requirement using 'osConfig'. This is only supported in Home Manager modules."
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
            throw "${throwMsg} contains a requirement with unsupported type '${builtins.typeOf requirement}'."
        ) requirements;

      module =
        # This ensures that things like definitionsWithLocations and error
        # messages give correct locations
        setDefaultModuleLocation path (
          { ... }:
          {
            imports = mergedModuleOpts.imports;

            options.${ns} =
              let
                options' =
                  (optionalAttrs (
                    (!isRoot && primaryModuleOpts.enableOpt && !categoryOpts.noChildren)
                    || (isRoot && categoryOpts.enableOpt)
                  ) { enable = mkEnableOption name; })
                  // mergedModuleOpts.opts;
              in
              mergedModuleOpts.nsOpts
              // (optionalAttrs (options' != { }) (
                setAttrByPath (
                  if isRoot || categoryOpts.noChildren then categoryPath else categoryPath ++ [ name ]
                ) options'
              ));

            config =
              let
                primarySetEnabled = (cfg.enable or true) && (categoryCfg.enable or true) && conditionsResult;

                guardTypeImpls = {
                  full = mkIf primarySetEnabled (
                    mkMerge (map (configSet: configSet.processedConfig) processedConfigSets)
                  );

                  first = (
                    mkMerge (
                      singleton (mkIf primarySetEnabled ((head processedConfigSets).processedConfig))
                      ++ map (configSet: configSet.processedConfig) (tail processedConfigSets)
                    )
                  );

                  # WARN: Since extraConfig is not applied when guardType is custom we must
                  # assert that module options generating this config are not used.
                  custom =
                    let
                      assertIncompat =
                        configSet: option:
                        assertMsg (
                          configSet.moduleOpts.guardType == "custom" -> !hasAttr option configSet.setModuleOpts
                        ) "${throwMsg} uses `${option}` which is not compatible with `guardType` 'custom'";
                    in
                    mkMerge (
                      map (
                        configSet:
                        assert assertIncompat configSet "asserts";
                        assert assertIncompat configSet "categoryConfig";
                        assert assertIncompat configSet "ns";
                        configSet.processedConfig
                      ) processedConfigSets
                    );
                };
              in
              guardTypeImpls.${primaryModuleOpts.guardType};
          }
        );
    in
    if isRoot then { inherit module categoryOpts; } else module;
}
