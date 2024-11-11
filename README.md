GMTSAR APP: 基于GMTSAR的自动化python脚本
------------

Originally edited by Eric Lindsey, last updated June 2021

Modified by Hal Xu, 2024

原项目中包含了一系列用户友好的python以及C-shell脚本，用户只需要在几个节点进行交互即可运行下一个步骤，基于本人工作习惯做了适当修改，并且准备了该简中版本recipe。有关Sentinel-1数据的示例请参阅以下说明：

**设置与安装**

最新测试：适用于GMT 6.4.0、GMTSAR 6.5以及Python 3.8。

需要用户根据GMTSAR项目主页的wiki提前安装好GMTSAR：https://github.com/gmtsar/gmtsar/wiki。

首先将GMTSAR_APP下载到本地（一般存放脚本的地方）：

```terminal
git clone https://github.com/Uncleyyyyy/automate-gmtsar.git AutomateGMTSAR
cd AutomateGMTSAR/
```

在AutomateGMTSAR/目录下运行：

```terminal
./setup_gmtsar_app.sh
```

此时会打印出一个export指令，参考打印出来的指引将指令复制添加到您的~/.bashrc或.zshrc，然后重新打开终端或者在目前终端：

```terminal
source ~/.bashrc
```

此时我们将AutomateGMTSAR/添加到了环境变量中，在之后的步骤中我们可以通过$GMTSAR_APP来指向当前路径。

同时我们需要保证后面会用到的run_gmtsar_app.csh是可执行文件：

```terminal
chmod +x run_gmtsar_app.csh
```

**IMPORTANT: ** 如果需要在slurm作业系统下通过srun运行该脚本，我们需要修改run_gmtsar_app.csh：

```shell
- 64 nohup python $GMTSAR_APP/gmtsar_app.py $config > & run_gmtsar_app.log &
+ 64 python $GMTSAR_APP/gmtsar_app.py $config
```

**设置GMTSAR_APP工作目录**

GMTSAR_APP的底层逻辑仍然是调用一系列GMTSAR脚本，所以与GMTSAR要求的形式类似，我们需要提前准备我们的工作目录。

```terminal
# create 1st-level directory and replace the name '$work_dir' with
# the name of your project
mkdir $work_dir
cd $work_dir
# create 2nd-level directory
mkdir asc dsc
cd asc/
mkdir raw raw_orig topo orbit 
# same operation in directory $work_dir/dsc/
```

- raw/：用来存放所有下载的数据，包括SAR数据、S1轨道数据，并进行拼接等处理。
- topo/：之后用来存放DEM数据。
- orbit/：之后请将raw/中的S1轨道数据(*.EOF)与辅助校正文件链接至此。
- raw_orig/：GMTSAR_APP所需目录，之后请将raw/中的SAR数据(*.SAFE)链接至此。

**数据准备与下载**

以升轨情况为例，我们目前位于asc/目录下。

- 准备Sentinel-1 SLC数据：

  Alaska Satellite Facility (ASF) 数据网址：https://search.asf.alaska.edu/#/

  在这里我们可以通过调整Search Filters中的各项参数选择研究区域并且查看并选择覆盖研究区域的Sentinel-1 SLC数据，记录下此时Search Filters中的参数。

  ```terminal
  cd raw/
  cp $GMTSAR_APP/sentinel_query* .
  ```

  此时我们将AutomateGMTSAR/目录中基于ASF网站的API进行SLC数据自动下载的脚本拷贝到了raw/目录中。

  打开sentinel_query.config，我们将ASF网站的Search Filters中的参数填入其中，例如：

  ```sentinel_query.config
  [api_search]
  output = csv
  platform = Sentinel-1A,Sentinel-1B
  processingLevel = SLC
  beamMode = IW
  intersectsWith = POLYGON((100.5 37,102 37,102 38.5,100.5 38.5,100.5 37))
  start=2022-01-10T00:00:00UTC
  end=2022-03-31T00:00:00UTC
  relativeOrbit=33
  asfframe=467
  download_site = ASF
  nproc = 4
  http-user = uncley
  http-password = Xyhstc453145
  ```

  其他可选参数详情见.config文件中的注释，基于以上config文件，我们可以通过如下指令检查数据的搜索结果：

  ```terminal
  python sentinel_query_download.py sentinel_query.config --verbose
  ```

  确认无误后进行下载：

  ```terminal
  python sentinel_query_download.py sentinel_query.config --download
  ```

  下载完成后我们将会得到一系列按PathNo./FrameNo./S1A_IW_SLC__1SDV_20231218T135441_20231218T135509_051710_063EB3_C9E6.zip分类方式整理的每一景SLC数据的压缩包，全部解压至raw/目录下即可。

  ```terminal
  for file in $(find ./ -name '*.zip')  
  do  
  unzip $file
  done
  ```

  此时raw/目录下将会出现一系列.SAFE文件，即是我们所需要的每一景SLC数据。

  这一步对应sentinel_time_series_6.pdf中的第3节。

