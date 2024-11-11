#!/bin/csh -f
#
# geocode output of the sbas program at specified resolution (vel.grd and disp_YYYYDDD.grd files)
#
# original version created by Eric Lindsey, June 2020

#
# geocode the output
#
ln -s ../topo/trans.dat .
ln -s ../topo/dem.grd .

foreach file (`ls disp_???????.grd`)
  echo "geocode $file"
  set file_ll = `basename $file .grd`_ll.grd
  set file_trend = `basename $file .grd`_detrended.grd
  set figure = `basename $file .grd`_ll.ps
  set cpt = `basename $file .grd`.cpt
  proj_ra2ll.csh trans.dat $file $file_ll
  gmt grdtrend $file_ll -N3r -D$file_trend
  gmt grd2cpt $file_trend -T= -Z -Cseis > $cpt
  grd2kml.csh `basename $file_trend .grd` $cpt
end

echo ""
echo "Finished all geocoding jobs..."
echo ""

#echo "geocode vel.grd"
#proj_ra2ll.csh trans.dat vel.grd vel_ll.grd
#gmt grdgradient vel_ll.grd -Nt.9 -A0. -Gvel_grad.grd
#set tmp = `gmt grdinfo -C -L2 vel.grd`
#set limitU = `echo $tmp | awk '{printf("%5.1f", $12+$13*2)}'`
#set limitL = `echo $tmp | awk '{printf("%5.1f", $12-$13*2)}'`
#gmt makecpt -Cjet -Z -T"$limitL"/"$limitU" -D > vel_ll.cpt
#gmt grdimage vel_ll.grd -Ivel_grad.grd -Q -Cvel_ll.cpt -Bxaf+lLongitude -Byaf+lLatitude -BWSen -JM6.5i -Y3i -P -K > vel_ll.ps
#gmt psscale -Rvel_ll.grd -J -DJTC+w5i/0.2i+h+e -Cvel_ll.cpt -Bxaf+l"Velocity" -By+lmm/yr -O >> vel_ll.ps
#gmt psconvert -Tf -P -A -Z vel_ll.ps
#grd2kml.csh vel_ll vel_ll.cpt
