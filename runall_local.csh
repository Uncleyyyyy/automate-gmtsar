#!/bin/csh -f

#run gmtsar_app in each subswath - local command, no qsub

if ( $#argv > 0 && ( $1 == '-h' || $1 == '--help' ) ) then
  echo "Usage: $0 [batch.config]"
  echo "Runs gmtsar_app for each subswath that has been set up (ls F?)"
  echo "if batch.config is given, it will be copied to all subswaths."
  exit 1
endif

set config = "batch.config"

#find subswaths to process
set subswaths = `ls -d F?`
echo "Processing subswaths $subswaths"

foreach F ( $subswaths ) 
  if ( $#argv == 1 ) then
    echo "copying user-specified config: $1"
    set config = $1
    cp $config $F
    set sat = `grep sat_name $config |awk '{print $3}'`
    if ( $sat == 'S1' ) then
      set n = `echo $F |sed 's/F//'`
      echo "Sentinel - setting s1_subswath value to $n in $config" 
      awk -v n=$n '/s1_subswath/{$3=n}1' $config > $config.temp
      mv $config.temp $config
    endif
  endif

  cd $F
  pwd
  #run gmtsar_app
  #qsub ../run_gmtsar_app.pbs -v config=$config
  python /Users/elindsey/Dropbox/code/geodesy/insarscripts/automate/gmtsar_app.py $config >& log_run_$F.txt &

  cd ..
end
