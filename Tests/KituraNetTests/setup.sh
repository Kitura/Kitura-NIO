OS=`uname`
if [ $OS = "Darwin" ]; then
    sudo sysctl -w net.inet.ip.portrange.first=10000
    sudo sysctl -w net.inet.ip.portrange.last=20000
else
    sudo sysctl -w net.ipv4.ip_local_port_range="10000 20000"
fi
