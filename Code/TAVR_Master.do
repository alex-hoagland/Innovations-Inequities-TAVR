/*******************************************************************************
* Title: TAVR Master
* Created by: Alex Hoagland
* Created on: October 2020
* Last modified on: January 2023
* Last modified by: 
* Purpose: This file runs all necessary code project "Innovations and Inequities in Access to High-Value Medical Services"

* Notes: 

* Key edits: 

* Key datasets: 
		- "$datadir/AllPatients_BeneIDs.dta" has list of all cardiology enrollees
		- "$datadir/all_IVcardiologists.dta" has list of all IVCs (there are corresponding data sets for CT surgeons + other cardiologists)
		- "$datadir/all_InpatientCardiology.dta" has list of all relevant inpatient procedures for these beneficiaries + surgeons
********************************************************************************/


***** Labels needed
label define mygroups 1 "IVC" 2 "CT" 3 "Other"
********************************************************************************


****** Packages and directories
// be sure to cite all of these before submission
* ssc install texdoc // Jann 2009.
* ssc install fre // Jann 2007
* ssc install semipar // Verardi 2012
* ssc install reghdfe // Correia 2017
* ssc install ppmlhdfe // Correia 2020

// Directories
// global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666"
global mydir // "C:\Users\alexh\Dropbox\TAVR"
global datadir // "$mydir/Backup_Aging/Data/CMS_Updated2023"
// global geodata "$mydir/2_Data/Geography" // used only for constructing maps, not in main publication
global output // "$mydir/Outputs/Debugging_2023"
global allcode // "$mydir/SourceCode_Main"
********************************************************************************


***** Data preparation *********************************************************
// Physician-Level Identifiers
do "$allcode/0a_IDPhysicianTypes.do" // Identifies NPIs of all CT surgeons, IVCs, and other cardiologists -- CHECKED 2023.02.01
do "$allcode/0b_IDInpatientProcedures_ByPhysicianType.do" // Identifies all Inpatient Procedures involving cardiologists -- CHECKED 2023.02.01
do "$allcode/0c_IDASPatients.do" // This pulls all surgical candidates based on diagnosis codes -- CHECKED 2023.02.01
do "$allcode/0d_SurgicalOutcomes.do" // Pulls all surgical outcomes associated with TAVR/SAVR/PTCA procedures -- CHECKED 2023.02.07
	
// Estimate Patient Risk (Section 4.1; Appendix Figure 3, Appendix Table 3)
do "$allcode/1_EstimatePatientRisk.do" // Constructs relevant risk variables -- CHECKED 2023.02.07
do "$allcode/1a_RiskRegressions.do" // Estimates patient risk based on STS-PROM model -- CHECKED 2023.02.08

// Summary Tables
do "$allcode/1b_PatientSummaryTable.do" // Appendix Table 2: Patient Summary Tables -- CHECKED 2023.02.09
do "$allcode/1c_ProviderSummaryTable.do" // Appendix Table 1, Appendix Figure 2 -- CHECKED 2023.02.09
	// role of CT surgeons and IVCs in TAVR/SAVR procs (Appendix)
	// note: this file works! Just don't overwrite the table unless you really mean it b/c I haven't hard-coded all the formatting (commas, %s, etc.)
	
// Construct Panels for Event Studies
	// TODO: market-level for surgeons, also want one that shows pr(surgery) from those in inpatient + outpatient with appropriate diagnoses (?) 
********************************************************************************


