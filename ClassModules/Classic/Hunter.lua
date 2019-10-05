local ThreatLib = LibStub and LibStub("ThreatClassic-1.0", true)
if not ThreatLib then return end

local pairs = _G.pairs
local GetTime = _G.GetTime
local ERR_FEIGN_DEATH_RESISTED = _G.ERR_FEIGN_DEATH_RESISTED

if select(2, _G.UnitClass("player")) ~= "HUNTER" then return end

local _G = _G
local Hunter = ThreatLib:GetOrCreateModule("Player")

local threatTable = {
	["DistractingShot"] = {
		[20736] = 110,
		[14274] = 160,
		[15629] = 250,
		[15630] = 350,
		[15631] = 465,
		[15632] = 600,
	},
	["Disengage"] = {
		[781] = -140,
		[14272] = -280,
		[14273] = -405,
	}
}

local threatPerLevelTable = {
	["DistractingShot"] = {
		[20736] = 1.5,
		[14274] = 2.0,
		[15629] = 2.5,
		[15630] = 3.0,
		[15631] = 3.5,
		[15632] = 4.0,
	},
	["Disengage"] = {
		[781] = -3.0,
		[14272] = -3.0,
		[14273] = -3.0,
	}
}


function Hunter:ClassInit()
	for k, v in pairs(threatTable["DistractingShot"]) do
		self.CastLandedHandlers[k] = self.DistractingShot
	end
	for k, v in pairs(threatTable["Disengage"]) do
		self.CastLandedHandlers[k] = self.Disengage
	end

	self.CastHandlers[5384] = self.FeignDeath
end

function Hunter:ClassEnable()
	-- Needed for FD. Ugly as hell, but it works.
	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	self:RegisterEvent("UI_ERROR_MESSAGE")
	-- ERR_FEIGN_DEATH_RESISTED
end

function Hunter:DistractingShot(spellID, target)
	local amt = threatTable["DistractingShot"][spellID] + (UnitLevel("Player") * threatPerLevelTable["DistractingShot"][spellID])
	self:AddTargetThreat(target, amt * self:threatMods())
end

function Hunter:Disengage(spellID, target)
	ThreatLib:Debug("Disengage caught, %s", spellID)
	local amt = threatTable["Disengage"][spellID] + (UnitLevel("Player") * threatPerLevelTable["Disengage"][spellID])
	self:AddTargetThreat(target, amt * self:threatMods())
end

-- Feign is a rather unique case. It's cast on all targets, but may be resisted by any one target. There is no combat log message - only an error event with ERR_FEIGN_DEATH_RESISTED from GlobalStrings
-- ERR_FEIGN_DEATH_RESISTED always happens before SPELLCAST_SUCCESSFUL, so we "prime" FD when we get SENT, then invalidate it if we get a resist, let it through otherwise.
-- The net effect is that a resist on any one target invalidates the threat reset on all targets, but we can't help that since we don't have target data on who resisted
local FeignDeathPrimed = 0
function Hunter:FeignDeath()
	if GetTime() - FeignDeathPrimed < 5 then
		FeignDeathPrimed = 0
		self:MultiplyThreat(0)
		ThreatLib:Debug("Running FD, clearing threat!")
	end
end

function Hunter:UNIT_SPELLCAST_SENT(event, unit, target, castGUID, spellID)
	ThreatLib:Debug("Hunter:UNIT_SPELLCAST_SENT: %s, %s, %s, %d", unit, target, castGUID, spellID)
	if unit == "player" and spellID == 5384 then
		ThreatLib:Debug("FD is primed!")
		FeignDeathPrimed = GetTime()
	end
end

function Hunter:UI_ERROR_MESSAGE(event, msg)
	if msg == ERR_FEIGN_DEATH_RESISTED then
		ThreatLib:Debug("Canceling FD!")
		FeignDeathPrimed = 0
	end
end
