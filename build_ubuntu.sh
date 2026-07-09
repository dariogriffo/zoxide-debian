zoxide_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$zoxide_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <zoxide_version> <build_version> [architecture]"
    echo "Example: $0 0.10.0 1 arm64"
    echo "Example: $0 0.10.0 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, armhf, riscv64, all"
    exit 1
fi

# Function to map Ubuntu architecture to zoxide release name
get_zoxide_release() {
    local arch=$1
    case "$arch" in
        "amd64")
            echo "zoxide-${zoxide_VERSION}-x86_64-unknown-linux-musl"
            ;;
        "arm64")
            echo "zoxide-${zoxide_VERSION}-aarch64-unknown-linux-musl"
            ;;
        "armhf")
            echo "zoxide-${zoxide_VERSION}-armv7-unknown-linux-musleabihf"
            ;;
        "riscv64")
            echo "zoxide-${zoxide_VERSION}-riscv64gc-unknown-linux-musl"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to build for a specific architecture
build_architecture() {
    local build_arch=$1
    local zoxide_release

    zoxide_release=$(get_zoxide_release "$build_arch")
    if [ -z "$zoxide_release" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64, armhf, riscv64"
        return 1
    fi

    echo "Building for architecture: $build_arch using $zoxide_release"

    # Clean up any previous builds for this architecture
    rm -rf "$zoxide_release" || true
    rm -f "${zoxide_release}.tar.gz" || true

    # Download and extract zoxide binary for this architecture
    if ! wget "https://github.com/ajeetdsouza/zoxide/releases/download/v${zoxide_VERSION}/${zoxide_release}.tar.gz"; then
        echo "❌ Failed to download zoxide binary for $build_arch"
        return 1
    fi

    # zoxide tarballs are flat, extract into a per-release directory
    mkdir -p "$zoxide_release"
    if ! tar -xf "${zoxide_release}.tar.gz" -C "$zoxide_release"; then
        echo "❌ Failed to extract zoxide binary for $build_arch"
        return 1
    fi

    rm -f "${zoxide_release}.tar.gz"

    # Build packages for appropriate Ubuntu distributions
    # riscv64 is only supported from noble (24.04) onwards
    if [ "$build_arch" = "riscv64" ]; then
        declare -a arr=("noble" "questing" "resolute")
    else
        declare -a arr=("jammy" "noble" "questing" "resolute")
    fi

    for dist in "${arr[@]}"; do
        FULL_VERSION="$zoxide_VERSION-${BUILD_VERSION}~${dist}_${build_arch}_ubu"
        echo "  Building $FULL_VERSION"

        if ! docker build . -f Dockerfile.ubu -t "zoxide-ubuntu-$dist-$build_arch" \
            --build-arg UBUNTU_DIST="$dist" \
            --build-arg zoxide_VERSION="$zoxide_VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg ZOXIDE_RELEASE="$zoxide_release"; then
            echo "❌ Failed to build Docker image for $dist on $build_arch"
            return 1
        fi

        id="$(docker create "zoxide-ubuntu-$dist-$build_arch")"
        if ! docker cp "$id:/zoxide_$FULL_VERSION.deb" - > "./zoxide_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb package for $dist on $build_arch"
            return 1
        fi

        if ! tar -xf "./zoxide_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb contents for $dist on $build_arch"
            return 1
        fi
    done

    # Clean up extracted directory
    rm -rf "$zoxide_release" || true

    echo "✅ Successfully built for $build_arch"
    return 0
}

# Main build logic
if [ "$ARCH" = "all" ]; then
    echo "🚀 Building zoxide $zoxide_VERSION-$BUILD_VERSION for all supported architectures..."
    echo ""

    # All supported architectures (Ubuntu dropped armel and i386 support)
    ARCHITECTURES=("amd64" "arm64" "armhf" "riscv64")

    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="

        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi

        echo ""
    done

    echo "🎉 All architectures built successfully!"
    echo "Generated packages:"
    ls -la zoxide_*.deb
else
    # Build for single architecture
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
