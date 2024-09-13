/*******************************************************************************
* Title: Flag all inpatient NSTEMIs
* Created by: Alex Hoagland
* Created on: 6/28/2023
* Last modified on: 
* Last modified by: 
* Purpose: Identifies all inpatient NSTEMIs in the population (will eventually link to angioplasties and TAVR adoption at CZ level)

* Notes: 

* Key edits: 
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202101"
global geodata "$mydir/2_Data/Geography"
********************************************************************************


***** 0. Map rates to CZ-quarter level
use "$mydir/linked_nstemi_angiograms.dta", clear 
 
*** First, go from SSA state/county to FIPS
//preserve
//import delimited "$geodata/SSA_FIPS_cw.csv", clear
//tostring ssacd, format("%05.0f") replace
//tostring fipsc, format("%05.0f") replace
//save "$geodata/SSA_FIPS", replace
//restore

//gen ssacd = state_cd + cnty_cd
//merge m:1 ssacd using "$geodata/SSA_FIPS", keep(1 3) keepusing(fipsc) nogenerate

*** Now go from FIPS to CZ
//rename fipsc FIPS
//merge m:1 FIPS using "$geodata/CZs_Crosswalk", keep(1 3) keepusing(CommutingZoneID2000) nogenerate
//rename Commuting CZID
// drop if missing(CZID)

// gen quarter = qofd(from_dt) 

// compress
// save "$mydir/linked_nstemi_angiograms.dta", replace
********************************************************************************


***** 1. Now collapse to outcomes
gen nstemi = 1
gcollapse (mean) ang* (sum) nstemi, by(CZID quarter) fast
replace ang = ang * 100 // change to percent
compress
save "$mydir/nstemi_angiograms_outcomes.dta", replace

sum ang, d
*********************************************************************************
