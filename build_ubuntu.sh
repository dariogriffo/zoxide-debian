zoxide_VERSION=$1
BUILD_VERSION=$2
declare -a arr=("jammy" "noble")
for i in "${arr[@]}"
do
  UBUNTU_DIST=$i
  FULL_VERSION=$zoxide_VERSION-${BUILD_VERSION}+${UBUNTU_DIST}_amd64_ubu
  docker build . -f Dockerfile.ubu -t zoxide-ubuntu-$UBUNTU_DIST --build-arg UBUNTU_DIST=$UBUNTU_DIST --build-arg zoxide_VERSION=$zoxide_VERSION --build-arg BUILD_VERSION=$BUILD_VERSION --build-arg FULL_VERSION=$FULL_VERSION
  id="$(docker create zoxide-ubuntu-$UBUNTU_DIST)"
  docker cp $id:/zoxide_$FULL_VERSION.deb - > ./zoxide_$FULL_VERSION.deb
  tar -xf ./zoxide_$FULL_VERSION.deb
done
