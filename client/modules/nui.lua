function SendReactMessage(action, data)
	SendNUIMessage({
		action = action,
		data = data
	})
end

function ShowNUI(action, shouldShow)
    SetNuiFocus(shouldShow, shouldShow)
	SendNUIMessage({
		action = action,
		data = shouldShow
	})
end