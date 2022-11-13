local addonName, addon = ...;

local sort = _G.sort;
local strmatch = _G.strmatch;
local tinsert = _G.tinsert;
local executeAfter = _G.C_Timer.After;
local hooksecurefunc = _G.hooksecurefunc;
local IsAltKeyDown = _G.IsAltKeyDown;
local issecurevariable = _G.issecurevariable;

local Constants = addon.import('Logic/Constants');
local SlashCommands = addon.import('Core/SlashCommands');
local Utils = addon.import('Core/Utils');

local anchors = Constants.anchors;

local Minimap = _G.Minimap;

local LEFTBUTTON = 'LeftButton';
local MIDDLEBUTTON = 'MiddleButton';
local ONMOUSEUP = 'OnMouseUp';

local Layout = addon.importPending('Layouts/Main');
local Blacklist = addon.importPending('Logic/Blacklist');
local options;

local buttonContainer;
local mainButton;
local logo;
local collectedButtonMap = {};
local collectedButtons = {};

--##############################################################################
-- minimap button collecting
--##############################################################################

local function doNothing () end

local function updateLayoutIfVisibilityChanged (frame)
  local visibility = frame:IsShown();

  if (collectedButtonMap[frame] ~= visibility) then
    collectedButtonMap[frame] = visibility;
    Layout.updateLayout();
  end
end

local function collectMinimapButton (button)
  -- print('collecting button:', button:GetName());

  button:SetParent(buttonContainer);
  button:SetFrameStrata(Constants.FRAME_STRATA);
  button:SetScript('OnDragStart', nil);
  button:SetScript('OnDragStop', nil);
  button:SetIgnoreParentScale(false);

  -- Hook the function on the frame itself instead of setting a script handler
  -- to execute only when the function is called and not when the frame changes
  -- visibility because the parent gets shown/hidden
  hooksecurefunc(button, 'Show', updateLayoutIfVisibilityChanged);
  hooksecurefunc(button, 'Hide', updateLayoutIfVisibilityChanged);

  -- There's still a ton of addons being coded like hot garbage moving their
  -- buttons on every single frame so to prevent a billion comments stating that
  -- MBB is apparently incompatible, we try to block moving the frame
  button.ClearAllPoints = doNothing;
  button.SetPoint = doNothing;
  button.SetParent = doNothing;

  tinsert(collectedButtons, button);
  collectedButtonMap[button] = button:IsShown();
end

local function isButtonCollected (button)
  return (collectedButtonMap[button] ~= nil);
end

local function collectLibDBIconButtons ()
  local LibStub = _G.LibStub;
  local LibDBIconStub = LibStub and LibStub('LibDBIcon-1.0');

  if (not LibDBIconStub) then
    return;
  end

  for _, buttonName in ipairs(LibDBIconStub:GetButtonList()) do
    local button = LibDBIconStub:GetMinimapButton(buttonName);

    if (not isButtonCollected(button) and
        not Blacklist.isButtonBlacklisted(button)) then
      collectMinimapButton(button);
    end
  end
end

local function isValidFrame (frame)
  if (type(frame) ~= 'table') then
    return false;
  end

  if (not frame.IsObjectType or not frame:IsObjectType('Frame')) then
    return false;
  end

  return true;
end

local function scanButtonByName (buttonName)
  local button = _G[buttonName];

  if (isValidFrame(button) and not isButtonCollected(button)) then
    collectMinimapButton(button);
  end
end

local function collectWhitelistedButtons ()
  for buttonName in pairs(options.whitelist) do
    scanButtonByName(buttonName);
  end
end

local function nameEndsWithNumber (frameName)
  return (strmatch(frameName, '%d$') ~= nil);
end

local function nameMatchesButtonPattern (frameName)
  local patterns = {
    '^LibDBIcon10_', -- keep this in, some buttons are manually named to be detected
    'MinimapButton',
    'MinimapFrame',
    'MinimapIcon',
    '[-_]Minimap[-_]',
    'Minimap$',
  };

  for _, pattern in ipairs(patterns) do
    if (strmatch(frameName, pattern) ~= nil) then
      return true;
    end
  end

  return false;
end

local function isMinimapButton (frame)
  local frameName = Utils.getFrameName(frame);

  if (not frameName) then
    return false;
  end;

  if (issecurevariable(frameName)) then
    return false;
  end

  if (nameEndsWithNumber(frameName)) then
    return false;
  end

  return (nameMatchesButtonPattern(frameName));
end

local function shouldButtonBeCollected (button)
  if (isButtonCollected(button) or
      not isValidFrame(button) or
      Blacklist.isButtonBlacklisted(button)) then
    return false;
  end

  return isMinimapButton(button);
end

local function scanMinimapChildren ()
  for _, child in ipairs({Minimap:GetChildren()}) do
    if (shouldButtonBeCollected(child)) then
      collectMinimapButton(child);
    end
  end
end

local function sortCollectedButtons ()
  sort(collectedButtons, function (a, b)
    return a:GetName() < b:GetName();
  end);
end

