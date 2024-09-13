/*******************************************************************************
* Title: Master file for the replication of "Innovations and Inequities in Access to Medical Services" 
* Created by: Alex Hoagland (alexander.hoagland@utoronto.ca)
* Created on: October 2020
* Last modified on: August 2024
* Last modified by: 
* Purpose: This file runs all necessary code for the project, including analytic data file creation, analysis, and output generation

* Notes: 

* Datasets required for use: the following key datasets are required for use (in addition to Medicare claims) and either provided with the replication package or 
	constructed directly from the Medicare claims data (using the NBER versions). Ancillary data sets may be created in later files as needed, but these are self-contained:
	
	- Geography datasets: SSA_FIPS.dta, CZs_Crosswalk.dta, ADI_allstates.dta and ADI_9digits.dta, fips_income.dta, czpop_20.dta
	- Useful datasets: 20p_flag.dta (just to indicate which beneficiaries are in the 20% sample) 
	- Core cardiology claims/physicians: all_IVCardiologists.dta, all_InpatientCardiology.dta, all_OutpatientCardiology.dta, all_SurgicalCandidates.dta
	- From there, we construct market-level and patient-level data: IVC_EventStudy_Base.dta, ASpatients2024_20p_collapsed_withoutpatient.dta (maybe others?)
	
* Questions to address: 
	- TODO: iron out the ADI scores and make the tweaks only once (so that increasing values means more disadvantage)
		- update to be with 2022 ADI using FIPS and ensure you are counting correctly: https://www.neighborhoodatlas.medicine.wisc.edu/#pdfs-anchor
	- TODO: Table 3 needs to be updated using the 20\% subsample before submission
********************************************************************************/


**** Protect you against running this whole thing by accident 
DO YOU REALLY WANT TO RUN THE WHOLE THING? COMMENT THIS OUT IF SO. // I know this is a low-tech way of doing things
********************************************************************************

****** Packages and directories
* Packages needed for this to run: lpdid, texdoc, semipar, schemepack, gtools, catplot, estout, hopefully not too many others missed here? 

// Directories
macro drop _all
global mydir "C:/Users/alexh/Dropbox/TAVR_Leapfrogging"
global datadir "$mydir/2_Data/CMS_Updated202105"
global geodata "$mydir/2_Data/Geography"
global allcode "$mydir/3_SourceCode/"
global output "$mydir/ToExport/MainFigures"
global output_a "$mydir/ToExport/AppendixFigures"

set scheme cblind1

global today : di %td_CYND date("$S_DATE", "DMY")
global today $today 
	// global for today's date; second command removes leading spaces
	
clear all
set more off
cd "$mydir"
********************************************************************************


***** Data preparation code
do "$allcode/0a_IDPhysicianTypes.do" // Identifies NPIs of all CT surgeons, IVCs, and other cardiologists
	// this constructs the "all_IVCardiologists.dta" file (among others)
do "$allcode/0b_IDInpatientProcedures_ByPhysicianType.do" // Identifies all Inpatient Procedures involving cardiologists 
	// this constructs the "all_InpatientCardiology.dta" file 
do "$allcode/0c_IDOutpatientProcedures_ByPhysicianType.do" // Identifies all Outpatient Procedures involving cardiologists
	// this constructs the "all_OutpatientCardiology.dta" file 
do "$allcode/0d_CZLevelData.do" // Market Level Data
	// this constructs the "IVCEventStudy_Base.dta" file
do "$allcode/0e_FullPatientPopulation_20p.do" // Individual Level Data 
	// this constructs the "ASpatients2024_20p_collapsed_withoutpatient.dta" file
do "$allcode/0f_STROMRiskDenominator" // Individual Level Data for all potential cardiology surgeries
	// this constructs the "all_SurgicalCandidates.dta" file, used in estimating the STS-PROM model below
********************************************************************************


***** Main Figures and Tables (in order of presentation) 
// TABLE 1: SUMMARY STATISTICS
do "allcode/1_ProcedureSummaryTable.do" // produces .tex code

// FIGURES 1-2: LATEX ONLY (email me if you would like the .tex files)

// FIGURE 3: MAIN TAVR EFFECTS
do "$allcode/2a_EventStudies_MarketLevel.do" all extensive // panel (a): CZ level 
do "$allcode/2b_EventStudies_PatientLevel.do" all // panel (b): Patient level 

// TABLE 2: EFFECT OF TAVR'S ADOPTION ON PCI OUTCOMES
do "$allcode/3_PCIOutcomes.do"

// FIGURE 4: CATH LAB UTILIZATION
do "$allcode/4_Robustness_CathLabDemand.do" cathlab_pat	// panel a: unique # of patients
do "$allcode/4_Robustness_CathLabDemand.do" cathlab_charges // panel b: total spending

