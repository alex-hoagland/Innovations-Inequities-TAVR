/*******************************************************************************
* Title: Estimate patient risk / appropriateness for TAVR
* Created by: Alex Hoagland
* Created on: 2/21/2022
* Last modified on: 
* Last modified by: 
* Purpose: Identifies risk/appropriateness for TAVR
* Notes: - identifies a risk measure for each patient-year for all AS, OP, and IP patients (can trim later?)
	- single risk index as predicted probability of TAVR, or PCA of covariates?

* Key edits: 
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202105"
global geodata "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/Geography"
********************************************************************************


***** 1. Use all cardiology patients (not just inpatient; can trim this down later)
use "$datadir/TreatmentPanel_AllCardiologist_OutpatientVisits_202110.dta", clear 
	// note: this data set needs to be updated with the new cardiologists? Might be missing some patients
keep bene_id 
duplicates drop
append using "$datadir/all_InpatientCardiology" // add any who got inpatient care without outpatient care
keep bene_id 
duplicates drop
// about 8.8 million patients

sort bene_id 
compress
save "$datadir/AllPatients_BeneIDs.dta", replace
********************************************************************************


***** 2. Match in major beneficiary information (risk scores, chronic conditions, etc.)
clear
gen year = .
save "$datadir/PatientRisk.dta", replace

// Merge in dummies for chronic conditions and utilization in each year
forvalues i = 2010/2017 { 
	di "YEAR: `i'"
	use "$datadir/AllPatients_BeneIDs.dta", clear
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsfcc/`i'/bsfcc`i'.dta, keep(3) nogenerate // chronic conditions
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsfcu/`i'/bsfcu`i'.dta, keep(3) nogenerate // cost and utilization
	gen year = `i'
	append using "$datadir/PatientRisk.dta"
	compress
	save "$datadir/PatientRisk.dta", replace
}

// Merge in age/sex information
use "$datadir/PatientRisk.dta", clear
forvalues i = 2010/2017 { 
	di "YEAR: `i'"
	merge 1:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsfab/`i'/bsfab`i'.dta, ///
		keep(1 3 4 5) nogenerate update ///
		keepusing(age sex state_cd cnty_cd race death_dt) 
}
save "$datadir/PatientRisk.dta", replace
********************************************************************************


***** 3. Variables used in calculating STS-PROM
// currently, no interactions used (that I have all data for) 

* Demographics: sex, age, race (black, hispanic, white, other), # of chronic conditions, time trend (year FE)

* General chronic conditions : 
// CHF, diabetes, dialysis, hypertension, stroke, AMI, COPD

* DXIs (plus mapping to ICD-9-CM)
// AFib: DXI1_CIR023	Atrial_fibrillation_and_flutter (ICD-10: I48,I480,I481,I482,I483,I484,I489,I4891,I4892)

// CIR HIER: CeVD
	// CIR	Cerebral infarction (ICD-10: I693,I6930,I6931,I69310,I69311,I69312,I69313,I69314,I69315,I69318,I69319,I6932,I69320,I69321,I69322,I69323,I69328,I6933,I69331,I69332,I69333,I69334,I69339,I6934,I69341,I69342,I69343,I69344,I69349,I6935,I69351,I69352,I69353,I69354,I69359,I6936,I69361,I69362,I69363,I69364,I69365,I69369,I6939,I69390,I69392,I69393,I69398,I698,I6980,I6981,I69810,I69811,I69812,I69813,I69814,I69815,I69818,I69819,I6982,I69820,I69821,I69822,I69823,I69828,I6983,I69831,I69832,I69833,I69834,I69839,I6984,I69841,I69842,I69843,I69844,I69849,I6985,I69852,I69853,I69854,I69859,I6986,I69861,I69862,I69863,I69864,I69865,I69869,I6989,I69890,I69891,I69892,I69893,I69898,I699,I6990,I6991,I69910,I69911,I69912,I69913,I69914,I69915,I69918,I69919,I6992,I69920,I69921,I69922,I69923,I69928,I6993,I69931,I69932,I69933,I69934,I69939,I6994,I69941,I69942,I69943,I69944,I69949,I6995,I69951,I69952,I69953,I69954,I69959,I6996,I69961,I69962,I69963,I69964,I69965,I69969,I6999,I69990,I69991,I69992,I69993,I69998
	// CIR	Occlusion or stenosis of precerebral or cerebral arteries without infarction (I65,I650,I6501,I6502,I6503,I6509,I651,I652,I6521,I6522,I6523,I6529,I658,I659)
	// CIR	Other and ill-defined cerebrovascular disease (I518,I5189,I519,I52)
	// CIR	Nontramatic_subarachnoid_hemorrhage (I60,I600,I6000,I6001,I6002,I601,I6010,I6011,I6012,I602,I603,I6030,I6031,I6032,I604,I605,I6050,I6051,I6052,I606,I607,I608,I609,I690,I6900,I6901,I69010,I69011,I69012,I69013,I69014,I69015,I69018,I69019,I6902,I69020,I69021,I69022,I69023,I69028,I6903,I69031,I69032,I69033,I69034,I69039,I6904,I69041,I69042,I69043,I69044,I69049,I6905,I69051,I69052,I69053,I69054,I69059,I6906,I69061,I69062,I69063,I69064,I69065,I69069,I6909,I69090,I69091,I69092,I69093,I69098)
	// CIR	Nontraumatic_intracerrebral_hemorrhage (I61,I610,I611,I612,I613,I614,I615,I616,I618,I619,I691,I6910,I6911,I69110,I69111,I69112,I69113,I69114,I69115,I69118,I69119,I6912,I69120,I69121,I69122,I69123,I69128,I6913,I69131,I69132,I69133,I69134,I69139,I6914,I69141,I69142,I69143,I69144,I69149,I6915,I69151,I69152,I69153,I69154,I69159,I6916,I69161,I69162,I69163,I69164,I69165,I69169,I6919,I69190,I69191,I69192,I69193,I69198)
	// CIR	Nontraumatic_intracranial_hemorrhage (I692,I6920,I6921,I69210,I69211,I69212,I69213,I69214,I69215,I69218,I69219,I6922,I69220,I69221,I69222,I69223,I69228,I6923,I69231,I69232,I69233,I69234,I69239,I6924,I69241,I69242,I69243,I69244,I69249,I6925,I69251,I69252,I69253,I69254,I69259,I6926,I69261,I69262,I69263,I69264,I69265,I69269,I6929,I69290,I69291,I69292,I69293,I69298,I62,I620,I6200,I6201,I6202,I6203,I621,I629,,	// CIR	Stroke,	// CIR	Non-stroke,	// CIR	Non-stroke_cerebral_infarction,
	// CIR	Cerebrovascular_diseases_oth (I67,I670,I673,I676,I67850,I67858,I6789,I679,I68,I680,I682,I688,I69)
	// CIR	Cerebral_aneurysm_nonruptured (I671)
	// CIR	Cerebral_arteritis_not_elsewhere_classified (I677,I678,I6781,I6782,I6783,I6784,I67841,I6785)
	// CIR	Cerebrovascular_vasospasm_and_vasoconstriction_oth (I67848)
	// CIR	Cerebral_infarction (I693,I6930,I6931,I69310,I69311,I69312,I69313,I69314,I69315,I69318,I69319,I6932,I69320,I69321,I69322,I69323,I69328,I6933,I69331,I69332,I69333,I69334,I69339,I6934,I69341,I69342,I69343,I69344,I69349,I6935,I69351,I69352,I69353,I69354,I69359,I6936,I69361,I69362,I69363,I69364,I69365,I69369,I6939,I69390,I69392,I69393,I69398,I698,I6980,I6981,I69810,I69811,I69812,I69813,I69814,I69815,I69818,I69819,I6982,I69820,I69821,I69822,I69823,I69828,I6983,I69831,I69832,I69833,I69834,I69839,I6984,I69841,I69842,I69843,I69844,I69849,I6985,I69852,I69853,I69854,I69859,I6986,I69861,I69862,I69863,I69864,I69865,I69869,I6989,I69890,I69891,I69892,I69893,I69898,I699,I6990,I6991,I69910,I69911,I69912,I69913,I69914,I69915,I69918,I69919,I6992,I69920,I69921,I69922,I69923,I69928,I6993,I69931,I69932,I69933,I69934,I69939,I6994,I69941,I69942,I69943,I69944,I69949,I6995,I69951,I69952,I69953,I69954,I69959,I6996,I69961,I69962,I69963,I69964,I69965,I69969,I6999,I69990,I69991,I69992,I69993,I69998)

// PVD
	// CIR	Peripheral and visceral vascular disease(I73,I731,I738,I7381,I7389,I739)
	// CIR	Oth_pulmonary_heart_diseases (I27,I271,I272,I2720,I2721,I2722,I2723,I2729,I278,I2781,I2782,I2783,I2789,I279)
	// CIR	Pulmonary_vascular_abnormalities (I28,I280,I281,I288,I289)
	// CIR	Raynauds_syndrome (I730,I7300,I7301)
	// CIR	Arteritis_unsp (I776,I778,I7781,I77810,I77811,I77812,I77819,I7789,I779,I78,I780,I781,I788,I789,I79,I790,I791,I798)
	// CIR	Secondary_esophageal_varices (I85,I850,I8500,I8501,I851)
	// CIR	Gastric_varices (I864)
	// CIR	Nonspecific_lymphadenitis (I88,I880,I881,I888,I889)
	// CIR	Noninfective_disorders_of_lymphatic_vessels_and_nodes_oth (I89,I890,I891,I898,I899)
	// CIR  Atheroembolism (I75,I750,I7501,I75011,I75012,I75013,I75019,I7502,I75021,I75022,I75023,I75029,I758,I7581,I7589,I76)

// Atherosclerosis (ICD10: I70,I700,I701,I702,I7020,I70201,I70202,I70203,I70208,I70209,I7021,I70211,I70212,I70213,I70218,I70219,I7029,I70291,I70292,I70293,I70298,I70299,I70799,I708,I709,I7090,I7091,I7092)

// Cirrhosis: DXI1_DIG065	Alcoholic_cirrhosis, (K7030,K7031,K704,K7040,,7041,K709,K7010,K7011,K702,K703,K71,K700,K701)
// 				DXI1_DIG076	Secondary_biliary_cirrhosis (K745,K746,K7460,K7469,K75)
// Pulmonary hypertension: DXI1_CIR006	Pulmonary_hypertension_primary_and_chronic_thromboembolic (I270,I2724)

// Pulmonary embolism: DXI1_CIR015	Embolism (I26,I269,I2690,I2692,I2699,I260,I2601,I2602,I2609)

// DXI1_SYM006	Cachexia (R64)
// DXI1_CIR047	Acute_and_subacute_endocarditis: (ICD-10 I33, I330, I339, I38, I39)

// DXI1_CIR048	Acute_myocarditis (CD-10 I40, I400, I401, I408, I409, I41)
// DXI1_CIR049	Acute_pericarditis (ICD-10 I30, I300, I301, I308, I309)

// Renal failure: (others?) + DXI1_GEN071	Acute_kidney_failure (N17,N170,N171,N172,N178,N179)
	// Chronic Kidney Disease (not stage 5 and ESRD) N18,N181,N182,N183,N184,N189,N19
	// CKD, stage 5 and ESRD: N185,N186

// DXI1_CIR035	Angina (I20,I201,I208,I209,I24,I240,I241,I248,I249,I25,I251,I2510,I2511,I25111,I25118,I25119,I257,I2570,I25701,I25708,I25709,I2571,I25710,I25711,I25718,I25719,I2572,I25720,I25721,I25728,I25729,I2573,I25731,I25738,I25739,I2575,I25750,I25751,I25758,I25759,I2576,I25760,I25761,I25768,I25769,I2579,I25790,I25791,I25798,I25799)
// DXI1_CIR024	Cardiac_arrhythmias_oth (I49,I490,I4901,I4902,I491,I492,I493,I494,I4940,I4949,I498,I499)



* Other data from claims: 
// insulin use, immunosuppressive treatment, 
// mitral stenosis (I050, I052)
// aortic stenosis (I060, I062)
// tricuspid stenosis (I070, I072)
// pulmonic stenosis, pulmonic insufficiency
// aortic valve insufficiency (I061)
// mitral insufficiency (I051)
// tricuspid insufficiency (I071)
// BMI, smoker, calcified/diseased aorta, 
// right ventricular failure (I5082, missing right)
// hypercholesterolemia, cardiogenic shock, resuscitation

* Prior surgeries (also from claims): 
// any prior surgery (previous calendar year), # of surgeries last year, previous coronary artery bypass, 
// previous valve surgery, previous PCI, 

********************************************************************************


***** 4. Merge in surgeries + mortality outcomes (all IVC procedures)
// outcome: mortality in-hospital (before discharge) and within 30 days of procedure

********************************************************************************


***** 5. Estimate regression coefficients, check for validity, and use to generate predicted risk

********************************************************************************


***** 6. Examine distribution of predicted risk
// generally, low risk is <= 3%, medium risk is 3-8%, and high risk is >= 8%

********************************************************************************
