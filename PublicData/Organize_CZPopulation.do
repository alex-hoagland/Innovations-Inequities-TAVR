use bene_id file_year using "$datadir/ASpatients2024_20p.dta", clear
duplicates drop 

// first, pull zips
gen bene_zip = ""
forvalues y = 2010/2016 { 
	di "***** PART AB for `y' *******"
	merge 1:1 bene_id file_year using /disk/aging/medicare/data/harm/20pct/bsf/`y'/bsfab`y'.dta, ///
	keep(1 3) nogenerate keepusing(bene_id file_year g_bene_zip5)
	replace bene_zip = g_bene_zip5 if file_year == `y'
	drop g_bene_zip5
} 
merge 1:1 bene_id file_year using /disk/aging/medicare/data/harm/20pct/bsf/2017/bsfab2017.dta, ///
	keep(1 3) nogenerate keepusing(bene_id file_year zip_cd)
replace bene_zip = zip_cd if file_year == 2017
drop zip_cd

// second, pull dual status (from Part D)
gen dual_months = ""
forvalues y = 2010/2016 { 
	di "***** PART D for `y' *******"
	merge 1:1 bene_id file_year using /disk/aging/medicare/data/harm/20pct/bsf/`y'/bsfd`y'.dta, ///
	keep(1 3) nogenerate keepusing(bene_id file_year dual_mo)
	replace dual_months = dual_mo if file_year == `y'
	drop dual_mo
} 
destring dual_months, replace
merge 1:1 bene_id file_year using /disk/aging/medicare/data/harm/20pct/bsf/2017/bsfd2017.dta, ///
	keep(1 3) nogenerate keepusing(bene_id file_year dual_mo)
replace dual_months = dual_mo if file_year == 2017
drop dual_mo
replace dual_months = 0 if missing(dual_months)

// merge in ADI based on zip
destring bene_zip, gen(zip_cd)
merge m:1 zip_cd using "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/ADI/ADI_allstates.dta", keep(1 3) nogenerate
drop zip_cd 

// merge back in 
merge 1:m bene_id file_year using "$datadir/ASpatients2024_20p.dta", keep(2 3) nogenerate

// divisions
gen white = (race == "1") // race
gen female = (sex == "2") // sex
gen dual_any = (dual_months > 0) //dual
gen dual_full = (dual_months == 12) 
gen adi_50 = (adi > 50)
gen adi_80 = (adi_natrank > 80) // 1 = disadvantage 
compress
save "$datadir/ASpatients2024_20p.dta", replace // so that you don't have to do this again. 

// collapse and save 
gen num = 1 
gcollapse (sum) pop=num pop_white=white pop_female=female pop_dual_any=dual_any ///
	pop_dual_full=dual_full pop_adi_50=adi_50 pop_adi_80=adi_80, by(CZID file_year yq) fast
gen pop_nonwhite = pop - pop_white
gen pop_male = pop - pop_female
gen pop_nondual_any = pop - pop_dual_any
gen pop_nondual_full = pop - pop_dual_full
gen pop_adi50_good = pop - pop_adi_50
gen pop_adi80_good = pop - pop_adi_80
compress
save "$datadir/CZpop.dta"