- 准备DEM数据：

  我们需要提前准备可以完全覆盖SLC数据控制范围的DEM数据，以用来在之后的干涉过程中消除地形相位的影响。

  ```terminal
  cd topo/
  # Generate DEM by GMTSAR script make_dem.csh
  make_dem.csh W E S N [mode]
  ```

  此时topo/目录下将生成dem.grd和一系列过程中的文件，最终我们会使用的将只有dem.grd。

  这一步对应sentinel_time_series_6.pdf中的第2节。

- 准备轨道数据：

  首先我们需要准备Sentinel-1的辅助校正数据S1A/B-AUX-CAL：https://sar-mpc.eu/

  由于网站关闭了api，所以我们现在只能手动下载，这个数据不常更新，选择日期最新的下载即可。下载得到的压缩包解压后我们只需要保留data目录中的s1a/b-aux-cal.xml文件即可，这两个文件会反复使用，建议下好之后放到一个常用的数据库目录下。

  如果我们下载的SLC数据来自Sentinel-1A卫星，那么我们需要提前将s1a-aux-cal.xml复制到orbit/下；

  如果我们下载的SLC数据来自Sentinel-1B卫星，那么我们需要提前将s1b-aux-cal.xml复制到orbit/下；

  如果我们需要同时用到两种卫星的SLC数据，那么我们需要提前将s1a和s1b-aux-cal.xml都复制到orbit/下；

  轨道数据分为精密轨道数据(Precise Orbit)与还原轨道数据(Restitute Orbit)，通常在一景SLC数据发布后的20天之后其对应的精密轨道数据才可供下载，如果需要在20天之内做一些快速处理则只能使用还原轨道数据。

  进入raw/目录下，我们首先需要将我们的SAFE文件列到一个SAFE_list：

  ```terminal
  cd raw/
  ls -d $PWD/*SAFE > SAFE_list
  less SAFE_list 
  # to look at it and check, should look like:
  # /absolute path to/asc/raw/S1A_IW_SLC__1SDV_20180219T043025_20180219T043053_020671_023679_5817.SAFE
  # /absolute path to/asc/raw/S1A_IW_SLC__1SDV_20180315T043025_20180315T043053_021021_024191_5F9B.SAFE
  # /absolute path to/asc/raw/S1A_IW_SLC__1SDV_20180327T043025_20180327T043053_021196_024722_A9DB.SAFE
  ```

  1. 直接进行轨道下载：

     我们可以通过GMTSAR脚本download_sentinel_orbits_linux.csh实现两种轨道数据的下载：

     ```terminal
     # if you want to download precise orbits, use mode 1
     download_sentinel_orbits_linux.csh SAFE_list 1 >& dso_mode1.log &
     # if you want to download restitute orbits, use mode 2
     download_sentinel_orbits_linux.csh SAFE_list 2 >& dso_mode2.log &
     ```

     下载结束后我们将raw/目录下的文件链接到相应的文件夹

     ```terminal
     cd ../raw_orig
     ln -s ../raw/*SAFE
     cd ../orbit
     ln -s ../raw/*EOF
     cd ..
     ```

     此时raw_orig/下应该是SLC所对应的 *SAFE文件，topo/下应该是dem.grd，orbit/下应该是轨道所对应的 *EOF文件以及s1a/b-aux-cal.xml。

  2. 在对SLC进行拼接、删减操作的时候同时下载轨道：

     大部分情况下我们的研究区域横跨了多景SLC或者只是一景SLC中的很小一部分，这个时候我们需要先在Google Earth中打开.SAFE/preview中的.kml文件，用两个placemark限定自己研究区域的南北范围，将placemark的经纬度记录到pins.ll。

     需要注意两个placemark的先后顺序必须沿着卫星的飞行方向（由南至北或由北至南），例如升轨的pins.ll应该类似于：

     ```pins.ll
     -155.13 18.95
     -155.30 19.75
     ```

     而降轨的pins.ll则应该是：

     ```pins.ll
     -155.30 19.75
     -155.13 18.95
     ```

     然后通过GMTSAR脚本organize_files_tops_linux.csh对SLC进行拼接或是删减，同时下载精密轨道数据：

     ```terminal
     organize_files_tops_linux.csh SAFE_list pins.ll 1 >& oft_mode1.log &
     organize_files_tops_linux.csh SAFE_list pins.ll 2 >& oft_mode2.log &
     ```

     organize结束之后在raw/目录下会出现一个F????_F????文件夹，里面同样是一些.SAFE文件夹，这些是拼接/删减完成后的SLC文件，在后续干涉处理中我们将使用这些SLC而不是原始下载的SLC。

     ```terminal
     cd ../raw_orig
     ln -s ../raw/F????_F????/*SAFE
     cd ../orbit
     ln -s ../raw/*EOF
     cd ..
     ```

  这一步对应sentinel_time_series_6.pdf中的第4节。

