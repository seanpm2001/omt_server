##
## update a given tile server
##
BDIR=`dirname $0`
. $BDIR/bolt-base.sh
. $BDIR/../base.sh

MACHINE=${1:-"cs-st-mapapp01"}

# step 0: validate *.mbtiles ... proper size before updating a server
size=`ls -ltr $MBTILES_PATH | awk -F" " '{ print $5 }'`
if [[ $size -gt $MIN_FILE_SIZE ]]
then
  INFO="step 1: kill OMT on server $MACHINE and backup old data"
  echo; echo $INFO
  bolt command run "cd $OMT_DIR; ./scripts/nuke.sh ALL; ./scripts/mbtiles/backup.sh" --targets $MACHINE
  bolt command run "update.sh; cd $OMT_DIR; git reset --hard HEAD" --targets $MACHINE

  INFO="step 2: scp new data $GL_DATA_DIR $MACHINE:$GL_DIR"
  echo; echo $INFO $SCP
  scp -r $GL_DATA_DIR $MACHINE:$GL_DIR

  INFO="step 3: restart GL server on $MACHINE"
  echo; echo $INFO
  bolt command run "cd $OMT_DIR; ./scripts/gen_hostname_txt.sh" --targets $MACHINE
  bolt command run "cd $OMT_DIR/gl/; ./run-nohup.sh" --targets $MACHINE
  sleep 3
  echo
  bolt command run "docker ps" --targets $MACHINE
  sleep 3
  echo
  $BDIR/test-gl.sh $MACHINE
  echo
else
  echo
  echo "ERROR: $MBTILES_PATH is too small at $size to copy over to $MACHINE"
  echo "NOT updating / restarting $MACHINE !!!"
  echo
fi

