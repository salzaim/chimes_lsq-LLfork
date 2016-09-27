# Goal: Treat as a black box. Feed a DFT MD .xyzf file, get out a force field
#
# Useage: Make sure the following files are in the running directory
#
# 1. input_full-0.xyzf
# 2. fm_setup-0.in
# 3. run_md-0.in		-- Make sure # SLFCNST # is set true in top section of file
# 4. INCAR 			-- Be careful -- number of procs used should be divisible by NCORE
# 5. POTCAR
# 6. KPOINTS
#
# ...And set the variables 
#
#
# WARNING: This script DOES automatically delete temporary files generated by the script... watch our for file naming

 
##############################################################################################################################
############################################ 			 	######################################################
############################################ 	GENERAL  CONTROLS 	######################################################
############################################ 			 	######################################################
##############################################################################################################################

N_SCS=5 		# Number of self consistent steps (SCS) to be taken 
ATOMS=256		# Number of atoms in the input_full-1.xyz file
ORIG_FRAMES=59		# Number of frames in the original .xyzf trajectory file

HOUSE_PATH="/g/g17/rlindsey/SELF_CONSIST_TEST/"
VASP_PATH="/usr/gapps/emc-vasp/vasp.5.3/src/"
VASP_EXEC="vasp"

VASP_NODES=12
VASP_PROCS=144

##############################################################################################################################
############################################ 			 	######################################################
############################################ 	ADVANCED  CONTROLS 	######################################################
############################################ 			 	######################################################
##############################################################################################################################

NDFT_KEEP=15	# Number of frames of the original xyzf trajectory file to keep
N1MM_KEEP=5	# Number of frames from the first MM MD xyzf trajectory to keep -- should be equal to the number of frames you can print accoring to md input file (i.e. steps/frqdftb)
MAX_2_ADD=10	# Maximum number of frames to add during self consistent runs
ADD_INTRV=2	# Add "interval" ... how many frames from the current iteration should overwrite those in the current add set

# ASSUMES NEVER MORE THAN 100 FRAMES ARE PRESENT FROM ORIGINAL DFT TRAJECTORY











##############################################################################################################################
############################################ 			 	######################################################
############################################ 	BEGIN	DRIVER 		######################################################
############################################ 			 	######################################################
##############################################################################################################################

##########################################
# Prepare for the eventual reconstruction of the force trajectory file:
# ##########################################

# 1. Break the original trajectory file into individual frames 

echo "Breaking up original trajectory into indvidual frames..."

python ${HOUSE_PATH}/contrib/subtract_forces/break_apart_xyz.py $ORIG_FRAMES input_full-0.xyzf

# 2. Catenate together roughly evenly spaced files

echo "Catenating together roughly evenly spaced files..."

INTERVAL=$[ $ORIG_FRAMES / $NDFT_KEEP ]		# Take every INTERVAL-th file

rm -f orig_dft_chunk.xyzf				# Name for the .xyzf containing selected files

FILE_NO=$INTERVAL							# Index for selected file