**预处理**

在数据准备完成之后我们在asc/下运行：

```terminal
$GMTSAR_APP/setup_tops.csh
```

此时目录下将会多出对应三个子带的F1/2/3文件夹，并且之前准备的数据已经链接到了其中。

InSAR处理流程中的预处理包括：

- 选择主辅影像
- 对齐(align)
- 将dem.grd转换到雷达坐标下

在GMTSAR_APP的设计思路中这三步对应stage 1~3，通过将batch.config中的相关参数设置为：

```batch.config
startstage = 1
endstage = 3
```

设置完成后在终端运行：

```
./run_gmtsar_app.csh batch.config
```

即可线性地进行这三步过程。预处理结束后我们将在F1/2/3中看到raw/以及SLC/文件夹。

raw/目录下包含了每一景的.SLC图像，以及对应的.PRM参数文件和.LED轨道文件，同时还有baseline.dat以便我们确认主辅影像之间的基线长短。

SLC/目录下则是raw/中每一景.SLC、.PRM、.LED文件的软链接。

topo/目录下也会生成一些新的文件，例如trans.dat，这是图像中每个像素点的雷达坐标与地理坐标之间的一个look-up table，用于数据在两个坐标系之间的互转。

这一步对应sentinel_time_series_6.pdf中的第5节。

**干涉**

如果过程正确无报错的话我们就可以开始干涉，以F2子带为例，将batch.config中threshold_snaphu与threshold_geocode设置为0以跳过解缠与地理编码：

```batch.config
s1_subswath = 2
startstage = 4
endstage = 4

filter_wavelength = 100
dec_factor = 2
threshold_snaphu = 0
defomax = 0
threshold_geocode = 0
```

如果后续需要进行SBAS分析，需要准备不同基线大小的干涉对，我们既可以通过GMTSAR脚本也可以通过GMTSAR_APP脚本来生成。

1. 通过GMTSAR_APP自动生成intf.in并进行干涉，检查batch.config并对以下参数作出调整：

   ```batch.config
   restart = True				#restart设置为True将会在每次运行的时候删掉之前的intf.in文件重新生成
   num_processors = 4			#并行任务数
   max_timespan = 100			#最大时间基线阈值
   max_baseline = 100			#最大空间基线阈值
   intf_min_connectivity = 2	#设置为2保证每一景至少与其他两景组成干涉对
   ```

   设置完成后在终端运行：

   ```terminal
   ./run_gmtsar_app.csh batch.config
   ```

   此时F2/目录下出现intf/、intf_all/、logs_intf/三个文件夹，说明干涉正在进行，可以时刻检查logs_intf/目录下的.log文件或者intf/目录下对应文件夹中的产品来确认干涉过程是否正常进行。

