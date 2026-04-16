#!/bin/bash 

dosetup1=1 #do first part of setup
dosetup2=1 #do second part of setup (after first manual modifications)
dosetup3=1 #do second part of setup (after namelist manual modifications)
dosubmit=1 #do the submission stage! Before this step, set up to run on dedicated nodes!!
forcenewcase=1 #scurb all the old cases and start again
doanalysis=0 #analyze output (not yet coded up)
numCPUs=0 #Specify number of cpus. 0: use default


echo "setup1, setup2, setup3, submit, forcenewcase, analysis:", $dosetup1, $dosetup2, $dosetup3, $dosubmit, $forcenewcase, $doanalysis 

USER="reidur"
project='nn9188k' #nn8057k: EMERALD, nn2806k: METOS, nn9188k: CICERO, nn9560k: NorESM (INES2), nn9039k: NorESM (UiB: Climate predition unit?), nn2345k: NorESM (EU projects)
machine='betzy'

#NorESM dir
noresmrepo="NorESM_3_0_beta13a"
noresmversion="noresm3_0_beta13a"

resolution="ne16pg3_tn14" #f19_g17, ne30pg3_tn14, f45_f45_mg37
casename="n1850.$resolution.$noresmversion.Run11-1.`date +"%Y-%m-%d"`"
compset="1850_CAM70%LT%NORESM%CAMoslo_CLM60%FATES-NOCOMP_CICE_BLOM%HYB%ECO_MOSART_DGLC%NOEVOLVE_SWAV_SESP"
refcase="n1850.ne16pg3_tn14.noresm3_0_beta12a.Run10_hyb.2026-03-28" #Update here
refyear="1131" #Update here
# aka where do you want the code and scripts to live?
workpath="/cluster/work/users/$USER/" 

# some more derived path names to simplify scripts
scriptsdir=$workpath$noresmrepo/cime/scripts/

#case dir
casedir=$workpath$casename

#where are we now?
startdr=$(pwd)

#Download code and checkout externals
if [ $dosetup1 -eq 1 ] 
then
    cd $workpath

    pwd
    #go to repo, or checkout code
    if [[ -d "$noresmrepo" ]] 
    then
        cd $noresmrepo
        echo "Already have NorESM repo"
    else
        echo "Cloning NorESM"
        
        git clone https://github.com/NorESMhub/NorESM/ $noresmrepo
        cd $noresmrepo
        git checkout $noresmversion      
        #sed -i 's/ctsm5.3.045_noresm_v14/ppe-scramble-tag-for-ctsm-on-norems3-beta04/g' .gitmodules
        #echo "Updated .gitmodules to use ppe-scramble-tag-for-ctsm-on-norems3-beta04 of CLM:"
        #grep -i -n 'ppe-scramble-tag-for-ctsm-on-norems3-beta04' .gitmodules        
        ./bin/git-fleximod update  
    fi
fi

#Make case
if [[ $dosetup2 -eq 1 ]] 
then
    cd $scriptsdir

    if [[ $forcenewcase -eq 1 ]]
    then 
        if [[ -d "$workpath$casename" ]] 
        then    
        echo "$workpath$casename exists on your filesystem. Removing it!"
        rm -rf $workpath$casename
        rm -r $workpath/noresm/$casename
        rm -r $workpath/archive/$casename
        rm -r $casename
        fi
    fi
    if [[ -d "$workpath$casename" ]] 
    then    
        echo "$workpath$casename exists on your filesystem."
    else
        
        echo "making case:" $workpath$casename        
        ./create_newcase --case $workpath$casename --compset $compset --res $resolution --project $project --machine betzy --compiler intel --run-unsupported --user-mods-dir $workpath$noresmrepo/cime_config/usermods_dirs/reduced_out_devsim/                
        cd $workpath$casename

        #XML changes
        echo 'updating settings'  

        ./xmlchange NTASKS=1536,NTASKS_OCN=500,NTASKS_ICE=768,NTASKS_LND=768,ROOTPE_OCN=1536,ROOTPE_LND=768
        ./xmlchange RUN_TYPE=hybrid
        ./xmlchange RUN_STARTDATE=$refyear-01-01  
        ./xmlchange RUN_REFCASE=$refcase
        ./xmlchange RUN_REFDATE=$refyear-01-01 
        ./xmlchange GET_REFCASE=FALSE
        ./xmlchange STOP_OPTION=nyears
        ./xmlchange STOP_N=5
        ./xmlchange REST_N=5
        ./xmlchange RESUBMIT=0        
        ./xmlchange REST_OPTION=nyears
        ./xmlchange HAMOCC_SEDSPINUP=FALSE
        ./xmlchange BLOM_OUTPUT_SIZE=spinup
        ./xmlchange HAMOCC_OUTPUT_SIZE=spinup
        ./xmlchange --subgroup case.run JOB_WALLCLOCK_TIME=48:00:00
        ./xmlchange --subgroup case.st_archive JOB_WALLCLOCK_TIME=2:00:00
        ./xmlchange --subgroup case.compress JOB_WALLCLOCK_TIME=12:00:00   
        echo 'done with xmlchanges'        
        
        ./case.setup
        echo ' '       
        echo "Done with Setup. Updateing namelists in $workpath$casename/user_nl_*"    
