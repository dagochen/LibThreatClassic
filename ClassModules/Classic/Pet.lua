local ThreatLib = LibStub and LibStub("ThreatClassic-1.0", true)
if not ThreatLib then return end

local _G = _G
local pairs = _G.pairs
local tonumber = _G.tonumber

local GetPetActionInfo = _G.GetPetActionInfo
local GetSpellInfo = _G.GetSpellInfo
local UnitName = _G.UnitName

local Pet = ThreatLib:GetOrCreateModule("Pet")

-- Most of this data come from KTM's pet module
local spellIDRanks = {}
local spellLookups = {}

local skillData = not ThreatLib.Classic and {} or { -- for when testing in retail
	-- Scaling skills
	-- Growl
	[GetSpellInfo(2649)] = {
		spellIDs		= {2649, 14916, 14917, 14918, 14919, 14920, 14921},
		rankLevel		= {1, 10, 20, 30, 40, 50, 60},
		rankThreat		= {50, 65, 110, 170, 240, 320, 415},
		levelThreat		= {2, 3, 4, 4, 4, 5},
		
	},
	-- Torment
	[GetSpellInfo(3716)] = {
		spellIDs		= {3716, 7809, 7810, 7811, 11774, 11775},
		rankLevel		= {10, 20, 30, 40, 50, 60},
		rankThreat		= {45, 75, 125, 215, 300, 395},
		levelThreat		= {2, 2, 2, 2, 2, 2},
	},
	-- Suffering
	[GetSpellInfo(17735)] = {
		spellIDs		= {17735, 17750, 17751, 17752},
		rankLevel		= {24, 36, 48, 60},
		rankThreat		= {150, 300, 450, 600},
	},

	-- I think that Intimidation scales, but I don't have any scaling data on it
	-- Intimidation
	[GetSpellInfo(24394)] = {
		spellIDs 	= {24394},
		rankLevel 	= {1},
		rankThreat	= {580},
		levelThreat = {21},
	},

	-- Unscaling skills
	-- Scorpid Poison
	[GetSpellInfo(24640)] = {
		spellIDs	= {24640, 24583, 24586, 24587},
		rankLevel	= {8, 24, 40, 56},
		rankThreat	= {5, 5, 5, 5},
	},
	-- Cower
	[GetSpellInfo(1742)] = {
		spellIDs	= {1742, 1753, 1754, 1755, 1756, 16697},
		rankLevel	= {5, 15, 25, 35, 45, 55},
		rankThreat	= {-30, -55, -85, -125, -175, -225},
		levelThreat = {-1, -1, -2, -3, -3, -3},
	},
	-- Soothing Kiss
	[GetSpellInfo(6360)] = {
		spellIDs	= {6360, 7813, 11784, 11785},
		rankThreat	= {-45, -75, -127, -165}
		rankLevel	= {22, 34, 46, 58},
		levelThreat = {-1},
	},
}

local skillRanks = {}

function Pet:ClassEnable()
	self:RegisterEvent("LOCALPLAYER_PET_RENAMED")
	self:RegisterEvent("UNIT_NAME_UPDATE")

	-- CastHandlers
	self.unitName = UnitName("pet")
	self.unitType = "pet"
	local playerClass = select(2, UnitClass("player"))
	self.petScaling = (playerClass == "HUNTER") or (playerClass == "WARLOCK")

	local function castHandler(self, spellID, target) self:AddSkillThreat(spellID, target) end
	local function castMissHandler(self, spellID, target) self:RollbackSkillThreat(spellID, target) end
	for name, data in pairs(skillData) do
		for i = 1, #data.spellIDs do
			local v = data.spellIDs[i]
			spellIDRanks[v] = i
			spellLookups[v] = name
			self.CastLandedHandlers[v] = castHandler
			self.CastMissHandlers[v] = castMissHandler
		end
	end

	for k, v in pairs(skillRanks) do
		skillRanks[k] = nil
	end
	self.skillRanks = skillRanks

	self:ScanPetSkillRanks()
	self:RegisterEvent("PET_BAR_UPDATE", "ScanPetSkillRanks")
end

function Pet:ScanPetSkillRanks()
	for i = 1, 10 do
		local name, _, _, _, _ , _, rank = GetPetActionInfo(i)
		if skillData[name] then
			self.skillRanks[name] = rank
		end
	end
end

function Pet:GetSkillThreat(spellID, target)
	local rank = spellIDRanks[spellID]
	local skill = skillData[spellLookups[spellID]]
	local rankLevel = skill.rankLevel

	local threat = skill.rankThreat[rank]

	if self.petScaling and skill.levelThreat then
		-- This could be optimized pretty heavily
		local petLevel = UnitLevel("pet")
		if rankLevel then
			for i = 1, #rankLevel do
				if rankLevel[#rankLevel - i + 1] <= petLevel then
					rank = #rankLevel - i + 1
					break
				end
			end
			local baseThreat = skill.rankThreat[rank]
			local threatByLevel = skill.levelThreat[rank] * petLevel
			threat = baseThreat + threatByLevel
		end
	end

	return threat
end

function Pet:AddSkillThreat(spellID, target)
	local threat = self:GetSkillThreat(spellID, target)
	if not threat then return end

	self:AddTargetThreat(target, threat * self:threatMods())
end

function Pet:RollbackSkillThreat(spellID, target)
	local threat = self:GetSkillThreat(spellID, target)
	if not threat then return end

	self:AddTargetThreat(target, -(threat * self:threatMods()))
end

function Pet:LOCALPLAYER_PET_RENAMED()
	self.guid = nil
	self.unitName = UnitName("pet")
end

function Pet:UNIT_NAME_UPDATE(arg1)
	if arg1 == "pet" then
		self.guid = nil
		self.unitName = UnitName("pet")
		self:CheckDespawned()
	end
end
