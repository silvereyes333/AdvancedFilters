-- authors: votan, sirinsidiator
-- thanks to: baertram & circonian

-- Register with LibStub
local MAJOR, MINOR = "LibCustomMenu", 4.1
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end -- the same or newer version of this lib is already loaded into memory

local wm = WINDOW_MANAGER

----- Common -----
local function SetupDivider(pool, control)
	local function GetTextDimensions(self)
		return 32, 7
	end
	local function Noop(self)
	end

	local label = wm:CreateControlFromVirtual("$(parent)Name", control, "ZO_BaseTooltipDivider")
	label:ClearAnchors()
	label:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 2)
	label:SetAnchor(TOPRIGHT, nil, TOPRIGHT, 0, 2)
	label.SetText = Noop
	label.SetFont = Noop
	label.GetTextDimensions = GetTextDimensions
	label:SetHidden(false)

	control:SetMouseEnabled(false)
end

lib.DIVIDER = "-"

----- Sub Menu -----

local Submenu = ZO_Object:Subclass()

local SUBMENU_ITEM_MOUSE_ENTER = 1
local SUBMENU_ITEM_MOUSE_EXIT = 2
local SUBMENU_SHOW_TIMEOUT = 350
local SUBMENU_HIDE_TIMEOUT = 350

local submenuCallLaterHandle
local nextId = 1
local function ClearTimeout()
	if (submenuCallLaterHandle ~= nil) then
		EVENT_MANAGER:UnregisterForUpdate(submenuCallLaterHandle)
		submenuCallLaterHandle = nil
	end
end

local function SetTimeout(callback)
	if (submenuCallLaterHandle ~= nil) then ClearTimeout() end
	submenuCallLaterHandle = "LibCustomMenuSubMenuTimeout" .. nextId
	nextId = nextId + 1

	EVENT_MANAGER:RegisterForUpdate(submenuCallLaterHandle, SUBMENU_SHOW_TIMEOUT, function()
		ClearTimeout()
		if callback then callback() end
	end )
end

local function GetValueOrCallback(arg, ...)
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end

function Submenu:New(...)
	local object = ZO_Object.New(self)
	object:Initialize(...)
	return object
end