2. 如果有需要手动添加干涉对的情况，我们也可以自行创建intf.in。GMTSAR脚本select_pairs.csh基于raw目录下的baseline.dat，通过设置最大时空基线阈值来初步生成基线长短不超过这两个值的干涉对，以F2为例：

   ```terminal
   cd F2/raw
   select_pairs.csh baseline_table.dat threshold_time threshold_baseline
   #  generate the input file for intf_tops.csh with given threshold of time and baseline
   #  outputs:
   #    intf.in
   ```

   此时raw/下将会生成包含了不同基线大小干涉对的intf.in和一幅展示了干涉对之间connectivity的baseline.ps，我们可以手动向intf.in中继续添加值得处理的干涉对。

   准备好了之后我们将intf.in从raw/目录下移动到F2/目录下，此时我们可以先对一对干涉对进行干涉以检查有没有任何问题：

   ```terminal
   head -1 intf.in > one.in
   ```

   修改batch.config的参数。

   ```batch.config
   restart = false				#restart设置为false则不会重新生成intf.in，而是直接使用我们创建的输入文件
   intf_file = one.in			#输入文件设置为one.in
   num_processors = 1			#我们只需要干涉一景
   ```

   设置完成后在终端运行：

   ```terminal
   ./run_gmtsar_app.csh batch.config
   ```

   运行结束后我们可以前往F2/intf/???????_???????/目录下检查生成的相干性图corr.png，干涉图phase_filt.png等产品。

   一切没有问题的话我们就可以对所有干涉对进行干涉，修改batch.config的参数：

   ```batch.config
   restart = false				#restart设置为false则不会重新生成intf.in，而是直接使用我们创建的输入文件
   intf_file = intf.in			#输入文件设置为intf.in
   num_processors = 4			#并行任务数
   ```

   设置完成后在终端运行：

   ```terminal
   ./run_gmtsar_app.csh batch.config
   ```

这一步对应sentinel_time_series_6.pdf中的第6节。

**合并多个子带**

如果我们的研究区域横跨多个子带，那么我们最好在干涉之后先merge所需要的子带再进行后续的解缠等环节。

```terminal
$GMTSAR_APP/gmtsar_functions/create_merge_input.csh path mode > merge_list
```

这会在asc/下创建一个merge/文件夹，并且将merge过程所需要读取的文本内容打印到merge_list中。

检查merge_list，我们需要将一行包含主影像的merge信息放到第一行，这一步十分重要，确保了merge后所有图像仍能继续保持和主影像相同坐标、相同大小。

将batch.config与dem.grd同样放到merge/目录下，然后开始merge：

```terminal
cp ../batch.config .
ln -s ../topo/dem.grd .
merge_batch.csh merge_list batch.config
```

merge完成后，merge/目录下将会出现和每个子带的intf/目录下相同的干涉对文件夹，里面包含了merge后的雷达坐标系下的corr.grd、phasefilt.grd等。

这一步对应sentinel_time_series_6.pdf中的第7节。

**制作掩膜文件(optional)**

水体区域的干涉条件极差，如果我们的研究区域包含了大量水体，那么我们应该先制作掩膜文件覆盖水体区域以避免解缠错误以及资源浪费，我们可以通过多种方式制作掩膜文件。

1. 通过GMTSAR中的landmask.csh来创建掩膜文件：

   ```terminal
   # cd到merge/中的任一干涉对的目录下
   gmt grdinfo phasefilt.grd
   # 记录此时phasefilt.grd的minX/maxX/minY/maxY，作为后面landmask.csh的参数
   cd ../
   landmask.csh minX/maxX/minY/maxY
   ```

   通过这种方式可以基于GMT的海岸线数据库区分陆地与水体，生成水体的掩膜文件。

   问题在于GMT的海岸线数据库并不是up-to-date，所以针对部分地区可能不太适用。

2. 基于干涉对的相干性来创建掩膜文件：

   ```terminal
   ls */corr.grd > corr_list
   # 通过stack.csh获取一个平均的相干性结果
   stack.csh corr_list 1 corr_stack.grd std.grd
   # 选取一个合适的阈值，例如我们将相干性低于0.075的区域设置为NAN，高于0.075的区域设置为1
   gmt grdmath corr_stack.grd 0.075 GE 0 NAN = mask_def.grd
   ```

   我们需要反复调整阈值并且检查生成的mask_def.grd范围，以达到最大程度保留研究区域像素，mask掉低相干度区域的目的。

3. 通过GoogleEarth自定义制作掩膜文件：

   通过GoogleEarth圈定水体区域，在参考GMT的grdmask模块生成掩膜文件，此处不再赘述。

若是方法1生成的掩膜文件，则其名称为landmask.grd，若是按照方法2、3自行创建掩膜文件，则必须将其命名为mask_def.grd，否则解缠的脚本将无法正确调用掩膜文件。

**相位解缠**

现在我们得到了合并后多个子带（或是单个子带的）的干涉条纹图，也就是我们的缠绕相位，为了还原出形变场我们还需要进行相位解缠。

即使没有进行上一步的制作掩膜文件环节，我们同样可以通过snaphu.csh的第一个参数threshold_snaphu，基于每对干涉对的相干性，在解缠每对干涉对时先mask掉相干性低于阈值的区域，再进行解缠。

