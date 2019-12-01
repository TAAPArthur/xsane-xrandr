# Maintainer: Arthur Williams <taaparthur at gmail dot com>

pkgname='xsane-xrandr'
pkgver='1.0'
pkgrel=0
pkgdesc='Utility script to create and manage user defined monitors'
url="https://github.com/TAAPArthur/xsane-xrandr"
arch=('any')
license=('MIT')
depends=('xorg-xrandr' )
optdepends=('python3: for the configure command')
makedepends=('git')
md5sums=('SKIP')

source=("git+https://github.com/TAAPArthur/xsane-xrandr.git")
_srcDir="xsane-xrandr"

package() {
  cd "$_srcDir"
  make DESTDIR=$pkgdir install
}
