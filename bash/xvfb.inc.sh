_xvfb_start() {
  if ! pidof Xvfb; then
    Xvfb -screen 0 1920x1080x24 :99 &
    echo -n $! > ~/.vxfb.pid
    echo 'export DISPLAY=:99' > ~/.xvfb.inc
  fi
  source ~/.xvfb.inc
  renice 19 $$
  ionice -c3 -p$$
}
