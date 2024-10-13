# BladeRF installation
sudo apt install -y git cmake make libusb-1.0-0-dev build-essential

# Define the repository URL and branch
REPO_URL="https://github.com/Nuand/bladeRF.git"
REPO_BRANCH="master"

# Clone the repository
git clone --branch $REPO_BRANCH $REPO_URL bladerf


cd bladeRF/host/

git submodule init
git submodule update

mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DINSTALL_UDEV_RULES=ON ../ # -DCMAKE_INSTALL_PREFIX=/usr/local
make
sudo make install
sudo ldconfig

cd ../../
rm -rf bladerf

echo "BladeRF C library installed successfully.