function Submenu:Initialize(name)
	self.window = ZO_Menus

	local submenuControl = self.window:CreateControl(name, CT_CONTROL)
	submenuControl:SetClampedToScreen(true)
	submenuControl:SetMouseEnabled(true)
	submenuControl:SetHidden(true)
	-- OnMouseEnter: Stop hiding of submenu initiated by mouse exit of parent
	submenuControl:SetHandler("OnMouseEnter", function(control) ClearTimeout() end)
	submenuControl:SetHandler("OnMouseExit", function(control)
		SetTimeout( function() self.parent:OnSelect(SUBMENU_ITEM_MOUSE_EXIT) end)
	end )

	submenuControl:SetHandler("OnHide", function(control) ClearTimeout() self:Clear() end)
	submenuControl:SetDrawLevel(ZO_Menu:GetDrawLevel() + 1)

	local bg = submenuControl:CreateControl("$(parent)BG", CT_BACKDROP)
	-- bg:SetCenterColor(0, 0, 0, .93)
	bg:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
	bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
	bg:SetInsets(16, 16, -16, -16)
	bg:SetAnchorFill()

	local overlay = bg:CreateControl("$(parent)MungeOverlay", CT_TEXTURE)
	overlay:SetTexture("EsoUI/Art/Tooltips/munge_overlay.dds")
	overlay:SetAddressMode(TEX_MODE_WRAP)
	overlay:SetAnchor(TOPLEFT)
	overlay:SetAnchor(BOTTOMRIGHT)

	self.highlight = CreateControlFromVirtual("$(parent)Highlight", submenuControl, "ZO_SelectionHighlight")
	self.highlight:SetHidden(true)

	self.control = submenuControl

	local upInside = false
	local function ItemFactory(pool)
		local control = CreateControlFromVirtual("ZO_SubMenuItem", submenuControl, "ZO_MenuItem", pool:GetNextControlId())
		local function MouseEnter(control)
			upInside = true
			ClearTimeout()
			self:SetSelectedIndex(control.index)
		end
		local function MouseExit(control)
			upInside = false
			if (self.selectedIndex == control.index) then
				self:SetSelectedIndex(nil)
			end
		end
		local function MouseUp(control)
			if upInside == true then
				ZO_Menu_ClickItem(control, 1)
				self:Clear()
			end
		end

		control:SetHandler("OnMouseEnter", MouseEnter)
		control:SetHandler("OnMouseExit", MouseExit)
		control:SetHandler("OnMouseDown", IgnoreMouseDownEditFocusLoss)
		control:SetHandler("OnMouseUp", MouseUp)

		return control
	end

	local function ResetFunction(control)
		control:SetHidden(true)
		control:ClearAnchors()
		control.OnSelect = nil
		control.menuIndex = nil
	end

	local function DividerFactory(pool)
		local control = CreateControlFromVirtual("ZO_CustomSubMenuDivider", submenuControl, "ZO_NotificationsRowButton", pool:GetNextControlId())
		SetupDivider(pool, control)
		return control
	end

	self.itemPool = ZO_ObjectPool:New(ItemFactory, ResetFunction)
	self.dividerPool = ZO_ObjectPool:New(DividerFactory, ResetFunction)
	self.items = { }

	EVENT_MANAGER:RegisterForEvent(name .. "_OnGlobalMouseUp", EVENT_GLOBAL_MOUSE_UP, function()
		if self.refCount ~= nil then
			local moc = wm:GetMouseOverControl()
			if (moc:GetOwningWindow() ~= submenuControl) then
				self.refCount = self.refCount - 1
				if self.refCount <= 0 then
					self:Clear()
				end
			end
		end
	end )
end

function Submenu:SetSelectedIndex(index)
	if (index) then
		index = zo_max(zo_min(index, #self.items), 1)
	end

	if (self.selectedIndex ~= index) then
		self:UnselectItem(self.selectedIndex)
		self:SelectItem(index)
	end
end

function Submenu:UnselectItem(index)
	local item = self.items[index]
	if item then
		self.highlight:SetHidden(true)
		local nameControl = GetControl(item, "Name")
		nameControl:SetColor(nameControl.normalColor:UnpackRGBA())

		self.selectedIndex = nil
	end
end

function Submenu:SelectItem(index)
	local item = self.items[index]
	if item then
		local highlight = self.highlight

		highlight:ClearAnchors()

		highlight:SetAnchor(TOPLEFT, item, TOPLEFT, -2, -2)
		highlight:SetAnchor(BOTTOMRIGHT, item, BOTTOMRIGHT, 2, 2)

		highlight:SetHidden(false)

		local nameControl = GetControl(item, "Name")
		nameControl:SetColor(nameControl.highlightColor:UnpackRGBA())

		self.selectedIndex = index
	end
end

function Submenu:UpdateAnchors()
	local iconSize = self.iconSize
	local previousItem = self.control
	local items = self.items
	local width, height = 0, 0
	local padding = ZO_Menu.menuPad

	for i = 1, #items do
		local item = items[i]
		local textWidth, textHeight = GetControl(item, "Name"):GetTextDimensions()
		width = math.max(textWidth + padding * 2, width)
		height = height + textHeight
		item:ClearAnchors()
		if i == 1 then
			item:SetAnchor(TOPLEFT, previousItem, TOPLEFT, padding, padding)
			item:SetAnchor(TOPRIGHT, previousItem, TOPRIGHT, - padding, padding)
		else
			item:SetAnchor(TOPLEFT, previousItem, BOTTOMLEFT, 0, item.itemYPad)
			item:SetAnchor(TOPRIGHT, previousItem, BOTTOMRIGHT, 0, item.itemYPad)
		end

		item:SetHidden(false)
		item:SetDimensions(textWidth, textHeight)
		previousItem = item
	end

	self.control:SetDimensions(width + padding * 2, height + padding * 2)
end

function Submenu:Clear()
	self:UnselectItem(self.selectedIndex)
	self.items = { }
	self.itemPool:ReleaseAllObjects()
	self.dividerPool:ReleaseAllObjects()
	self.control:SetHidden(true)
	self.refCount = nil
end

local DEFAULT_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
local DEFAULT_TEXT_HIGHLIGHT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CONTEXT_HIGHLIGHT))

