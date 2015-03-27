#ifndef _HELPERS_
#define _HELPERS_


#include<stdio.h>
#include<iostream>
#include<math.h>
#include<stdlib.h>
#include<string.h>
#include "functions.h"
using namespace std;

static const double ke=332.0637157615209;//converter between electron units and Stillinger units for Charge*Charge.

static const double Hartree = 627.50961 ; // 1 Hartree in kcal/mol.
static const double Kb  = 0.001987 ; // Boltzmann constant in kcal/mol-K.
static const double Tfs = 48.888 ;   // Internal time unit in fs.
static const double GPa = 6.9479 ;

enum Sr_pair_t {
  CHEBYSHEV,
  SPLINE,
  INVERSE_R,
  LJ,
  STILLINGER
} ;


void ZCalc(double **Coord, string *Lb, double *Q, double *Latcons,const int nlayers,
	   const int nat,const double smin,const double smax,
	   const double sdelta,const int snum, 
	   double *params, double *pot_params, Sr_pair_t pair_type,
	   bool if_coulomb,bool if_overcoord,
	   double **SForce,double& Vtot,double& Pxyz) ;


void ZCalc_Deriv(double **Coord,string *Lb, 
		 double *Latcons,const int nlayers,
		 const int nat,double ***A,const double smin,const double smax,
		 const double sdelta,const int snum, double **coul_oo,
		 double **coul_oh,double **coul_hh,Sr_pair_t pair_type) ;

void SubtractCoordForces(double **Coord,double **Force,string *Lb, double *Latcons,
			 const int nlayers, const int nat, bool calc_deriv, 
			 double **Fderiv) ;

void ZCalc_Ewald(double **Coord, string *Lb, double *Q, double *Latcons,const int nlayers,
		 const int nat,const double smin,const double smax,
		 const double sdelta,const int snum, 
		 double *params,double **SForce,double& Vtot,double& Pxyz) ;
void ZCalc_Ewald_Orig(double **Coord,string *Lb, double *Latcons,
		      const int nat,double **SForce,double& Vtot,double& Pxyz) ;

double bondedpot(double **Coord_bonded,double ***I_bonded);
double spline_pot(double smin, double smax, double sdelta, double rlen2, double *params, double *pot_params, int snum, int vstart, double &S_r) ;

bool parse_tf(char *val, int bufsz, char *line) ;
#endif

