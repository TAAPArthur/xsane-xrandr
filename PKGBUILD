# Maintainer: Arthur Williams <taaparthur@gmail.com>


pkgname='xsane-xrandr'
pkgver='1.0.0'
_language='en-US'
pkgrel=0
pkgdesc='Allows insane XRandr configurations'

arch=('any')
license=('MIT')
depends=('xorg-xrandr' )
optdepends=('python3')
makedepends=('git')
md5sums=('SKIP')

source=("git+https://github.com/TAAPArthur/xsane-xrandr.git")
_srcDir="xsane-xrandr"

package() {
  cd "$_srcDir"
  make DESTDIR=$pkgdir install
}
