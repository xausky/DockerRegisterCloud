if [ $DRCD_ORIGIN ]; then
  sed -i "s|DRCD_ORIGIN|$DRCD_ORIGIN|g" ./build/web/index.html
fi
if [ $PRELOAD_SCRIPT ]; then
  sed -i "s|</head>|$PRELOAD_SCRIPT</head>|g" ./build/web/index.html
fi
./drcd