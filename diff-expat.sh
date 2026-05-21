# Make separate directories for each version
mkdir -p -m 777 old new

cd old
# apt-get source libexpat1=2.5.0-1
dget -u https://snapshot.debian.org/archive/debian/20221027T213940Z/pool/main/e/expat/expat_2.5.0-1.dsc
cd ..

cd new  
apt-get source libexpat1=2.5.0-1+deb12u1
cd ..

diff -r old/expat-2.5.0/debian/patches new/expat-2.5.0/debian/patches > expat-patches.diff