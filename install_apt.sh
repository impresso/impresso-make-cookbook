sudo apt update
sudo apt upgrade -y
sudo apt install git git-lfs make remake parallel coreutils  # needed for building
# Ensure python3.11 and python3.11-dev are installed; add deadsnakes PPA if needed
if ! dpkg -s python3.11 >/dev/null 2>&1 || ! dpkg -s python3.11-dev >/dev/null 2>&1; then
  sudo add-apt-repository -y ppa:deadsnakes/ppa
  sudo apt update
  sudo apt install -y python3.11 || true
  sudo apt install -y python3.11-dev || true
  sudo apt install -y python3.11-distutils || true
fi
python3.11 -mpip help > /dev/null || { curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 ; }
