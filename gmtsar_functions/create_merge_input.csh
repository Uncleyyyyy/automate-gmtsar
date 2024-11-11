#!/bin/csh -f

# input is list of files in intf_all

if ($#argv != 2) then
  echo ""
  echo "Usage: create_merge_input.csh path mode"
  echo ""
  echo "    Used to create inputlist for merge_batch.csh "
  echo "    input intf_list is the folder names in F?/intf_all"
  echo "    mode 0 is merging all 3 subswaths, mode 1 is for F1/F2"
  echo "    mode 2 is for F2/F3"
  echo ""
  echo "    Example: create_merge_input.csh .. 0"
  echo ""
  exit 1
endif

set mode = $2
set dir = $1

mkdir merge
cd merge
ls $dir/F2/intf > intf_list
ln -s ../topo/dem.grd .
cp ../batch.config .


foreach line (`awk '{print $0}' intf_list`)
  if ($mode == 0 || $mode == 1) then
    ls $dir/F1/intf/$line/*F1.PRM > tmp
    set pth = `awk NR==1'{print $1}' tmp | awk -F'/' '{for(i=1;i<NF;i++) printf("%s/",$i)}'`
    set f1 = `awk NR==1'{print $1}' tmp | awk -F'/' '{print $NF}'`
    set f2 = `awk NR==2'{print $1}' tmp | awk -F'/' '{print $NF}'`
    set txt1 = `echo $pth":"$f1":"$f2`
  endif

  ls $dir/F2/intf/$line/*F2.PRM > tmp 
  set pth = `awk NR==1'{print $1}' tmp | awk -F'/' '{for(i=1;i<NF;i++) printf("%s/",$i)}'`
  set f1 = `awk NR==1'{print $1}' tmp | awk -F'/' '{print $NF}'`
  set f2 = `awk NR==2'{print $1}' tmp | awk -F'/' '{print $NF}'`
  set txt2 = `echo $pth":"$f1":"$f2`

  if ($mode == 0 || $mode == 2) then
    ls $dir/F3/intf/$line/*F3.PRM > tmp 
    set pth = `awk NR==1'{print $1}' tmp | awk -F'/' '{for(i=1;i<NF;i++) printf("%s/",$i)}'`
    set f1 = `awk NR==1'{print $1}' tmp | awk -F'/' '{print $NF}'`
    set f2 = `awk NR==2'{print $1}' tmp | awk -F'/' '{print $NF}'`
    set txt3 = `echo $pth":"$f1":"$f2`
  endif
 
  if ($mode == 0) then
    echo $txt1","$txt2","$txt3
  endif
  if ($mode == 1) then
    echo $txt1","$txt2
  endif
  if ($mode == 2) then
    echo $txt2","$txt3
  endif
end