function Submenu:AddItem(entry, myfont, normalColor, highlightColor, itemYPad)
	local visible
	if entry.visible ~= nil then visible = entry.visible else visible = true end
	if not GetValueOrCallback(visible, ZO_Menu) then return end

	local item, key = entry.label ~= lib.DIVIDER and self.itemPool:AcquireObject() or self.dividerPool:AcquireObject()
	item.OnSelect = entry.callback
	item.index = #self.items + 1
	self.items[item.index] = item

	local nameControl = GetControl(item, "Name")

	local entryFont = GetValueOrCallback(entry.myfont, ZO_Menu, item) or myfont
	local normColor = GetValueOrCallback(entry.normalColor, ZO_Menu, item) or normalColor
	local highColor = GetValueOrCallback(entry.highlightColor, ZO_Menu, item) or highlightColor
	myfont = entryFont or "ZoFontGame"
	nameControl.normalColor = normColor or DEFAULT_TEXT_COLOR
	nameControl.highlightColor = highColor or DEFAULT_TEXT_HIGHLIGHT

	nameControl:SetFont(myfont)
	nameControl:SetText(GetValueOrCallback(entry.label, ZO_Menu, item))
	local enabled = not GetValueOrCallback(entry.disabled or false, ZO_Menu, item)
	nameControl:SetColor((enabled and nameControl.normalColor or ZO_DEFAULT_DISABLED_COLOR):UnpackRGBA())
	item:SetMouseEnabled(enabled)
end

function Submenu:Show(parent)
	if not self.control:IsHidden() then self:Clear() return false end
	self:UpdateAnchors()

	local padding = ZO_Menu.menuPad
	local control = self.control
	control:ClearAnchors()
	-- If there is not enough space on the right side, use the left side. Like Windows.
	if (parent:GetRight() + control:GetWidth()) < GuiRoot:GetRight() then
		control:SetAnchor(TOPLEFT, parent, TOPRIGHT, -1, - padding)
	else
		control:SetAnchor(TOPRIGHT, parent, TOPLEFT, 1, - padding)
	end
	control:SetHidden(false)
	self.parent = parent
	self.refCount = 2

	return true
end

