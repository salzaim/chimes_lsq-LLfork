#ifndef _A_MATRIX_H
#define _A_MATRIX_H

#include <vector>

using namespace std;

#include "util.h"

struct STENSOR
{
	double XX;
	double YY;
	double ZZ;
	double XY;
	double XZ;
	double YZ;
};

class A_MAT
{
	public:
	
	int 				NO_ATOM_TYPES;	 // How many atom types are in the frame
	vector<string> 			ATOM_TYPES;	 // What are their chemical symbols
	vector<int>    			NO_ATOMS_OF_TYPE;// How many atoms of each type are there?
	
	vector<vector<vector<XYZ> > >	FORCES; 	// originally "A_MATRIX"       ... [#frames][#atoms][#fittingparameters]
	vector<vector<STENSOR> >	STRESSES;	// new; stresses       ... originally tacked on to "A_MATRIX" ... [#frames][#fittingparameters]
	vector<vector<double> >		FRAME_ENERGIES;	// new; frame energies ... originally tacked on to "A_MATRIX" ... [#frames][#fittingparameters]
	vector<vector<vector<double> > >ATOM_ENERGIES;	// new; per-atom energies      ... [#frames][#atoms] [#fittingparameters]
	
	// Depreciated for now (on the "to-do" list): 
	
	vector<vector<XYZ > >		OVERBONDING;	// originally "P_OVER_FORCES"  ... [#frames][#atoms]
	vector<vector<vector<XYZ> > >	CHARGES;	// originally "COULOMB_FORCES" ... [#frames][#pairtypes][#atoms]
					
	
	
	A_MAT(int NFRAMES);
	~A_MAT();
	
	void INITIALIZE_NATOMS  (           int ATOMS, vector<string> & FRAME_ATOMTYPES);
	void INITIALIZE_FORCES  (int FRAME, int ATOMS, int PARAMS);
	void INITIALIZE_ENERGIES(int FRAME, int ATOMS, int PARAMS, bool FRAME_ENER, bool ATOM_ENER);
	void INITIALIZE_STRESSES(int FRAME, int PARAMS, bool DIAG_STRESS, bool ALL_STRESS);
	void INITIALIZE_OVERBOND(int FRAME, int ATOMS);
	void INITIALIZE_CHARGES (int FRAME, int FF_PAIRS,int ATOMS);
	void PRINT_ALL(const struct JOB_CONTROL &CONTROLS,
								 const vector<class FRAME> &TRAJECTORY,
								 const vector<class PAIRS> & ATOM_PAIRS,
								 const vector<struct CHARGE_CONSTRAINT> & CHARGE_CONSTRAINTS,
								 int istart, int iend) ;
	void PRINT_FRAME(const struct JOB_CONTROL &CONTROLS,
									 const class FRAME &SYSTEM,
									 const vector<class PAIRS> & ATOM_PAIRS,
									 const vector<struct CHARGE_CONSTRAINT> & CHARGE_CONSTRAINTS,
									 int N, ofstream &fileA, ofstream &fileb, ofstream &fileb_labeled) ;
	void PRINT_CONSTRAINTS(const struct JOB_CONTROL &CONTROLS,
												 const vector<struct CHARGE_CONSTRAINT> & CHARGE_CONSTRAINTS,
												 ofstream &fileA, ofstream &fileb, ofstream &fileb_labeled,
												 int NPAIRS) ;
	void CLEANUP_FILES(ofstream &fileA, ofstream &fileb, ofstream &fileb_labeled) ;
	void OPEN_FILES(ofstream &fileA, ofstream &fileb, ofstream &fileb_labeled) ;
	void INITIALIZE(JOB_CONTROL &CONTROLS, FRAME& SYSTEM, int NPAIRS, int f) ;
	
	private:
	
	int MY_ID;		// In parallel runs, each proc will have its own A-mat. This is the proc's ID
	int MY_SIZE;	// Number of frames for A-mat
	void add_col_of_ones(string item, bool DO_ENER, ofstream & OUTFILE) ;
};


#endif
	
	
	
	
	
	
	
