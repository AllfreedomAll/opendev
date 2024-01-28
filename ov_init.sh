sudo yum install -y -q net-tools epel-release git
sudo yum update -y -q nss curl libcurl
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker


docker_check(){
  echo "开始检查docker>>>>>>"
  # 检查 Docker 是否已安装
  if command -v docker &> /dev/null
  then
      echo "Docker 已安装"
  else
      echo "Docker 未安装，尝试安装..."
      yum -q -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
      yum install -q -y yum-utils device-mapper-persistent-data lvm2
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      yum -q -y install docker-ce docker-ce-cli containerd.io
      yum update -q xfsprogs -y
      mkdir -p /etc/docker/ /root/.docker
      systemctl enable docker
      systemctl start docker
      # 再次检查 Docker 是否安装成功
      if command -v docker &> /dev/null
      then
          echo "Docker 安装成功"
      else
          echo "无法安装 Docker，请检查网络和权限"
          exit 1
      fi
  fi
  # 检查 Docker 服务是否已启动
  if systemctl is-active --quiet docker
  then
      echo "Docker 服务已启动"
  else
      echo "Docker 服务未启动，尝试启动..."
      sudo systemctl start docker

      # 再次检查 Docker 服务是否已成功启动
      if systemctl is-active --quiet docker
      then
          echo "Docker 服务已成功启动"
      else
          echo "无法启动 Docker 服务，请检查安装和配置"
          exit 1
      fi
  fi
  echo "Docker 正常运行"
}

#  设置swap,大小1M,避免崩溃
set_swap() {
  echo "开始检查swap分区>>>>>>"
  if [[ $(ls / | grep swapfile | wc -l) -ge 1 ]]; then
    echo "swap分区已经设置"
  else
    dd if=/dev/zero of=/swapfile2 bs=1024 count=1M
    sleep 1
    chmod 600 /swapfile2
    mkswap /swapfile2
    swapon /swapfile2
    echo "/swapfile2 swap swap defaults 0 0" >>/etc/fstab
    [[ $(grep swapfile /proc/swaps | wc -l) -ge 1 ]] && echo "Swap设置成功" || echo "<b style=color:red>Swap设置失败</b>"
  fi
}

block_firewall() {
  echo "开始检测防火墙>>>>>>"
  if [[ $(grep setenforce /etc/rc.local | wc -l) -ge 1 ]]; then
    echo "防火墙已经关闭"
  else
    echo "setenforce 0 " >>/etc/rc.local
    sudo chmod +x /etc/rc.d/rc.local
    sudo systemctl stop firewalld
    #service NetworkManager stop
    #systemctl disable NetworkManager
    sudo systemctl disable firewalld
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    /usr/sbin/setenforce 0
    echo "防火墙关闭成功"
  fi
}