local function SubMenuItemFactory(pool)
	local control = CreateControlFromVirtual("ZO_CustomSubMenuItem", ZO_Menu, "ZO_NotificationsRowButton", pool:GetNextControlId())

	local arrowContainer = control:CreateControl("$(parent)Arrow", CT_CONTROL)
	-- we need this in order to control the menu with independently of the texture size
	arrowContainer:SetAnchor(RIGHT, control, RIGHT, 0, 0)
	arrowContainer:SetDimensions(32, 16)

	local arrow = arrowContainer:CreateControl("$(parent)Texture", CT_TEXTURE)
	arrow:SetAnchor(RIGHT, arrowContainer, RIGHT, 0, 0)
	arrow:SetDimensions(16, 20)
	arrow:SetTexture("EsoUI/Art/Miscellaneous/colorPicker_slider_vertical.dds")
	arrow:SetTextureCoords(0, 0.5, 0, 1)

	-- we assign the submenu arrow to checkbox because the context menu will add the desired width automatically that way
	control.checkbox = arrowContainer

	local clicked = false
	local function MouseEnter(control)
		ZO_Menu_EnterItem(control)
		clicked = false
		SetTimeout( function() if control.OnSelect then control:OnSelect(SUBMENU_ITEM_MOUSE_ENTER) end end)
	end
	local function MouseExit(control)
		ZO_Menu_ExitItem(control)
		if not clicked then
			SetTimeout( function() if control.OnSelect then control:OnSelect(SUBMENU_ITEM_MOUSE_EXIT) end end)
		end
	end
	local function MouseDown(control)
		IgnoreMouseDownEditFocusLoss()
		-- re-open sub menu on click
		clicked = true
		control:OnSelect(SUBMENU_ITEM_MOUSE_ENTER)
	end

	local label = wm:CreateControl("$(parent)Name", control, CT_LABEL)
	label:SetAnchor(TOPLEFT)

	control:SetHandler("OnMouseEnter", MouseEnter)
	control:SetHandler("OnMouseExit", MouseExit)
	control:SetHandler("OnMouseDown", MouseDown)

	return control
end

----- Standard Menu -----

local function ResetMenuItem(button)
	button:SetHidden(true)
	button:ClearAnchors()
	button.menuIndex = nil
	button.OnSelect = nil
end

local function ResetCheckBox(checkBox)
	ResetMenuItem(checkBox)
	ZO_CheckButton_SetToggleFunction(checkBox, nil)
end

local upInside = false

local function MenuItemFactory(pool)
	local control = CreateControlFromVirtual("ZO_CustomMenuItem", ZO_Menu, "ZO_NotificationsRowButton", pool:GetNextControlId())
	local function MouseEnter()
		upInside = true
		ZO_Menu_EnterItem(control)
	end
	local function MouseExit()
		upInside = false
		ZO_Menu_ExitItem(control)
	end
	local function MouseUp()
		if upInside == true then
			ZO_Menu_ClickItem(control, 1)
		end
	end

	local label = wm:CreateControl("$(parent)Name", control, CT_LABEL)
	label:SetAnchor(TOPLEFT)

	control:SetHandler("OnMouseEnter", MouseEnter)
	control:SetHandler("OnMouseExit", MouseExit)
	control:SetHandler("OnMouseDown", IgnoreMouseDownEditFocusLoss)
	control:SetHandler("OnMouseUp", MouseUp)

	return control
end

local function CheckBoxFactory(pool)
	local control = CreateControlFromVirtual("ZO_CustomMenuItemCheckButton", ZO_Menu, "ZO_CheckButton", pool:GetNextControlId())
	local function MouseEnter()
		ZO_Menu_EnterItem(control)
	end
	local function MouseExit()
		ZO_Menu_ExitItem(control)
	end
	control:SetHandler("OnMouseEnter", MouseEnter)
	control:SetHandler("OnMouseExit", MouseExit)
	return control
end

local function DividerFactory(pool)
	local control = CreateControlFromVirtual("ZO_CustomMenuDivider", ZO_Menu, "ZO_NotificationsRowButton", pool:GetNextControlId())
	SetupDivider(pool, control)
	return control
end

----- Public API -----

function AddCustomMenuItem(mytext, myfunction, itemType, myfont, normalColor, highlightColor, itemYPad)
	local orgItemPool = ZO_Menu.itemPool
	local orgCheckboxItemPool = ZO_Menu.checkBoxPool

	ZO_Menu.itemPool = mytext ~= lib.DIVIDER and lib.itemPool or lib.dividerPool
	ZO_Menu.checkBoxPool = lib.checkBoxPool

	local index = AddMenuItem(mytext, myfunction, itemType, myfont, normalColor, highlightColor, itemYPad)

	ZO_Menu.itemPool = orgItemPool
	ZO_Menu.checkBoxPool = orgCheckboxItemPool

	return index
