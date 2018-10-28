#!/bin/bash

if [[ -z $1 ]] || [[ $1 == -* ]]; then
  echo "usage: $0 <package.deb>"
  exit 1
fi

if [[ ! -f $1 ]]; then
  echo "file not found: $1"
  exit 2
fi

DEB_LOC="$1"

if ar t "$DEB_LOC" | grep '\.xz' > /dev/null; then
  echo 'recompressing deb to use gz instead of xz'
  EXTRACT="/tmp/$(openssl rand -hex 8)"
  dpkg-deb -R "$DEB_LOC" "$EXTRACT"
  DEB_LOC="/tmp/$(openssl rand -hex 8).deb"
  dpkg-deb --build -Zgzip "$EXTRACT" "$DEB_LOC"
  rm -rf "$EXTRACT"
fi

echo 'copying deb file'
PACKAGE_ID="$(dpkg -f "$DEB_LOC" Package)"
PACKAGE_VERSION="$(dpkg -f "$DEB_LOC" Version)"
FILENAME="./debs/${PACKAGE_ID}_${PACKAGE_VERSION}.deb"
cp "$DEB_LOC" "$FILENAME"

echo 'generating depiction'
DEPICTION_DIR="./depictions/$PACKAGE_ID"
mkdir "$DEPICTION_DIR"
echo "<changelog>
	<changes>
		<version>$PACKAGE_VERSION</version>
		<change>Initial Release</change>
	</changes>
</changelog>" > "$DEPICTION_DIR/changelog.xml"
SHORT_DESCRIPTION="$(dpkg -f "$DEB_LOC" Description)"
PACKAGE_AUTHOR_FULL="$(dpkg -f "$DEB_LOC" Author)"
PACKAGE_AUTHOR_NAME="$(grep -oP '[^<]+' <<< "$PACKAGE_AUTHOR_FULL" | head -n1 | xargs)"
PACKAGE_AUTHOR_EMAIL="$(grep -oP '.+ <\K.+(?=>)' <<< "$PACKAGE_AUTHOR_FULL")"
PACKAGE_NAME="$(dpkg -f "$DEB_LOC" Name)"
echo "<package>
	<id>com.shfdev.infinitown</id>
	<name>$PACKAGE_NAME</name>
	<version>$PACKAGE_VERSION</version>
	<compatibility>
		<firmware>
			<miniOS>7.0</miniOS>
		</firmware>
	</compatibility>
	<shortDescription>$SHORT_DESCRIPTION</shortDescription>
	<descriptionlist>" > "$DEPICTION_DIR/info.xml"
if [[ -n "$PACKAGE_AUTHOR_EMAIL" ]]; then
  echo "                <description>Author: &lt;a href=\"mailto:$PACKAGE_AUTHOR_EMAIL\"&gt;$PACKAGE_AUTHOR_NAME &amp;lt;$PACKAGE_AUTHOR_EMAIL&amp;gt;&lt;/a&gt;</description>" >> "$DEPICTION_DIR/info.xml"
else
  echo "                <description>Author: $PACKAGE_AUTHOR_NAME</description>" >> "$DEPICTION_DIR/info.xml"
fi
echo "	</descriptionlist>
</package>" >> "$DEPICTION_DIR/info.xml"

echo 'calculating md5sum'
MD5SUM="$(md5sum "$FILENAME" | awk '{print $1}')"
SIZE="$(stat --printf=%s "$FILENAME")"

echo 'adding info to packages list'
echo "
MD5sum: $MD5sum
Size: $SIZE
Depiction: https://xmb5.github.io/cydia/depictions/?p=$PACKAGE_ID" >> Packages
dpkg -f "$DEB_LOC" >> Packages
bzip2 -f -k Packages

echo 'adding to repo webpage'
sed -i 's/<!--insert here-->/\n        <div class="panel panel-default">\n          <div class="panel-heading">'"$PACKAGE_NAME"'<\/div>\n          <div class="panel-body">\n                '"$SHORT_DESCRIPTION"'<br \/><br \/>\n                <a class="btn btn-xs btn-default" href="depictions\/?p='"$PACKAGE_ID"'">More info<\/a>\n          <\/div>\n        <\/div>\n<!--insert here-->/' index.html
