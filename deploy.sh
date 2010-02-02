#! /bin/bash

#cd $(nims)/NIMSplugin/
xcodebuild -project NIMSplugin/NIMSplugin.xcodeproj 
cd NIMSplugin/build/Release/
zip -r NIMSplugin.zip NIMSplugin.AdiumPlugin
scp NIMSplugin.zip yootles.com:/var/www/html/yootles/nims/
cd ../../../
