AddCSLuaFile()

if SERVER then
	include("gitrc.lua")

	ACFM_VersionStatus = nil

	net.Receive("acfm_versioncheck", function( len, ply )
		net.Start("acfm_versionresponse")
		net.WriteTable(ACFM_VersionStatus or {})
		net.Send(ply)
	end)

	function ACF_Missiles_VersionCheck()
		-- make sure version checker only runs for people who've installed the mod.
		if file.Exists("ACFMissiles_VCheck.txt", "GAME") then
			GitRC.CheckVersion("Bubbus", "ACF-Missiles", function(data)
				ACFM_VersionStatus = 
				{
					IsLatest = data.uptodate,
					LatestDate = data.committime
				}
			end)
		end
	end

	hook.Add("Initialize", "acfm_versioncheck", function(move)
		util.AddNetworkString("acfm_versioncheck")
		util.AddNetworkString("acfm_versionresponse")
		
		timer.Simple(1, ACF_Missiles_VersionCheck)
	end)
else
	net.Receive("acfm_versionresponse", function( len, ply )
		local response = net.ReadTable()
		
		local inDate = response.IsLatest
		local lastUpdate = response.LatestDate
		
		if inDate == nil then return end
			
		if not inDate then
			if lastUpdate then
				chat.AddText(Color(255,0,0), "A newer version of ACF Missiles is available! (last updated ", Color(255, 128, 0), os.date("%x", lastUpdate) , Color(255, 0, 0), ")")
			else
				chat.AddText(Color(255,0,0), "A newer version of ACF Missiles is available!")
			end
			
			chat.AddText(Color(255,0,0), "Update this server to the latest version at ", Color(255, 128, 0), "https:--github.com/Bubbus/ACF-Missiles")
		else
			chat.AddText(Color(0,255,64), "ACF Missiles ", Color(0, 192, 42), "is up to date on this server!")
		end
	end)
	
	function ACF_Missiles_VersionCheck()
		net.Start("acfm_versioncheck")
		net.SendToServer()
	end
	
	hook.Add("CreateMove", "acfm_versioncheck", function(move)
		if move:GetButtons() == 0 then return end
		
		hook.Remove("CreateMove", "acfm_versioncheck")
		
		timer.Simple(1, ACF_Missiles_VersionCheck)
	end)
end
