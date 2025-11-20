TAG="${2:-master}"
apt update
apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    make \
    git \
    iptables \
    iproute2 \
    xtables-addons-common \
    xtables-addons-dkms
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
git clone https://github.com/ang3el7z/kvn-lite.git
cd ./kvn-lite
git checkout $TAG
echo "<?php

\$c = ['key' => '$1'];" > ./app/config.php
make u

# Автоматическая настройка автозапуска через crontab
PROJECT_PATH=$(pwd)
CRON_ENTRY="@reboot cd $PROJECT_PATH && make r"
(crontab -l 2>/dev/null | grep -v "@reboot.*make r"; echo "$CRON_ENTRY") | crontab -
echo "Автозапуск настроен: $CRON_ENTRY"