set_speed_limit(){
  echo "开始进行限速>>>>>>"
  # 要限速的网络接口
  INTERFACE="eth0"
  # 要限速的端口号
  PORT=443

  # 限速带宽，以kbps为单位
  LIMIT=8000

  sudo iptables -A INPUT -p udp --dport $PORT -m hashlimit --hashlimit-name UDP_LIMIT --hashlimit-mode srcip,dstport --hashlimit-above ${LIMIT}kbps -j DROP
  sudo iptables -A OUTPUT -p udp --sport $PORT -m hashlimit --hashlimit-name UDP_LIMIT --hashlimit-mode srcip,dstport --hashlimit-above ${LIMIT}kbps -j DROP

  echo "已对端口 $PORT 进行限速，限制为 ${LIMIT}kbps。"
}
block_bt() {
  echo "开始屏蔽BT>>>>>>"
  if [[ $(iptables -L | grep torrent | wc -l) -ge 1 ]]; then
      echo "已屏蔽bt"
    else
      echo "开始屏蔽bt"
      iptables -N LOGDROP > /dev/null 2> /dev/null
      iptables -F LOGDROP
      iptables -A LOGDROP -j LOG --log-prefix "LOGDROP "
      iptables -A LOGDROP -j DROP
      # Torrent ALGO Strings using Boyer-Moore
      iptables -A INPUT -m string --algo bm --string "BitTorrent" -j DROP
      iptables -A INPUT -m string --algo bm --string "BitTorrent protocol" -j DROP
      iptables -A INPUT -m string --algo bm --string "peer_id=" -j DROP
      iptables -A INPUT -m string --algo bm --string ".torrent" -j DROP
      iptables -A INPUT -m string --algo bm --string "announce.php?passkey=" -j DROP
      iptables -A INPUT -m string --algo bm --string "torrent" -j DROP
      iptables -A INPUT -m string --algo bm --string "announce" -j DROP
      iptables -A INPUT -m string --algo bm --string "info_hash" -j DROP
      iptables -A INPUT -m string --algo bm --string "/default.ida?" -j DROP
      iptables -A INPUT -m string --algo bm --string ".exe?/c+dir" -j DROP
      iptables -A INPUT -m string --algo bm --string ".exe?/c_tftp" -j DROP

      # Torrent Keys
      iptables -A INPUT -m string --string "peer_id" --algo kmp -j DROP
      iptables -A INPUT -m string --string "BitTorrent" --algo kmp -j DROP
      iptables -A INPUT -m string --string "BitTorrent protocol" --algo kmp -j DROP
      iptables -A INPUT -m string --string "bittorrent-announce" --algo kmp -j DROP
      iptables -A INPUT -m string --string "announce.php?passkey=" --algo kmp -j DROP

      # Distributed Hash Table (DHT) Keywords
      iptables -A INPUT -m string --string "find_node" --algo kmp -j DROP
      iptables -A INPUT -m string --string "info_hash" --algo kmp -j DROP
      iptables -A INPUT -m string --string "get_peers" --algo kmp -j DROP
      iptables -A INPUT -m string --string "announce" --algo kmp -j DROP
      iptables -A INPUT -m string --string "announce_peers" --algo kmp -j DROP
      echo "屏蔽bt完成"
    fi
  }

ovpen_install(){
  sudo mkdir -p /data/openvpn/conf
  sudo mkdir -p /data/dep/
  cd /data/dep/
  sudo git clone https://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@github.com/AllfreedomAll/opendev.git
  sudo cp -r /data/dep/opendev/openvpn/* /data/openvpn/
#  docker run -v /data/openvpn/conf/:/etc/openvpn --name openvpn-l -p 443:443/udp -d --restart always --privileged kylemanna/openvpn ovpn_run  --proto udp
#  docker run -e "OVPN_SERVER=43.157.55.233/18" -v /data/openvpn/conf/:/etc/openvpn --name openvpn -p 443:443/udp -d --restart always --privileged --sysctl net.ipv6.conf.all.disable_ipv6=0 --sysctl net.ipv6.conf.default.forwarding=1 --sysctl net.ipv6.conf.all.forwarding=1 kylemanna/openvpn ovpn_run --server 43.157.55.233 43.157.55.233 --proto udp
#  docker run -v /data/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://43.157.98.148
#  docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
#  docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full ling nopass
#  docker run -v /data/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient ling > /data/openvpn/conf/ling.ovpn
  sudo docker run --name openvpn -v /data/openvpn:/etc/openvpn -d -p 443:443/udp --cap-add=NET_ADMIN --restart always kylemanna/openvpn


}
docker_check
set_swap
block_firewall
set_speed_limit
block_bt
sudo systemctl restart docker
ovpen_install
echo "密码文件:/data/openvpn/password_file,格式 用户名 密码 ,一个用户明 密码一行，没有验证用户名，只验证了密码"
echo "客户端证书:/data/openvpn/ling.ovpn，修改其中的的 remote xxxx 443 udp 这一行,xxxx 为 机器的公网ip"