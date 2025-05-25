zoxide_VERSION=$1
BUILD_VERSION=$2
declare -a arr=("bookworm" "trixie" "sid")
for i in "${arr[@]}"
do
  DEBIAN_DIST=$i
  FULL_VERSION=$zoxide_VERSION-${BUILD_VERSION}+${DEBIAN_DIST}_amd64
docker build . -t zoxide-$DEBIAN_DIST  --build-arg DEBIAN_DIST=$DEBIAN_DIST --build-arg zoxide_VERSION=$zoxide_VERSION --build-arg BUILD_VERSION=$BUILD_VERSION --build-arg FULL_VERSION=$FULL_VERSION
  id="$(docker create zoxide-$DEBIAN_DIST)"
  docker cp $id:/zoxide_$FULL_VERSION.deb - > ./zoxide_$FULL_VERSION.deb
  tar -xf ./zoxide_$FULL_VERSION.deb
done