local function collectMinimapButtons ()
  local previousCount = #collectedButtons;

  collectLibDBIconButtons();
  collectWhitelistedButtons();
  scanMinimapChildren();

  if (#collectedButtons > previousCount) then
    sortCollectedButtons();
  end
end

local function collectMinimapButtonsAndUpdateLayout ()
  collectMinimapButtons();
  Layout.updateLayout();
end

--##############################################################################
-- main button setup
--##############################################################################

local function toggleButtons ()
  collectMinimapButtonsAndUpdateLayout();

  if (buttonContainer:IsShown()) then
    options.buttonsShown = false;
    buttonContainer:Hide();
  else
    options.buttonsShown = true;
    buttonContainer:Show();
  end
end

local function setDefaultPosition ()
  mainButton:ClearAllPoints();
  mainButton:SetPoint(anchors.CENTER, _G.UIParent, anchors.CENTER, 0, 0);
end

local function storeMainButtonPosition ()
  options.position = {mainButton:GetPoint()};
end

local function stopMovingMainButton ()
  mainButton:SetScript(ONMOUSEUP, nil);
  mainButton:SetMovable(false);
  mainButton:StopMovingOrSizing();
  storeMainButtonPosition();
end

local function moveMainButton ()
  mainButton:SetScript(ONMOUSEUP, stopMovingMainButton);
  mainButton:SetMovable(true);
  mainButton:StartMoving();
end

local function initMainButton ()
  mainButton = _G.CreateFrame('Frame', addonName .. 'Button', _G.UIParent,
      _G.BackdropTemplateMixin and 'BackdropTemplate');
  mainButton:SetParent(_G.UIParent);
  mainButton:SetFrameStrata(Constants.FRAME_STRATA);
  mainButton:SetFrameLevel(Constants.FRAME_LEVEL);
  setDefaultPosition();
  mainButton:SetClampedToScreen(true);
  mainButton:Show();

  mainButton:SetScript('OnMouseDown', function (_, button)
    if (button == MIDDLEBUTTON or IsAltKeyDown()) then
      moveMainButton();
    elseif (button == LEFTBUTTON) then
      toggleButtons();
    end
  end);
end

local function initButtonContainer ()
  buttonContainer = _G.CreateFrame('Frame', nil, _G.UIParent,
    _G.BackdropTemplateMixin and 'BackdropTemplate');
  buttonContainer:SetParent(mainButton);
  buttonContainer:SetFrameLevel(Constants.FRAME_LEVEL);
  buttonContainer:Hide();
end

local function initLogo ()
  logo = mainButton:CreateTexture(nil, 'ARTWORK');
  logo:SetTexture('Interface\\AddOns\\' .. addonName ..
      '\\Media\\Logo.blp');

  logo:SetPoint(anchors.CENTER, mainButton, anchors.CENTER, 0, 0);
  logo:SetSize(Constants.LOGO_SIZE, Constants.LOGO_SIZE);
end

local function initFrames ()
  initMainButton();
  initButtonContainer();
  initLogo();
end

initFrames();

--##############################################################################
-- initialization
--##############################################################################

local function applyScale ()
  mainButton:SetScale(options.scale);
end

local function restoreOptions ()
  if (options.position == nil) then
    addon.import('Core/Tooltip').createTooltip(mainButton, {
      'You can drag the button using the middle mouse button',
      'or any mouse button while holding ALT.'
    });
  else
    mainButton:ClearAllPoints();
    mainButton:SetPoint(unpack(options.position));
  end

  applyScale();

  if (options.buttonsShown == true) then
    buttonContainer:Show();
  end
end

local function init ()
  options = addon.import('Logic/Options').getAll()
  restoreOptions();
  collectMinimapButtonsAndUpdateLayout();
end

addon.import('Core/Events').registerEvent('PLAYER_LOGIN', function ()
  --[[ executing on next frame to wait for addons that create minimap buttons
       on PLAYER_LOGIN ]]
  executeAfter(0, init);
  -- rescanning buttons after a second for special candidates like Questie
  executeAfter(1, collectMinimapButtonsAndUpdateLayout);
  return true;
end);


--##############################################################################
-- slash commands
--##############################################################################

SlashCommands.addHandlerName('mbb');

local function printButtonLists ()
  if (#collectedButtons > 0) then
    Utils.printAddonMessage('Buttons currently being collected:');

    for _, button in ipairs(collectedButtons) do
      print(button:GetName());
    end
  end

  if (next(options.whitelist) ~= nil) then
    Utils.printAddonMessage('Buttons currently being manually collected:');

    for buttonName in pairs(options.whitelist) do
      print(buttonName);
    end
  end

  if (next(options.blacklist) ~= nil) then
    Utils.printAddonMessage('Buttons currently being ignored:');

    for buttonName in pairs(options.blacklist) do
      print(buttonName);
    end
  end
end

SlashCommands.addCommand('list', printButtonLists);
SlashCommands.addCommand('default', printButtonLists);
SlashCommands.addCommand('reset', setDefaultPosition);

--##############################################################################
-- shared data
--##############################################################################

addon.export('Logic/Main', {
  buttonContainer = buttonContainer,
  mainButton = mainButton,
  logo = logo,
  collectedButtons = collectedButtons,
  applyScale = applyScale,
  collectMinimapButtonsAndUpdateLayout = collectMinimapButtonsAndUpdateLayout,
  isValidFrame = isValidFrame,
});
