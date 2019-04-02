# Maintainer: Arthur Williams <taaparthur@gmail.com>


pkgname='xsane-xrandr'
pkgver='0.9.0'
_language='en-US'
pkgrel=3
pkgdesc='Allows insance XRandr configurations'

arch=('any')
license=('MIT')
depends=('xorg-xrandr' 'python')
makedepends=('git')
md5sums=('SKIP')

source=("git+https://github.com/TAAPArthur/xsane-xrandr.git")
_srcDir="xsane-xrandr"

package() {
  cd "$_srcDir"
  make DESTDIR=$pkgdir install
}