***** Main Figures/Tables
// FIGURE 3 (plus accompanying appendix/extras)
	// total surgeries (Figure 3, panel a)
	do "$allcode/2a_EventStudies_MarketLevel.do" all extensive 
	do "$allcode/2a_EventStudies_MarketLevel.do" high extensive 
	do "$allcode/2a_EventStudies_MarketLevel.do" low extensive 

	// Extra figures
	do "$allcode/2a_EventStudies_MarketLevel.do" all intensive predrisk_30
	do "$allcode/2a_EventStudies_MarketLevel.do" all intensive predrisk_60
	do "$allcode/2a_EventStudies_MarketLevel.do" all intensive predrisk_90
	do "$allcode/2a_EventStudies_MarketLevel.do" high intensive predrisk_30
	do "$allcode/2a_EventStudies_MarketLevel.do" high intensive predrisk_60
	do "$allcode/2a_EventStudies_MarketLevel.do" high intensive predrisk_90
	do "$allcode/2a_EventStudies_MarketLevel.do" low intensive predrisk_30
	do "$allcode/2a_EventStudies_MarketLevel.do" low intensive predrisk_60
	do "$allcode/2a_EventStudies_MarketLevel.do" low intensive predrisk_90
	do "$allcode/2b_IntensiveMargin_CombineGraphs.do" all
	do "$allcode/2b_IntensiveMargin_CombineGraphs.do" high // note: lots of noise here
	do "$allcode/2b_IntensiveMargin_CombineGraphs.do" low // TODO: rerun these without dropping any?
	
	// likelihood of surgery by risk (binned)  (Figure 3, panel B)
	local allfiles: dir "$datadir/" files "binned_*"
	foreach f of local allfiles { 
		cap rm `f'
	}
	forvalues i = 0/60 { 
		local rlb = .002*`i'
		local ulb = `rlb' + .002
		di "***** RUNNING REGRESSION `rlb' *****"
		qui do "$allcode/2c_EventStudies_MarketLevel_BinnedRisk.do" all `rlb' `ulb'
	}
	do "$allcode/2c_EventStudies_MarketLevel_BinnedRisk.do" all "all"
	forvalues i = 0/60 { 
		local rlb = .002*`i'
		local ulb = `rlb' + .002
		di "***** RUNNING REGRESSION `rlb' *****"
		qui do "$allcode/2c_EventStudies_MarketLevel_BinnedRisk.do" high `rlb' `ulb'
	}
	do "$allcode/2c_EventStudies_MarketLevel_BinnedRisk.do" high "all"
	forvalues i = 0/60 { 
		local rlb = .002*`i'
		local ulb = `rlb' + .002
		di "***** RUNNING REGRESSION `rlb' *****"
		qui do "$allcode/2c_EventStudies_MarketLevel_BinnedRisk.do" low `rlb' `ulb'
	}
	do "$allcode/2c_EventStudies_MarketLevel_BinnedRisk.do" low "all"
		
	// Extra Option: Saturated by risk
// 	do "$allcode/2Extra_1_EventStudies_MarketLevel_Saturated.do" all	
// 	do "$allcode/2Extra_2_EventStudies_MarketLevel_Semiparametric.do" all 

	// Unused options: individual level codes
	// do "$allcode/2Extra_3_EventStudies_AllSurgicalCandidates.do" all .3
	// do "$allcode/2Extra_4_EventStudies_AllSurgicalCandidates_SaturatedRisk.do" all 1
	// do "$allcode/2Extra_5_EventStudies_AllSurgicalCandidates_SemiparametricRisk.do" all 0.3

		// MECHANISMS: readmissions and mortality
	do "$allcode/3a_Mechanisms_SurgicalOutcomes.do" low readmit 
	do "$allcode/3a_Mechanisms_SurgicalOutcomes.do" low mortality 
	
	do "$allcode/3a_Mechanisms_SurgicalOutcomes.do" high readmit 
	do "$allcode/3a_Mechanisms_SurgicalOutcomes.do" all readmit 
	do "$allcode/3a_Mechanisms_SurgicalOutcomes.do" high mortality 
	do "$allcode/3a_Mechanisms_SurgicalOutcomes.do" all mortality 
	
	// INEQUITIES: Market level 
	do "$allcode/4a_Inequities_Binned.do" low riskvar_white
	do "$allcode/4a_Inequities_Binned.do" low riskvar_dual_any
	do "$allcode/4a_Inequities_Binned.do" low riskvar_dual_full
	do "$allcode/4a_Inequities_Binned.do" low riskvar_adi_5
	do "$allcode/4a_Inequities_Binned.do" low riskvar_adi_9
	do "$allcode/4b_Inequities_Binned_Combine.do" low
	
	do "$allcode/4a_Inequities_Binned.do" high riskvar_white
	do "$allcode/4a_Inequities_Binned.do" high riskvar_dual_any
	do "$allcode/4a_Inequities_Binned.do" high riskvar_dual_full
	do "$allcode/4a_Inequities_Binned.do" high riskvar_adi_5
	do "$allcode/4a_Inequities_Binned.do" high riskvar_adi_9
	do "$allcode/4b_Inequities_Binned_Combine.do" high
	
	do "$allcode/4a_Inequities_Binned.do" all riskvar_white
	do "$allcode/4a_Inequities_Binned.do" all riskvar_dual_any
	do "$allcode/4a_Inequities_Binned.do" all riskvar_dual_full
	do "$allcode/4a_Inequities_Binned.do" all riskvar_adi_5
	do "$allcode/4a_Inequities_Binned.do" all riskvar_adi_9
	do "$allcode/4b_Inequities_Binned_Combine.do" all
	
	do "$allcode/Appendix_TAVRScreening.do" 
********************************************************************************
