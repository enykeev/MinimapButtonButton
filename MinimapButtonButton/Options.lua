local addonName, addon = ...;

addon.registerEvent('ADDON_LOADED', function (loadedAddon)
  if (loadedAddon ~= addonName) then
    return;
  end

  local options;

  if (type(_G.MinimapButtonButtonOptions) == 'table') then
    options = _G.MinimapButtonButtonOptions;
  else
    options = {};
  end

  if (type(options.blacklistedButtonNames) ~= 'table') then
    options.blacklistedButtonNames = {};
  end

  if (type(options.whitelist) ~= 'table') then
    -- addding some known special buttons as default
    options.whitelist = {
      ZygorGuidesViewerMapIcon = true,
      TrinketMenu_IconFrame = true,
      CodexBrowserIcon = true,
    };
  end

  addon.registerEvent('PLAYER_LOGOUT', function ()
    _G.MinimapButtonButtonOptions = options;
  end);

  addon.options = options;

  return true;
end);
