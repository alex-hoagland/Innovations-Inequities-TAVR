/*******************************************************************************
* Title: TAVR Master
* Created by: Alex Hoagland
* Created on: October 2020
* Last modified on: March 15, 2022
* Last modified by: 
* Purpose: This file runs all necessary code project "Innovations and Inequities in Access to High-Value Medical Services"

* Notes: 

* Key edits: 
	- see "TODO"s here for things to check/organize/add
********************************************************************************/


****** Packages and directories
// be sure to cite all of these before submission
* ssc install estout // Jann, Ben (2007). Making regression tables simplified. The Stata Journal 7(2): 227-244.
* ssc install catplot // "CATPLOT: Stata module for plots of frequencies, fractions or percents of categorical data", Statistical Software Components S431505, Boston College Department of Economics, revised 21 Dec 2010. 

// Directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666"
global datadir "$mydir/2_Data/CMS_Updated202105"
global geodata "$mydir/2_Data/Geography"
global output "$mydir/ToExport/MainFigures"
global allcode "$mydir/3_SourceCode/5_CrowdOut_Decomposition"
********************************************************************************


***** Data preparation code
// TODO: Need to test this section
// TODO: may need to move in additional (earlier) files here
do "$allcode/0a_IDPhysicianTypes.do" // Identifies NPIs of all CT surgeons, IVCs, and other cardiologists
do "$allcode/0b_IDInpatientProcedures_ByPhysicianType.do" // Identifies all Inpatient Procedures involving cardiologists
do "$allcode/1_EstimatePatientRisk.do" // Estimates patient risk based on STS-PROM model 
	// TODO: can add more demographic/DXI information here
********************************************************************************


***** Summary Tables
do "$allcode/1a_PatientSummaryTable.do" // Patient Summary Tables (need to test/update)
do "$allcode/1b_ProviderSummaryTable.do" // role of CT surgeons and IVCs in TAVR/SAVR procs (Appendix)
	// note: this file works! Just don't overwrite the table unless you really mean it b/c I haven't hard-coded all the formatting (commas, %s, etc.)
********************************************************************************


***** Main Figures/Tables
do "$allcode/2_EventStudies.do" high extensive // Runs event studies for different outcomes at surgeon level --- here, run all
do "$allcode/2_EventStudies.do" high intensive
do "$allcode/2_EventStudies.do" low extensive
do "$allcode/2_EventStudies.do" low intensive
do "$allcode/2_EventStudies.do" all extensive
do "$allcode/2_EventStudies.do" all intensive

do "$allcode/2a_EventStudies_MarketLevel.do" high extensive // Runs event studies for different outcomes at CZ level --- here, run all
do "$allcode/2a_EventStudies_MarketLevel.do" high intensive
do "$allcode/2a_EventStudies_MarketLevel.do" low extensive
do "$allcode/2a_EventStudies_MarketLevel.do" low intensive
do "$allcode/2a_EventStudies_MarketLevel.do" all extensive
do "$allcode/2a_EventStudies_MarketLevel.do" all intensive

*** Decompose heterogeneity in effect for high-risk patients (on PCI use)
forvalues i = 4/10 { // Loop through values of thetabar (lower bound for patient risk)
	local j = `i'/100
	di "LOWER BOUND IS `j'"
	do "$allcode/3a_LowIntensity_Decomposition_Threshold.do" `j' // thetabar is the definition of the cutoff region 
}
do "$allcode/3b_LowIntensity_Decomposition_Bins.do" 1 // For all interventions
do "$allcode/3b_LowIntensity_Decomposition_Bins.do" 0 // For PCI only
do "$allcode/3c_LowIntensity_Decomposition_Nonparametric.do" 1 // For all interventions
do "$allcode/3c_LowIntensity_Decomposition_Nonparametric.do" 0 // For PCI Only

*** Now look at inequities
do "$allcode/4_Inequities_Income.do" income all .05 .1 // income/race, all/PCI, then the crowd-out region (two thresholds)
// TODO: add TAVR adoption over income distribution, effect of TAVR on PCI over income, effect of TAVR on all over income 
// TODO: *then* focus on the crowdout region(s) -- look more into very low-risk patients getting ignored? 
********************************************************************************


***** Other Appendix Figures/Tables
********************************************************************************
