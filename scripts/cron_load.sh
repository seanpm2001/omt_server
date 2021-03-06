#
# cron_load.sh
#
# script does the following:
#  1. download the OSM meta file (stats) and compare it against a cached version from the last time the tiles were built
#  2. if the OSM meta (stats) data is are different, then will:
#   - download new OSM data 
#   - call import.sh  -- sub-process to rebuild *.mbtiles here in test, and validate that it's good
#   - bolt_reload.sh  -- sub-process to deploy new *.mbtiles server to remote (staging / production) servers via 'bolt'
#   - bolt_restart.sh -- sub-process to restart remote servers after new *.mbtiles are deployed there
#   - bolt_clear.sh   -- test that tileserver-gl is up and responding on remote servers, then clear file (tile) cache
#
DIR=`dirname $0`

START_GL_SH=${START_GL_SH:="start_gl_nohup.sh"}

ROOT_DIR=${ROOT_DIR:="$HOME/omt_server"}
DATA_DIR="$ROOT_DIR/openmaptiles/data"

OSM_SERVER=${OSM_SERVER:="http://maps6.trimet.org"}
OSM_META_FILE="or-wa.osm-stats"
OSM_FILE="or-wa-carto.osm.pbf"
OSM_META_URL="$OSM_SERVER/pelias/$OSM_META_FILE"
OSM_DATA_URL="$OSM_SERVER/pelias/$OSM_FILE"


function update_osm_data() {

  # step 1: move old OSM data aside
  if [ ! -d $DATA_DIR ]; then
    mkdir -p $DATA_DIR
  else
    old_osm_dir="$DATA_DIR/../old/"

    rm -rf /tmp/old
    mv $old_osm_dir /tmp/
    rm -rf $old_osm_dir
    mkdir -p $old_osm_dir
    mv $DATA_DIR/$OSM_META_FILE $old_osm_dir
    mv $DATA_DIR/$OSM_FILE $old_osm_dir
    mv $DATA_DIR/*mbtiles $old_osm_dir
  fi

  # step 2: grab new data
  curl $OSM_META_URL > $DATA_DIR/$OSM_META_FILE
  curl $OSM_DATA_URL > $DATA_DIR/$OSM_FILE

  # step 3: check new OSM data for size, etc... if not valid, revert back to old stuff
  #if [ size ]; then
    #bad_osm_dir="$DATA_DIR/../bad/"
    #rm -rf $bad_osm_dir
  #fi
  # TODO...
}


function check_osm_meta_data() {
  # returns true if the old and new gtfs files don't match
  ret_val=0

  if [ -d $DATA_DIR ]; then

    # step 1: grab meta data into tmp dir
    tmp_dir="$DATA_DIR/tmp"
    rm -rf $tmp_dir
    mkdir $tmp_dir
    curl $OSM_META_URL > $tmp_dir/$OSM_META_FILE

    # step 1b: make sure we have existing meta file to compare
    if [ ! -f $DATA_DIR/$OSM_META_FILE ]; then
      echo "NEW" > $DATA_DIR/$OSM_META_FILE
    fi
    
    # step 2: compare new meta data vs. old  
    DF=`diff $DATA_DIR/$OSM_META_FILE $tmp_dir/$OSM_META_FILE`
    if [ -z "$DF"  ]; then
	echo "OSM data match ... not reloading"
	ret_val=1
    else
	echo "OSM (meta) data DOES NOT match (eg: $DF)"
	ret_val=1
    fi
    rm -rf $tmp_dir
  fi

  return $ret_val
}


# update data 
check_osm_meta_data
new=$?
if [ $new == 1 ]; then
  echo "step 1: blow away existing GL / OMT Docker and data"
  rm -f $DIR/../gl/data/*
  `$DIR/nuke.sh ALL`

  echo "step 2: "
   update_osm_data
  `$DIR/import.sh`
  `$DIR/$START_GL_SH`
  #`$DIR/bolt/deploy.sh`
fi