## Changes to user_nl_* files goes here

cat <<EOF >> user_nl_cam
use_aerocom                = .false.
history_aerosol            = .false.
zmconv_c0_lnd              =  0.0075D0
zmconv_c0_ocn              =  0.0050D0
zmconv_ke                  =  5.0E-6
zmconv_ke_lnd              =  1.0E-5
clim_modal_aero_top_press  =  1.D-4
bndtvg                     = '/cluster/shared/noresm/inputdata/atm/cam/ggas/noaamisc.r8.nc'
dust_emis_method           = 'Leung_2023'
dust_emis_fact             = 6.1D0
rafsip_on                  = .true.
micro_mg_dcs               = 600.D-6
clubb_c8                   = 4.55
zmconv_tiedke_add	   = 0.7
nhtfrq = 0, -24, -6, -6, -3, -3 , -1, 1, -24
mfilt = 1, 73, 292, 292, 584, 584, 584, 240, 365
ndens = 2, 2, 2, 2, 2, 2, 2, 1, 1
fincl1 = 'SST','TAUX','TAUY','TAUBLJX','TAUBLJY','BTAUNET','PRECC','PRECL','PRECT','FREQZM','PCONVB','PCONVT','PRECCDZM','Z700','Z500','Z200','Z300','Z100','Z050','U200','U850','V200','V850','T200','T500', 'T700','T1000','OMEGA500','OMEGA850','VTHzm','WTHzm','UVzm','UWzm','Uzm','Vzm','THzm','Wzm','dUzm','dVzm','dUazm','dVazm','dUfzm','U','V','T','Q','Z3','dU','dV','dUa','dVa','dUf','EFLX','PTTEND','IETEND_DME', 'PTTEND_DME','TFIX','EFIX','EP','QFLX','MEANPTOP','MEANTTOP','MEANTAU','TCLDAREA',
'RHREFHT','TREFMXAV','TREFMNAV','ozone','O3','TROP_P','TROP_T','TROP_Z','VT100'
fincl2 = 'ABSVIS ','ACTNL:A', 'ACTREL:A', 'AOD_VIS:A', 'cb_BC:A', 'cb_DMS:A', 'cb_DUST:A', 'cb_OM:A', 'cb_SALT:A', 'cb_SO2:A', 'cb_SULFATE:A','CDNUMC:A', 'CLDICE:A', 'CLDLIQ:A', 'CLDTOT:A', 'CLOUD:A', 'CMFMC:A', 'CMFMCDZM:A', 'DAYFOC:A', 'FCTL:A', 'FLDS:A', 'FLDSC:A', 'FLNR:A', 'FLNS:A', 'FLNSC:A','FLNT:A', 'FLNTC:A', 'FLUT:A', 'FLUTC:A', 'FSDS:A', 'FSDSC:A', 'FSNR:A', 'FSNS:A', 'FSNSC:A', 'FSNTOA:A', 'FSNTOAC:A', 'ICEFRAC:A' ,'LHFLX:A', 'MASS:A', 'OMEGA:A','OMEGA500:A', 'PBLH:A', 'PDELDRY:A', 'PRECC:A', 'PRECT:A', 'PS:A', 'PSL:A', 'Q:A', 'QREFHT:A', 'QSNOW:A', 'RELHUM:A', 'RHREFHT:A', 'SHFLX:A', 'SOLIN:A', 'SOLLD:A', 'SOLSD:A','SST:A', 'T:A', 'T500:A', 'T700:A', 'T850:A', 'TAUBLJX:A', 'TAUBLJY:A', 'TAUGWX:A', 'TAUGWY:A', 'TAUX:A', 'TAUY:A', 'TGCLDIWP:A', 'TGCLDLWP:A', 'TMQ:A', 'TREFHT:A', 'TREFHTMN:M', 'TREFHTMX:X', 'TS:A', 'TSMN:M', 'TSMX:X', 'U:A', 'U10:A', 'UTGWORO:A','V:A', 'Z3:A', 'Z500:A','PRECL:A','FREQZM:A','PCONVB:A','PCONVT:A','PRECCDZM:A','Z700:A','Z200:A', 'Z300:A','Z100:A','Z050:A','U200:A','U850:A','V200:A','V850:A','T200:A','T1000:A','OMEGA850:A','VTHzm:A','WTHzm:A','UVzm:A','UWzm:A','Uzm:A','Vzm:A','THzm:A','Wzm:A','dUzm:A','dVzm:A','dUazm:A','dVazm:A','dUfzm:A','EFLX:A','TFIX:A','EFIX:A',
'TOT_CLD_VISTAU:A','PBLHMX:X','PBLHMN:M','DOD550:A','UA010:A','Z010:A','Z1000:A'
fincl3 ='CLOUD:A','PBLH:A','RHREFHT:A','PRECT:A','PRECC:A','PRECL:A','PSL:A','U10:A','TREFHT:A','OMEGA:A','UBOT:A','VBOT:A','Z1000:A','Q:A','OMEGA:A','TS:A','SST:A','ICEFRAC:A','PRECCDZM:A','PRECSH:A','PRECTMX:X','BS550AER:A'
fincl4= 'CLDICE:I','CLDLIQ:I','TOT_CLD_VISTAU:I','Q:I','QREFHT:I','Q850:I','PSL:I','U10:I','SNOWHLND:I','SNOWHICE:I','QRAIN:I','QSNOW:I', 'PS:I','PHIS:I','T:I','TREFHT:I','TS:I','T850:I','U:I','UBOT:I','V:I','VBOT:I','Z3:I','ZM_ORG:I','CMFMC:I','CMFMCDZM:I','FREQSH:I','FREQZM:I','PCONVB:I','PCONVT:I','Z700:I','Z500:I','Z200:I','Z300:I','Z100:I','Z050:I','U200:I','U850:I','V200:I','V850:I','T200:I','T500:I','T700:I','T1000:I','OMEGA500:I','OMEGA850:I','PTTEND:I','LHFLX:I','SHFLX:I','EFLX:I',
'EC550AER:I'
fincl5='PRECC:A','PRECL:A','PRECT:A','LHFLX:A','SHFLX:A','FLDS:A', 'FLDSC:A', 'FLNR:A', 'FLNS:A', 'FLNSC:A','FLNT:A', 'FLNTC:A', 'FLUT:A', 'FLUTC:A', 'FSDS:A', 'FSDSC:A', 'FSNR:A', 'FSNS:A', 'FSNSC:A', 'FSNTOA:A', 'FSNTOAC:A', 'LWCF','SWCF:A','CLDTOT:A','SOLLD:A','SOLSD:A',
'PRECSC:A','PRECSL:A'
fincl6='UBOT:I','VBOT:I','TREFHT:I','QREFHT:I','TS:I','SST:I','PS:I','ICEFRAC:I',
'U10:I'
fincl7='PS:A','TREFHT:A','MMRPM2P5_SRF:A'
EOF

