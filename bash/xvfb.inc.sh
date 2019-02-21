_xvfb_start() {
  Xvfb -screen 0 1920x1080x24 :99 &
  echo -n $! > ~/.vxfb.pid
  export DISPLAY=:99
  renice 19 $$
  ionice -c3 -p$$
}
