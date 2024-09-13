use "$datadir\PublicData\ADI_9digits.dta"

drop if strpos(adi_9, "PH") | strpos(adi_9, "Q") | strpos(adi_9, "N")
destring adi_9, replace
drop adi_state

// go from 9-digit zip to 5-digit zip, as we don't have 9 digits in Medicare claims 
	// 9-digit zip populations here: https://simplemaps.com/data/us-zips
	// note: we don't have 9-digit population, so this is likely imperfect 
format zip %09.0f // leading 0s
gen zip2 = string(zip, "%09.0f")
gen zip5 = substr(zip2, 1, 5)
destring zip5, replace
gcollapse (mean) adi_9, by(zip5) fast

rename adi_9 adi_5 
rename zip5 zip_cd

compress
save "$datadir\PublicData\ADI_5digits.dta", replace
