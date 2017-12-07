#!/bin/bash
# makefingerprint generates a video perceptual hash for an input
SCRIPTDIR=$(dirname $(which "${0}"))
. "${SCRIPTDIR}/mmfunctions" || { echo "Missing '${SCRIPTDIR}/mmfunctions'. Exiting." ; exit 1 ;};
SUFFIX="_signature"
EXTENSION="xml"
RELATIVEPATH="metadata"

## Insert DB Settings Here!
DBNAME=""
DBLOGINPATH=""

_report_fingerprint_db(){
    table_name="fingerprints"
    (IFS=$'\n'
    for i in ${VIDEOFINGERPRINT} ; do
    hash1=$(echo "$i" | cut -d':' -f3)
    hash2=$(echo "$i" | cut -d':' -f4)
    hash3=$(echo "$i" | cut -d':' -f5)
    hash4=$(echo "$i" | cut -d':' -f6)
    hash5=$(echo "$i" | cut -d':' -f7)
    startframe=$(echo "$i" | cut -d':' -f1)
    endframe=$(echo "$i" | cut -d':' -f2)
    echo "INSERT INTO fingerprints (objectIdentifierValue,startframe,endframe,hash1,hash2,hash3,hash4,hash5) VALUES ('${MEDIA_ID}','${startframe}','${endframe}','${hash1}','${hash2}','${hash3}','${hash4}','${hash5}')" | mysql --login-path="${DBLOGINPATH}"  "${DBNAME}"
    done)
}

_fingerprint_to_db(){
VIDEOFINGERPRINT=$(xmlstarlet sel -N "m=urn:mpeg:mpeg7:schema:2001" -t -m "m:Mpeg7/m:DescriptionUnit/m:Descriptor/m:VideoSignatureRegion/m:VSVideoSegment" -v m:StartFrameOfSegment -o ':' -v m:EndFrameOfSegment -o ':' -m m:BagOfWords -v "translate(.,' ','')" -o ':' -b -n "${FINGERPRINT_XML}")
}

while [ "${*}" != "" ] ; do
    # get context about the input
    INPUT="${1}"
    shift
    if [ -z "${OUTPUTDIR_FORCED}" ] ; then
        [ -d "${INPUT}" ] && { OUTPUTDIR="$INPUT/metadata/${RELATIVEPATH}" && FINGERDIR="${INPUT}/metadata/fingerprints" ;};
        [ -f "${INPUT}" ] && { OUTPUTDIR=$(dirname "${INPUT}")"/${RELATIVEPATH}" && FINGERDIR="$(dirname "${INPUT}")/fingerprints" ;};
        [ ! "${OUTPUTDIR}" ] && { OUTPUTDIR="${INPUT}/metadata/${RELATIVEPATH}" && FINGERDIR="${INPUT}/metadata/fingerprints" ;};
    else
        OUTPUTDIR="${OUTPUTDIR_FORCED}"
        FINGERDIR="${OUTPUTDIR}/metadata/fingerprints"
    fi
    _unset_variables
    _find_input "${INPUT}"
    MEDIAID=$(basename "${INPUT}" | cut -d. -f1)

    if [ "${FINGERDIR}" != "" ] ; then
        _mkdir2 "${FINGERDIR}"
    fi
    #Generate Fingerprint
    SIGNATURE="${MEDIAID}""${SUFFIX}"."${EXTENSION}"
    _run_critical_event ffmpeg "${FFMPEGINPUT[@]}" -vf signature=format=xml:filename="${FINGERDIR}/${SIGNATURE}" -map 0:v -f null -
    FINGERPRINT_XML="${FINGERDIR}/${SIGNATURE}"

#Report to DB
    _fingerprint_to_db
    _report_to_db
    _report_fingerprint_db
    gzip "${FINGERPRINT_XML}"
done