CHAR_MAX=${#ORIG_FRAMES}					# How many characters are in this integer

for i in $(seq 1 $NDFT_KEEP)
do
	# Take care of zeroes
	
	CHAR_CUR=${#FILE_NO}
	ZEROS=""
	
	for j in $(seq 1 $[ 1 + $CHAR_MAX - $CHAR_CUR ])
	do
		ZEROS="${ZEROS}0"
	done
		
	cat input_full-0_\#${ZEROS}${FILE_NO}.xyzf >> orig_dft_chunk.xyzf # The "#" here is not a comment! It's part of the string!
	
	FILE_NO=$[ $INTERVAL * $i + $INTERVAL ]

done

#rm -f input_full-0_#*.xyzf

# Setup files for the first iteration

echo "Setting up files for the first iteration..."

tail -n $[ $ATOMS + 2 ] input_full-0.xyzf > input-0.xyzf


# Start the loop

echo "BEGIN SELF CONSTISTENT LOOP"

for SCS in $(seq 1 $N_SCS)
do
	echo " SCS - $SCS"
	
	##########################################
	# Update necessary files and run the C++ and Python LSQ processes
	##########################################
	
	echo "	Updating necessary files..." 

	awk -v step="input_full-$[ $SCS - 1 ].xyzf" '/# TRJFILE #/{print; getline; sub($1, step)}{print}' fm_setup-$[ $SCS - 1 ].in > fm_setup-${SCS}.in
	
	if [ $SCS -eq 1 ]; then
		cp fm_setup-${SCS}.in tmp
		awk -v step="${NDFT_KEEP}" '/# NFRAMES #/{print; getline; sub($1, step)}{print}' tmp > fm_setup-${SCS}.in
	else
		cp fm_setup-${SCS}.in tmp
		FRAMES=`cat input_full-$[ $SCS - 1 ].xyzf | wc -l `
		LINES=$[ $ATOMS + 2 ]
		FRAMES=$[ $FRAMES / $ATOMS ]
		awk -v step="${FRAMES}" '/# NFRAMES #/{print; getline; sub($1, step)}{print}' tmp > fm_setup-${SCS}.in
	fi
	
	echo "	Running LSQ C++..."
	
	${HOUSE_PATH}/src/house_lsq < fm_setup-${SCS}.in > fm_setup-${SCS}.out
	
	echo "	Running LSQ Python..."
	
	${HOUSE_PATH}/src/lsq-new-md-fmt.py A.txt b.txt params.header ff_groups.map > tmp
	
	awk '/ATOM PAIR TRIPLETS:/{print ("PAIR CHEBYSHEV PENALTY DIST: 0.15\nPAIR CHEBYSHEV PENALTY SCALING: 1E7\n")}{print}' tmp > params-${SCS}.txt

	# =================================================================== VERIFIED ABOVE - !
	
	##########################################
	# Update necessary files and run the MD job... 4000 MD Steps * 0.125 fs/step = 500 fs = 0.5 ps
	# Note, as long as SLFCNST is set true, MD will produce a POSCAR file.
	##########################################
	
	echo "	Updating files for MD run..."
	
	cp run_md-$[ $SCS - 1 ].in run_md-${SCS}.in
	
	awk '/# TIMESTP #/{print; getline; sub($1, "0.125" )}{print}' run_md-$[ $SCS - 1 ].in > run_md-${SCS}.in; cp run_md-${SCS}.in tmp
	awk '/# N_MDSTP #/{print; getline; sub($1, "4000"  )}{print}' tmp > run_md-${SCS}.in; cp run_md-${SCS}.in tmp
	awk '/# CMPRFRC #/{print;getline; print; print("# SLFCNST #\n\t true 800");getline}{print}' tmp > run_md-${SCS}.in; cp run_md-${SCS}.in tmp
	
	if [ $SCS -gt 1 ]; then
		awk '/# VELINIT #/{print; getline; sub($1, "READ" )}{print}' tmp > run_md-${SCS}.in; cp run_md-${SCS}.in tmp
	else
		awk '/# VELINIT #/{print; getline; sub($1, "GEN" )}{print}' tmp > run_md-${SCS}.in; cp run_md-${SCS}.in tmp
	fi
	
	awk -v val="input-$[  $SCS - 1 ].xyzf" '/# CRDFILE #/{print; getline; sub($1, val)}{print}' tmp > run_md-${SCS}.in; cp run_md-${SCS}.in tmp
	awk -v val="params-${SCS}.txt"         '/# PRMFILE #/{print; getline; sub($1, val)}{print}' tmp > run_md-${SCS}.in; cp run_md-${SCS}.in tmp
	
	awk '/# FRQDFTB #/{print; getline; sub($1, "800" )}{print}' tmp > run_md-${SCS}.in; cp run_md-${SCS}.in tmp
	awk '/# FRQENER #/{print; getline; sub($1, "800" )}{print}' tmp > run_md-${SCS}.in; cp run_md-${SCS}.in tmp
	
	echo "	Launching MD run..."	
	
	${HOUSE_PATH}/src/house_md < run_md-${SCS}.in > run_md-${SCS}.out

	echo "	Setting up post-MD run files..."
	
	mv output.xyz input-${SCS}.xyzf
	mv traj.gen traj-${SCS}.gen
	
	for i in `ls POSCAR_[0-9].mm_md`
	do	
		mv $i ${i%.*}-${SCS}.mm_md
	done
	
	mv POSCAR_MAPPER.mm_md POSCAR_MAPPER-${SCS}.mm_md
	

	# ===================================================================		
	
	##########################################
	# Run VASP for the generated POSCAR file and convert the OUTCAR file 
	# to an xyzf file with atoms in the same order as the original xyzf
	##########################################
	
	echo "	Setting up files for VASP calculations..."
	
	LIST=""
	
	if [ $SCS -eq 1 ] ; then					# If this is the first time, run the VASP calc for $N1MM_KEEP frames
		LIST=$(seq 1 $N1MM_KEEP)
		echo "" > orig_1mm_chunk.xyzf
		echo "" > recy_scs_chunk.xyzf		
	else
		if [ $ADD_INTRV -eq 2 ]; then
			LIST="1 5"
		else
			LIST=$(seq 1 $ADD_INTRV 5)
		fi
	fi

	for i in `echo $LIST`
	do
		echo "	VASP LOOP: $i"
		
		cp POSCAR_${i}-${SCS}.mm_md POSCAR
	
		srun -N $VASP_NODES -n $VASP_PROCS ${VASP_PATH}/${VASP_EXEC} | tee vasp_run_${i}-${SCS}.out & 
		VASP_PID=$!
		wait $VASP_PID 	# Make sure job finished before moving on
		sleep 10	# Allow time for any leftover i/o to finish
		
		SANITY=`ps -aux | grep rlindsey | grep vasp | wc -l`
		
		if [ $SANITY -gt 1 ] ; then # Vasp is still running
			echo "		WARNING: VASP PROCESS FOUND STILL RUNNING!"
			
			while [ $SANITY -gt 1 ] ; do
				echo "		.. Waiting for 1 more minute..."
				sleep 60
				SANITY=`ps -aux | grep rlindsey | grep vasp | wc -l`
			done
		fi

		echo "		Calculation finished. Updating files..."	

		cp OUTCAR OUTCAR_${i}-${SCS}
		
		SANITY=`diff OUTCAR OUTCAR_${i}-${SCS} | wc -l`	
		
		if [ $SANITY -gt 0 ] ; then # Somehow the outcar files got corrupted
			echo "ERROR-1: See driver script."
			exit 0
		fi
		
		python ${HOUSE_PATH}/contrib/self_consist/outcar_to_xyzf.py OUTCAR_${i}-${SCS} POSCAR_MAPPER-${SCS}.mm_md 
		
		mv output_vasp.xyzf output_vasp_${i}-${SCS}.xyzf
		
		if [ $SCS -eq 1 ] ; then
			echo "		---> Printing to file orig_1mm_chunk.xyzf" 
			cat output_vasp_${i}-${SCS}.xyzf >> orig_1mm_chunk.xyzf
			wc -l orig_1mm_chunk.xyzf
		elif [ $[ $MAX_2_ADD - $ADD_INTRV * $SCS ] -ge 0 ] ; then
			echo "		---> Printing to file recy_scs_chunk.xyzf" 
			cat output_vasp_${i}-${SCS}.xyzf >> recy_scs_chunk.xyzf
			wc -l recy_scs_chunk.xyzf
		else
			echo "		---> Printing to file recy_scs_chunk.xyzf" 
			KEEP=$[ $ATOMS + 2 ]
			tail -n $[ $MAX_2_ADD * $KEEP ] recy_scs_chunk.xyzf > tmp; mv tmp recy_scs_chunk.xyzf
			cat output_vasp_${i}-${SCS}.xyzf >> recy_scs_chunk.xyzf
			wc -l recy_scs_chunk.xyzf
		fi
		
		cat orig_dft_chunk.xyzf  > input_full-${SCS}.xyzf
		cat orig_1mm_chunk.xyzf >> input_full-${SCS}.xyzf
		cat recy_scs_chunk.xyzf >> input_full-${SCS}.xyzf
		
		echo "		File updates complete"
		
	done
	
	# Clean up 
	
	echo "	SCS loop complete - $SCS "
	
	rm -f IBZKPT PCDAT OSZICAR XDATCAR CONTCAR CHG WAVECAR CHGCAR EIGENVAL vasprun.xml DOSCAR OUTCAR tmp
	
done


##########################################
# Do one last lsq/python calc to get ~final~ parameters 
##########################################

echo "	Updating necessary files..." 

# Just to make life easier, reset N_SCS to += 1

N_SCS=$[ $N_SCS + 1 ]

awk -v step="input_full-$[ $N_SCS - 1 ].xyzf" '/# TRJFILE #/{print; getline; sub($1, step)}{print}' fm_setup-$[ $N_SCS - 1 ].in > fm_setup-final.in

cp fm_setup-final.in tmp
FRAMES=`cat input_full-$[ $N_SCS - 1 ].xyzf | wc -l `
LINES=$[ $ATOMS + 2 ]
FRAMES=$[ $FRAMES / $ATOMS ]
awk -v step="${FRAMES}" '/# NFRAMES #/{print; getline; sub($1, step)}{print}' tmp > fm_setup-final.in


echo "	Running LSQ C++..."

${HOUSE_PATH}/src/house_lsq < fm_setup-final.in > fm_setup-final.out

echo "	Running LSQ Python..."

${HOUSE_PATH}/src/lsq-new-md-fmt.py A.txt b.txt params.header ff_groups.map > tmp

awk '/ATOM PAIR TRIPLETS:/{print ("PAIR CHEBYSHEV PENALTY DIST: 0.15\nPAIR CHEBYSHEV PENALTY SCALING: 1E7\n")}{print}' tmp > params-final.txt
	

# All done!

echo "SCS RUN COMPLETE"	
	