// FIGURE 5: Effects of TAVR Adoption on Total Intervention Volumes by Patient Risk
// NOTE: when done with LP-DID, add "_lpdid" to code file name and use binwidth of 0.005 -- 0.010.  
local allfiles: dir "$datadir/" files "binned_*"
foreach f of local allfiles { // this resets the temporary data files 
	cap rm "$datadir/`f'"
}
forvalues i = 0/60 { // this runs the regressions for each bin
	local rlb = .002*`i'
	local ulb = `rlb' + .002
	di "***** RUNNING REGRESSION `rlb' *****"
	qui do "$allcode/2c_EventStudies_MarketLevel_BinnedRisk.do" all `rlb' `ulb'
}
do "$allcode/2c_listpvals.do" all // run this and copy p-values for the next code
do "$allcode/2c_EventStudies_MarketLevel_BinnedRisk.do" all "all" // this makes the figure

// FIGURE 6: Inequities in TAVR’s Effects on Local Access to Interventions: CZ Level
do "$allcode/5_MarketInequities_Binned.do" all riskvar_white 5 // panel a (nonwhite) 
do "$allcode/5_MarketInequities_Binned.do" all riskvar_adi_9 5 // panel b (ADI)

// TABLE 3: Within-Market Inequities: Pooled LP-DID Estimates
// run all of these to store the globals 
do "$allcode/5a_Inequities_Patient20p.do" 0 // overall
do "$allcode/5a_Inequities_Patient20p.do" 1 // Male
do "$allcode/5a_Inequities_Patient20p.do" 2 // Female
do "$allcode/5a_Inequities_Patient20p.do" 3 // Dual
do "$allcode/5a_Inequities_Patient20p.do" 4 // Nondual
do "$allcode/5a_Inequities_Patient20p.do" 5 // White
do "$allcode/5a_Inequities_Patient20p.do" 6 // Black
do "$allcode/5a_Inequities_Patient20p.do" 7 // Hispanic
do "$allcode/5a_Inequities_Patient20p.do" 8 // Other
do "$allcode/5a_Inequities_Patient20p.do" 9 // All non-white
do "$allcode/5a_Inequities_Patient20p.do" 10 // Low disadvantage ADI (quintile)
do "$allcode/5a_Inequities_Patient20p.do" 11 // High disadvantage ADI (quintile)
do "$allcode/5a_Inequities_PatientLevel20p_CombineTable" // makes the table

// FIGURE 7: Market Level Relationships between Treatment Propensity and Risk Factors for Crowd-Out
do "$allcode/6_AllocativeInefficiency.do" // prep data
do "$allcode/6a_AllocativeInefficiency-CorrelationRiskADI.do" // binscatters 

// TABLE 4: Effects of TAVR Adoption on Local Intervention Volume: By Pre-TAVR Propensity to Treat
do "$allcode/6b_AllocativeInefficiency-DDQuintiles.do" 1 // pooled effects across quintiles of treatment thresholds 
do "$allcode/6b_AllocativeInefficiency-DDQuintiles.do" 2 // pooled effects across quintiles of treatment thresholds 
do "$allcode/6b_AllocativeInefficiency-DDQuintiles.do" 3 // pooled effects across quintiles of treatment thresholds 
do "$allcode/6b_AllocativeInefficiency-DDQuintiles.do" 4 // pooled effects across quintiles of treatment thresholds 
do "$allcode/6c_AllocativeInefficiency_MakeTable.do" // make these into a table with pooled effects  
********************************************************************************


***** APPENDIX TABLES
// Table A1 (physician market sizes over time)
do "$allcode/Appendix_Tables/A1_InterventionSummaryTable.do" // makes table for A1 and figure A1 as well below

// Table A2 is manually constructed (ICD codes for identifying events) -- email if you would like the .tex file 

// Table A3: STS-PROM Logistic Regression Coefficients
do "$allcode/Appendix_Tables/A2_EstimatePatientRisk.do"

// Table A4 Robustness to Poisson estimation 
do "$allcode/Appendix_Tables/A3a_EventStudies_MarketLevel_ppml.do" all extensive // LP-DID results using ppmlhdfe
do "$allcode/Appendix_Tables/A3a_EventStudies_MarketLevel_ppml.do" high extensive // FIGURE 4a
do "$allcode/Appendix_Tables/A3b_EventStudies_IndividualProcedures_ppml.do" cath //  figure 4c
do "$allcode/Appendix_Tables/A3b_EventStudies_IndividualProcedures_ppml.do" ptcaonly // figure 4b
do "$allcode/Appendix_Tables/A3b_EventStudies_IndividualProcedures_ppml.do" allother // figure 4d
do "$allcode/Appendix_Tables/A3c_EventStudies_PatientLevel_20240307_lpdid" all // runs regression for ppml and lpdid simultaneously