cat <<EOF >> user_nl_clm
glacier_region_behavior = 'single_at_atm_topo','UNSET','virtual','virtual' 
glcmec_downscale_longwave = .false. 
precip_repartition_glc_all_rain_t = 2. 
precip_repartition_glc_all_snow_t = 0. 
snow_thermal_cond_glc_method = 'Jordan1991'
albice = 0.6,0.4
use_fates_nocomp=.true.
use_fates_fixed_biogeog=.true.
fates_stomatal_model='medlyn2011'
fates_spitfire_mode=4
use_fates_luh=.true.
use_fates_lupft=.true.
fates_harvest_mode='luhdata_area'
use_fates_potentialveg=.false.
do_transient_lakes = .false.
do_transient_urban = .false.
fates_paramfile = '/cluster/shared/noresm/inputdata/lnd/clm2/paramdata/fates_params_sci.1.88.6_api.42.0.0_14pft_nor_sci3_api1_c260123.nc'
fluh_timeseries='/cluster/shared/noresm/inputdata/LU_data_CMIP7/LUH2_states_transitions_management.timeseries_ne16_hist_steadystate_1850_2025-11-06_cdf5.nc'
flandusepftdat='/cluster/shared/noresm/inputdata/LU_data_CMIP7/fates_landuse_pft_map_to_surfdata_ne16np4_251106_cdf5.nc'
paramfile = '/cluster/shared/noresm/inputdata/lnd/clm2/paramdata/ctsm60_params.5.3.045_noresm_v14_c260117.nc'
fates_history_dimlevel = 3
hist_nhtfrq = 0, -24, -3,-8760
hist_mfilt = 12, 365, 2920,1
hist_fincl1 = 'FERT_TO_SMINN','NFIX_TO_SMINN','LITFIRE','LITR1C_TO_SOIL1C','LITR2C_TO_SOIL1C','LITR3C_TO_SOIL2C','M_LEAFC_TO_LITTER','M_FROOTC_TO_LITTER','M_LIVESTEMC_TO_LITTER','M_DEADSTEMC_TO_LITTER','M_LIVECROOTC_TO_LITTER','M_DEADCROOTC_TO_LITTER','FATES_LITTER_BG_CWD_EL', 'FATES_VEGC_PF', 'FATES_STRUCTC', 'FATES_CROWNAREA_PF'
hist_fincl2 = 'ALT','H2OCAN','H2OSFC','QVEGE','QVEGT','QSOIL','QSNOEVAP','QRUNOFF','QOVER','QDRAI','QINTR','QCHARGE','RAM1','SOILLIQ','SOILICE','SOILWATER_10CM','SNOFSRVD','SNOFSRVI','SNOFSRND','SNOFSRNI','SNOFSDSVD','SNOFSDSVI','SNOFSDSND','SNOFSDSNI','FATES_LAI','TG','TSA','TSOI','TV','TOTSOILLIQ','TOTSOILICE','TWS','VOLR','ZWT'
hist_fincl3 = 'QRUNOFF', 'SOILLIQ', 'SOILICE', 'SOILWATER_10CM', 'TSA', 'TSL', 'FATES_GPP', 'AR', 'HR', 'FATES_NPP', 'FATES_AUTORESP', 'FATES_HET_RESP', 'FATES_FIRE_CLOSS'
hist_fincl4 = 'FATES_VEGC','TOTSOMC','TOTLITC', 'FATES_NPLANT_CANOPY_SZPF', 'FATES_DDBH_CANOPY_SZPF', 'FATES_NPLANT_USTORY_SZPF', 'FATES_DDBH_USTORY_SZPF', 'FATES_MORTALITY_CANOPY_SZPF', 'FATES_MORTALITY_USTORY_SZPF', 'FATES_VEGC_SZPF', 'FATES_VEGC_LUPF', 'FATES_VEGC_APPF', 'FATES_NPLANT_SZAPPF', 'FATES_NOCOMP_PATCHAREA_LUPF'
EOF

