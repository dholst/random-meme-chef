def action_run
  token = node[:hipchat][:token]
  room = node[:hipchat][:room]

  if(token && room)
    notify = new_resource.notify ? '-d "notify=1"' : ''
    execute %{curl #{notify} -d "room_id=#{room}" -d "from=The Chef" -d "message=#{new_resource.message}" -d "color=#{new_resource.color}" "http://api.hipchat.com/v1/rooms/message?format=json&auth_token=#{token}"} do
      ignore_failure true
    end
  end
end