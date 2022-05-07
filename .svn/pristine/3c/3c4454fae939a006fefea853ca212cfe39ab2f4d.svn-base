# -*- encoding : utf-8 -*-
class Audio
  def Audio.rm_sound_file(src)
    rm_cmd = "rm -fr \'#{src}\'"
    MorLog.my_debug(rm_cmd)
    system(rm_cmd)

    # delete file from remote Asterisk servers
    servers = Server.where.not(server_ip: '127.0.0.1').where(active: 1).all
    servers.each do |server|
      MorLog.my_debug("deleting audio file #{rm_cmd} from server #{servers_ip}")
      rm_cmd = "/usr/bin/ssh root@#{servers_ip} -p #{server_ssh_port} -f #{rm_cmd} "
      MorLog.my_debug(rm_cmd)
      system(rm_cmd)
    end
  end
end
