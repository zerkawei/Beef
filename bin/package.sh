set -e

if [ "$#" -gt 0 ]; then
    VERSION=$1
else
    VERSION="$(git describe --tags --long | sed -E 's/^([^-]+)-([0-9]+)-g([0-9a-f]+)$/\1+git\2.\3/')"
fi

echo Starting package.sh

### PREPARE ###

install -d install/usr/bin
ln -s /opt/BeefLang/bin/BeefBuild install/usr/bin/beefbuild

### PACKAGE ###

ARCH="$(uname -m)"
PACKAGE="beeflang_${VERSION}_${ARCH}"

echo "Creating packages for version $VERSION"

install -d package

fpm -t deb --version $VERSION -p package/$PACKAGE.deb 
fpm -t rpm --version $VERSION -p package/$PACKAGE.rpm
tar -czf package/$PACKAGE.tar.gz -C install/opt/ BeefLang/