cat <<EOF >> user_nl_cpl
ocean_albedo_scheme = 1
EOF

cat <<EOF >> user_nl_blom
EGC = 2.5
EGIDFQ = 1.25
dmsp3=0.1296
dmsp5=0.0136
dremcalc  = 0.0045
dremopal  = 0.008
rcalc     = 7.0
ropal     = 80.0
rano3denit = 0.00010
disso_poc = 3.9e-7
disso_sil = 1.0e-7
wlin=0.0154762
wmin=5.4
EOF

cat <<EOF >> user_nl_cice
drsnw_min = 1.0
floediam = 50.0
f_aero='m'
f_iage='m'
EOF
        echo "done with user_nl_* modifications"


        #more user_nl_*
    fi
fi

#Build case case
if [[ $dosetup3 -eq 1 ]] 
then
    cd $workpath$casename
    echo "Currently in" $(pwd)
    ./case.build
    echo ' '    
    echo "Done with Build"

    # copy restart files and pointers
    cp /cluster/work/users/kjetisaa/archive/$refcase/rest/$refyear-01-01-00000/*.r*.nc /cluster/work/users/reidur/noresm/$casename/run/ 
    cp /cluster/work/users/kjetisaa/archive/$refcase/rest/$refyear-01-01-00000/rpointer.*$refyear-01-01-00000 /cluster/work/users/reidur/noresm/$casename/run/ 
    cp /cluster/work/users/kjetisaa/archive/$refcase/rest/$refyear-01-01-00000/$refcase.cam.i.$refyear-01-01-00000.nc /cluster/work/users/reidur/noresm/$casename/run/ 
    echo "copied restart files and pointers"
fi

#Submit job
if [[ $dosubmit -eq 1 ]] 
then
    cd $workpath$casename
    ./case.submit
    echo " "
    echo 'done submitting'       
fi