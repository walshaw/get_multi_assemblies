#!/bin/bash

# get_multi_assemblies.bash version 0.1, Feb 2018.
# John Walshaw.

# This script is geared towards getting all of the *assembled and annotated
# sequence data* for all of the assemblies (genomes) associated with a
# single project (SRA Study). (I.e. NOT the reads files.)

ID=$1 # SRA Project ("Study") ID.
shift

# flags:
# -setids:	retrieve and display WGS Sequence Set IDs (whole ID lines)
# -idranges:	retrieve and display ranges of Assembly contig IDs
# -contigs:	retrieve the sequence data (EMBL format) for each range of
#		Assembly contig IDs (only valid if -idranges is used)
# -rewrite:	force overwrite of file whose name is specified by -seqsets
#		if that file already exists (only valid if -seqsets is used)

# parameters:
# -seqsets <OUTPUT_FILE_NAME>
#	- writes all of the sequence set data (EMBL format) to this file;
#	- this also speeds up the retrievals (see -setids and -idranges)
# 	because the retrieving is done from this file, instead of on-the-fly
#	for each retrieval.


if [[ "$ID" == "" ]]; then
    echo "specify assembly ID [ optionally followed by task code i.e. integer ] "
    exit 1
fi


clargs() {

NEXTVAR=$1

while [[ $NEXTVAR != "" ]]; do

    MATCHED=0

    for FLG in $FLAGS; do

        FLAGVAR=`echo $FLG | tr a-z A-Z`
        if [[ "$NEXTVAR" == "-$FLG" ]]; then
            eval "$FLAGVAR=1"
            MATCHED=1
            break
        fi

    done

    if [[ $MATCHED -eq 1 ]]; then
        shift
        NEXTVAR=$1
        continue
    fi

    for PAR in $PARS; do
        PARVAR=`echo $PAR | tr a-z A-Z`
        if [[ "$NEXTVAR" == "-$PAR" ]]; then
            shift
            PARVAL=$1
            if [[ "$PARVAL" == "" ]]; then
                echo "-$PAR requires a value"
		exit 1
            fi
            eval "$PARVAR=$PARVAL"
            MATCHED=1
            break
        fi

    done

    if [[ $MATCHED -eq 0 ]]; then
	echo "unrecognized argument '$NEXTVAR'"
        exit 1
    fi

    shift
    NEXTVAR=$1

done


} # end of clargs() definition



FLAGS="setids idranges contigs rewrite"

PARS="seqsets"

clargs "$@"

VIEW_URL=https://www.ebi.ac.uk/ena/data/view
PROJECT_URL=$VIEW_URL/$ID

# To get the EMBL-format data for *all* of the "WGS Sequence sets"
# associated with this project, this is the URL:
WGS_SETS_URL="'$PROJECT_URL&portal=wgs_set&display=text'" # note essential ' '

WGET_PREFIX="wget -O"
WGET_PREFIXQ="wget -q -O"
WGET_STDOUT="$WGET_PREFIXQ -"
WGET_SEQSETS="$WGET_PREFIX $SEQSETS"
WGET_CONTIGS="$WGET_PREFIX $CONTIGS"

if [[ "$SEQSETS" != "" ]]; then

    if [[ $REWRITE -eq 0 ]]; then
        WGET_SEQSETS="$WGET_SEQSETS -nc" # -nc is short form of --no-clobber
    fi

    WGET="$WGET_SEQSETS $WGS_SETS_URL"
    echo $WGET
    eval $WGET

    if [[ $SETIDS -gt 0 ]]; then
        GREP="grep '^ID   ' $SEQSETS"
        echo $GREP
        eval $GREP
    fi

    if [[ $IDRANGES -gt 0 ]]; then
        GREP="grep '^WGS  ' $SEQSETS"
        echo $GREP
        eval $GREP
        GREP_RANGE_IDS="$GREP | awk '{ print \$2 }'"
        echo $GREP_RANGE_IDS
        RANGE_IDS=`eval $GREP_RANGE_IDS`
        echo $RANGE_IDS
    fi

else

    if [[ $rewrite -gt 0 ]]; then
        echo "-rewrite is invalid unless -seqsets is used"
        exit 1
    fi

    if [[ $SETIDS -gt 0 ]]; then
        WGET="$WGET_STDOUT $WGS_SETS_URL | grep '^ID   '"
        echo $WGET
        eval $WGET
    fi

    if [[ $IDRANGES -gt 0 ]]; then
        WGET="$WGET_STDOUT $WGS_SETS_URL | grep '^WGS   ' | awk '{ print \$2 }'"
        echo $WGET
        RANGE_IDS=`eval $WGET`
        # this odd-looking reconstruction is due to loss of newlines in the
	# expansion; rebuilding the table is to keep consistency with the
	# output produced if -seqsets is used
        for RANGE in $RANGE_IDS; do echo "WGS   $RANGE"; done
        echo $RANGE_IDS
    fi

fi

if [[ $CONTIGS -gt 0 ]]; then

    if [[ $IDRANGES -eq 0 ]]; then
        echo "-contigs is invalid without -idranges"
        exit
    fi

    if [[ "$RANGE_IDS" == "" ]]; then
        echo "failed to determine (range of) contig sequence record IDS"
        exit 1
    fi

    for RID in $RANGE_IDS; do
        RANGE_URL="$VIEW_URL/$RID&display=text"
        ###echo $RANGE_URL
        WGET="$WGET_PREFIX $RID.embl '$RANGE_URL'"
        echo $WGET
        eval $WGET
    done
fi

exit 0