// Table A5: Complications ICD/CPT codes -- email if you would like the .tex file
********************************************************************************


***** APPENDIX FIGURES
// Figure A1 comes from the same code as Table A1 above ("A1_InterventionSummaryTable.do")

// Figure A2 (histogram of predicted risk) comes same code as Table A3 above

// Figure A3: Organization-level trends in utilization around TAVR adoption
do "$allcode/Appendix_Figures/A3_VolumesAroundAdoption.do"

// Figure A4: Procedural Volume Responses to TAVR Adoption, by Intervention Type
do "$allcode/2a_EventStudies_MarketLevel.do" high extensive // figure 4a
do "$allcode/Appendix_Figures/A4_EventStudies_IndividualProcedures.do" ptcaonly // figure 4b
do "$allcode/Appendix_Figures/A4_EventStudies_IndividualProcedures.do" cath //  figure 4c
do "$allcode/Appendix_Figures/A4_EventStudies_IndividualProcedures.do" allother // figure 4d

// Figure A5: Market Relationships Between TAVR Takeup and Overall Intervention Volume
do "$allcode/Appendix_Figures/A5_Binscatter.do" 

// Figure A6: LONG RUN EVENT STUDIES
do "$allcode/Appendix_Figures/A6_LongRun_MarketLevel.do" all extensive 16 // indicate how many quarters you want post
do "$allcode/Appendix_Figures/A6a_LongRun_PatientLevel.do" all 16 // indicate how many quarters you want post

// Figure A7: Average Commercial and Medicare Prices for Interventional Cardiology Procedures and SAVR
// note that prices in panel (a) (commercial prices from Merative) come from separate server with Merative data
	// to run the code for this (with the other data lined up): 
	// first, pull the raw data using the .sas files 1.TAVRPricesServices_2006.sas and 1.TAVRPricesAdmissions_2006.sas
	do "$allcode/PullMarketscanPrices/2_OrganizeData.do" // combine the data
	do "$allcode/PullMarketscanPrices/3_DescriptivePriceChanges.do" // make panel (a)
	
do "$allcode/Appendix_Figures/A7_MedicarePrices.do" // panel (b) 


// Figure A8: Robustness to excluding patients with CAD
do "$allcode/Appendix_Figures/A8_EventStudies_MarketLevel_NoCAD.do"

// Figure A9: Robustness: Total Intervention Effects, Dynamic Difference-in-Differences Model Relative to 2011 Quarter 4
do "$allcode/Appendix_Figures/A9_NoStaggeredAdoption.do" all extensive // LP-DID with no staggered adoption in timing 

// Figure A10: Effect of TAVR Adoption on Screening for Surgical Viability
do "$allcode/Appendix_Figures/A10_TAVRScreening.do"

// Figure A11: TAVR Adoption Effects on Acute Angiography for NSTEMI PatientsPre-treatment mean: 39.63
do "$allcode/Appendix_Figures/A11a_Flag_NSTEMIs.do" // for data creation
do "$allcode/Appendix_Figures/A11b_ID_Angiography.do"
do "$allcode/Appendix_Figures/A11c_MarketLevelRates.do"
do "$allcode/Appendix_Figures/A11d_TAVREffects.do"

// Figure A12: Impact of TAVR Adoption on PCI Volumes, Individual Operator Level
do "$allcode/Appendix_Figures/A12_EffectAdoption_ProcedureShares.do"

// Figure A13: Heterogeneous Effects of TAVR Adoption on Procedural Volumes by Patient Risk
// this unsmoothed version is constructed in the code "$allcode/2c_EventStudies_MarketLevel_BinnedRisk.do" all "all" above. 

// Figure A14: Effects of TAVR Adoption on Total Intervention Volumes by Patient Risk: Effects as % of Overall Decline
do "$allcode/2c_EventStudies_MarketLevel_BinnedRisk.do" all "perc" 

// Figure A15: Effects of TAVR Adoption on Procedural Volumes by Dual-Medicaid Eligibility
do "$allcode/5_MarketInequities_Binned.do" all riskvar_dual_any 5 // can also do riskvar_dual_full for those who are dual for the full year

// Figure A16: Distribution of Risk-Adjusted Treatment Thresholds, CZ Level
// this is produced in "$allcode/6_AllocativeInefficiency.do" above

// Figure A17: produced in Latex only (email if you want the .tex file) 
********************************************************************************