1. 如果进行了merge，那么我们需要在merge文件夹下创建一个unwrap_intf.csh：

   ```shell
   #!/bin/csh -f
   # intflist contains a list of all date1_date2 directories.
   cd $1
   # 如果需要用到上一步制作的掩膜文件，就将其链接到该目录下
   # ln -s ../landmask.grd .
   # or 
   # ln -s ../mask_def.grd .
   snaphu.csh 0.01 40
   cd ..
   ```

   将该脚本转为可执行文件，打开终端运行：

   ```terminal
   chmod +x unwrap_intf.csh
   ```

   对单个干涉对进行解缠我们只需要在终端运行：

   ```terminal
   unwrap_intf.csh date1_date2
   ```

   对所有干涉对进行并行解缠：

   ```terminal
   ls -d * > intf_list
   unwrap_parallel.csh intf_list 4
   ```

2. 如果研究区域只有一条子带，那么我们也可以继续利用GMTSAR_APP来自动处理，调整batch.config中的参数：

   ```batch.config
   startstage = 4
   endstage = 4
   
   #######################################
   # processing stage for intf_batch.csh #
   #######################################
   # 1 - start from make topo_ra (don't use, this is now done automatically before intf_batch)
   # 2 - start from make and filter interferograms
   # 3 - start from unwrap
   # 4 - start from geocode (Sentinel only)
   proc_stage = 3
   
   threshold_snaphu = 0.01
   defomax = 40
   ```

   保持startstage和endstage不变，将proc_stage调整为3，现在GMTSAR_APP将从解缠这一步开始运行。threshold_snaphu和defomax两个参数即是对应了snaphu.csh所需要的两个参数。

   设置完成后在终端运行：

   ```terminal
   ./run_gmtsar_app.csh batch.config
   ```

解缠完成后，在每个干涉对的目录下将会生成unwrap.grd。

在这里我们有一些提升解缠结果质量的tips：

- 调整threshold_snaphu，对于Sentinel-1而言，0.2~0.4是一个不错的取值范围，但是仍需要根据实际研究区域进行调整。
- 调整defomax，这是解缠时允许相位最大的跳变阈值，在同震研究中可以适当增大该阈值，但是震后以及震间研究中可以将其减小。
- 尝试将snaphu.csh替换为snaphu_interp.csh，后者会对解缠结果中数据覆盖度不够的地方进行插值，或许能获得较好的解缠效果。

**生成sbas命令**

GMTSAR中的sbas模块需要一系列输入参数，我们可以通过GMTSAR_APP中的run_sbas.csh来自动准备好这些文件。

1. 我们可以先检查一下生成的每对干涉对的解缠结果，我们需要提前安装gthumb便于批量浏览图像文件。

   ```terminal
   # 如果进行了merge，那么在asc/下运行
   gthumb merge/*/unwrap.png
   # 如果研究区域只有一个子带，那么进入这个子带的目录下
   gthumb intf/*/unwrap.png
   ```
   
   我们可以筛选掉一些解缠效果不是很理想的干涉对，将解缠结果良好的unwrap.grd列到一个list：
   
   ```terminal
   # 如果进行了merge，那么在asc/下运行
   ls merge/*/unwrap.grd > unwrap_list
   # 如果研究区域只有一个子带，那么进入这个子带的目录下
   ls intf/*/unwrap.grd > unwrap_list
   ```
   
2. 选择平滑因子与大气校正因子，通常两者设为0是一个好的开始。平滑因子会对所有像素做一个时空上的平滑，大气校正因子的设置参考Tymofyeyeva & Fialko的common-scene-stacking方法。 

   ```terminal
   # 如果进行了merge，那么在asc/下运行
   $GMTSAR_APP/gmtsar_functions/run_sbas.csh merge/supermaster.PRM unwrap_list 0 0
   # 如果研究区域只有一个子带，那么进入这个子带的目录下
   $GMTSAR_APP/gmtsar_functions/run_sbas.csh topo/master.PRM unwrap_list 0 0
   ```

   这一步将生成sbas所需要的intf.tab以及scene.tab，并且打印一行sbas指令，我们只需检查一下然后在终端输入生成的这一行指令即可开始进行sbas分析。sbas耗时长短取决于图像大小与干涉对数，一般在几小时到几天不等。

这一步对应sentinel_time_series_6.pdf中的第12节。

**恭喜！欣赏一下你的结果吧！**

