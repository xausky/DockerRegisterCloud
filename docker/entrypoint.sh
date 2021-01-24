if [ $DRCD_ORIGIN ]; then
  sed -i "s|DRCD_ORIGIN|$DRCD_ORIGIN|g" ./build/web/index.html
fi
./drcd