end

function AddCustomSubMenuItem(mytext, entries, myfont, normalColor, highlightColor, itemYPad)
	local function CreateSubMenu(control, state)
		if (state == SUBMENU_ITEM_MOUSE_ENTER) then
			lib.submenu:Clear()
			local currentEntries = GetValueOrCallback(entries, ZO_Menu, control)
			local entry
			for i = 1, #currentEntries do
				entry = currentEntries[i]
				lib.submenu:AddItem(entry, myfont, normalColor, highlightColor, itemYPad)
			end
			lib.submenu:Show(control)
		elseif (state == SUBMENU_ITEM_MOUSE_EXIT) then
			lib.submenu:Clear()
		end
	end

	local orgItemPool = ZO_Menu.itemPool
	local orgCheckboxItemPool = ZO_Menu.checkBoxPool

	ZO_Menu.itemPool = lib.submenuPool
	ZO_Menu.checkBoxPool = lib.checkBoxPool

	local index = AddMenuItem(mytext, CreateSubMenu, MENU_ADD_OPTION_LABEL, myfont, normalColor, highlightColor, itemYPad)

	ZO_Menu.itemPool = orgItemPool
	ZO_Menu.checkBoxPool = orgCheckboxItemPool

	return index
end

local function HookClearMenu()
	local orgClearMenu = ClearMenu
	function ClearMenu()
		ClearTimeout()
		orgClearMenu()
		lib.itemPool:ReleaseAllObjects()
		lib.submenuPool:ReleaseAllObjects()
		lib.checkBoxPool:ReleaseAllObjects()
		lib.dividerPool:ReleaseAllObjects()
		lib.submenu:Clear()
	end
end

local function HookAddSlotAction()
	function ZO_InventorySlotActions:AddCustomSlotAction(...)
		local orgItemPool = ZO_Menu.itemPool
		local orgCheckboxItemPool = ZO_Menu.checkBoxPool

		ZO_Menu.itemPool = lib.itemPool
		ZO_Menu.checkBoxPool = lib.checkBoxPool

		self:AddSlotAction(...)

		ZO_Menu.itemPool = orgItemPool
		ZO_Menu.checkBoxPool = orgCheckboxItemPool
	end
end
--[[
-- uncomment this, if you want to see where and when "insecure" controls get re-used.
function AddCustomMenuItem(mytext, myfunction, itemType, myfont, normalColor, highlightColor, itemYPad)
	local lastCount = ZO_Menu.itemPool and ZO_Menu.itemPool:GetTotalObjectCount() or 0
	local index = AddMenuItem(mytext, myfunction, itemType, myfont, normalColor, highlightColor, itemYPad)

	local control = ZO_Menu.items[index].item
	if ZO_Menu.itemPool:GetTotalObjectCount() > lastCount and control:GetNamedChild("Bad") == nil then
		local bad = wm:CreateControl("$(parent)Bad", control, CT_TEXTURE)
		bad:SetTexture("esoui/art/icons/poi/poi_groupboss_complete.dds")
		bad:SetDimensions(23, 23)
		bad:SetAnchor(RIGHT, control, RIGHT)
	end

	return index
end
]]--

---- Init -----

local function OnAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EVENT_MANAGER:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
	lib.itemPool = ZO_ObjectPool:New(MenuItemFactory, ResetMenuItem)
	lib.submenuPool = ZO_ObjectPool:New(SubMenuItemFactory, ResetMenuItem)
	lib.checkBoxPool = ZO_ObjectPool:New(CheckBoxFactory, ResetCheckBox)
	lib.dividerPool = ZO_ObjectPool:New(DividerFactory, ResetMenuItem)
	lib.submenu = Submenu:New("LibCustomMenuSubmenu")
	HookClearMenu()
	HookAddSlotAction()
end

EVENT_MANAGER:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
EVENT_MANAGER:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, OnAddonLoaded)
