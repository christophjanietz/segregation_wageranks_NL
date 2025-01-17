/*=============================================================================* 
* SEX SEGREGATION ACROSS WAGE RANKS IN DUTCH ORGANIZATIONS
*==============================================================================*
 	Project: Beyond Boardroom (9607)
	Author: Christoph Janietz (c.janietz@rug.nl)
	Last update: 17-01-2025
* ---------------------------------------------------------------------------- *

	INDEX: 
		0.  SETTINGS 
		1.  PREPARING INDIVIDUAL-LEVEL WAGE DATA
		2.  DECILE SHARES (NOT WEIGHTED)
		3.  DECILE SHARES (WEIGHTED BY FIRM SIZE)
		4.  COMBINE FILES
		
* Short description of output:
*
* - Within-organization sex segregation across wage ranks (deciles).
*
* NIDIO files used:
* - spolis_month_2006_2023
* - gba_rin_2023
* - abr_ogbe_register_2006_2023

* --------------------------------------------------------------------------- */
* 0. SETTINGS 
* ---------------------------------------------------------------------------- * 

*** Settings - run config file
	global sdir 		"H:/Syntax"	
	do 					"${sdir}/config"
	
	global wdir			"H:/Projects/CJ/glass"
	global adir			"H:/Projects/CJ/glass/analysis/d_shares"

	
* --------------------------------------------------------------------------- */
* 1. PREPARING INDIVIDUAL-LEVEL WAGE DATA
* ---------------------------------------------------------------------------- *

	foreach year of num 2011/2023 {
		//  Starting point: monthly SPOLIS for 2011/2023; excluding directors, interns, 
		//  and wsw-ers; restricted to mainjobs
		spolisselect, data(month) start(`year') end(`year') jobtype(2) mainjob(1)
	
		// Merge GBA data (administrative sex categories)
		sort rinpersoon
		merge 1:1 rinpersoon using "${dGBA}/gba_rin_2023", ///
			keep(match) keepusing(rin_sex) nogen 
		
		// Merge ABR data (industry) 
		sort year beid
		merge m:1 year beid using "${dABR}/abr_ogbe_register_2006_2023", ///
			keep(match) keepusing(be_industry) nogen
		
		* Reduce variable set 
		keep rinpersoon beid sbasisloon_month sreguliereuren_month rin_sex ///
			be_industry
		
		// Construct hourly wage measure
		gen hwage = sbasisloon_month/sreguliereuren_month 
		drop sbasisloon_month sreguliereuren_month
		* Bottom-code negative wages
		replace hwage = 1 if hwage<1
		* Remove few missings of wage
		drop if hwage==.
		
		// Drop extraterritorial organizations
		drop if be_industry==21
		
		// Restrict to large organizations (N>=100)
		orgsizeselect, id(beid) min(100) n_org(1) select(1)
	
		// Dummy man / woman
		gen woman = 0
		replace woman=1 if rin_sex==2
		gen man = 0
		replace man=1 if rin_sex==1
		
		// Generate within-firm wage ranks (deciles)
		gquantiles withind = hwage, xtile nquantiles(10) by(beid)
		
		// Save dataset
		save "${wdir}/data/d/wages_`year'", replace
	}
	*

	
* --------------------------------------------------------------------------- */
* 2. DECILE SHARES (NOT WEIGHTED)
* ---------------------------------------------------------------------------- *

	foreach year of num 2011/2023 {
		use "${wdir}/data/d/wages_`year'", replace
		
		gen year = `year'
		sort beid year
		
		merge m:1 beid year using "${dABR}/abr_ogbe_register_2006_2023", ///
			keepusing(og_sector be_gksbs vep_legalform og_ownership) nogen ///
			keep(match)
			
		merge m:1 beid year using "${wdir}/data/cao_status", ///
			keepusing(cao) nogen keep(master match)
	
		// Collapse into summary datasets
		
		**********************
		* Overall labor market
		**********************
		preserve
			gegen tot_woman = mean(woman)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=woman (median) tot_woman=tot_woman ///
				n_org=n_org (sum) N = woman, by(withind)
			drop if withind==.
			gen sex="Women"
			save "${adir}/withinq_women", replace
		restore
		preserve
			gegen tot_woman = mean(woman)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=man (median) tot_woman=tot_woman ///
				n_org=n_org (sum) N = man, by(withind)
			drop if withind==.
			gen sex="Men"
			append using "${adir}/withinq_women" 
			erase "${adir}/withinq_women.dta"
			sort withind sex
			gen pc = round((share*100),.01) 
			save "${adir}/withinq_all_`year'", replace
		restore
	
		*************
		* By industry
		*************
		foreach ind of num 1/19 {
			preserve
				gegen tot_woman = mean(woman) if be_industry==`ind'
				gunique beid if be_industry==`ind'
				gen n_org=r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = woman if be_industry==`ind', by(withind)
				gen sex="Women"
				gen subpop=`ind'
				order subpop, before(withind)
				save "${adir}/withinq_w_`ind'", replace
			restore		
		}
		*
		foreach ind of num 1/19 {
			preserve
				gegen tot_woman = mean(woman) if be_industry==`ind'
				gunique beid if be_industry==`ind'
				gen n_org=r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = man if be_industry==`ind', by(withind)
				gen sex="Men"
				gen subpop=`ind'
				order subpop, before(withind)
				save "${adir}/withinq_m_`ind'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_19", replace
			append using "${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7" "${adir}/withinq_w_8" ///
			"${adir}/withinq_w_9" "${adir}/withinq_w_10" ///
			"${adir}/withinq_w_11" "${adir}/withinq_w_12" ///
			"${adir}/withinq_w_13" "${adir}/withinq_w_14" ///
			"${adir}/withinq_w_15" "${adir}/withinq_w_16" ///
			"${adir}/withinq_w_17" "${adir}/withinq_w_18" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2" ///
			"${adir}/withinq_m_3" "${adir}/withinq_m_4" ///
			"${adir}/withinq_m_5" "${adir}/withinq_m_6" ///
			"${adir}/withinq_m_7" "${adir}/withinq_m_8" ///
			"${adir}/withinq_m_9" "${adir}/withinq_m_10" ///
			"${adir}/withinq_m_11" "${adir}/withinq_m_12" ///
			"${adir}/withinq_m_13" "${adir}/withinq_m_14" ///
			"${adir}/withinq_m_15" "${adir}/withinq_m_16" ///
			"${adir}/withinq_m_17" "${adir}/withinq_m_18" ///
			"${adir}/withinq_m_19"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def ind_lbl 1"Industry: Agriculture, forestry, and fishing (SBI08 A)" ///
				2"Industry: Mining and quarrying (SBI08 B)" ///
				3"Industry: Manufacturing (SBI08 C)" ///
				4"Industry: Electricity, gas, steam, and air conditioning supply (SBI08 D)" ///
				5"Industry: Water supply; sewerage, waste management and remidiation activities (SBI08 E)" ///
				6"Industry: Construction (SBI08 F)" ///
				7"Industry: Wholesale and retail trade; repair of motorvehicles and motorcycles (SBI08 G)" ///
				8"Industry: Transportation and storage (SBI08 H)" ///
				9"Industry: Accomodation and food service activities (SBI08 I)" ///
				10"Industry: Information and communication (SBI08 J)" ///
				11"Industry: Financial institutions (SBI08 K)" ///
				12"Industry: Renting, buying, and selling of real estate (SBI08 L)" ///
				13"Industry: Consultancy, research and other specialised business services (SBI08 M)" ///
				14"Industry: Renting and leasing of tangible goods and other business support services (SBI08 N)" ///
				15"Industry: Public administration, public services, and compulsory social security (SBI08 O)" ///
				16"Industry: Education (SBI08 P)" ///
				17"Industry: Human health and social work activities (SBI08 Q)" ///
				18"Industry: Culture, sports, and recreation (SBI08 R)" ///
				19"Industry: Other service activities (SBI08 S)" ///
				20"Activities of households as employers (SBI08 T)" ///
				21"Extraterritorial organizations and bodies (SBI08 U)", replace
			lab val subpop ind_lbl
	
			save "${adir}/withinq_industry_`year'", replace
	
			foreach ind of num 1/19 {
				erase "${adir}/withinq_w_`ind'.dta"
				erase "${adir}/withinq_m_`ind'.dta"	
			}
			*
		restore
		
		***********
		* By sector
		***********
		foreach sect of num 11 12 13 15 {
			preserve
				gegen tot_woman = mean(woman) if og_sector==`sect'
				gunique beid if og_sector==`sect'
				gen n_org=r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = woman if og_sector==`sect', by(withind)
				gen sex="Women"
				gen subpop=`sect'
				order subpop, before(withind)
				save "${adir}/withinq_w_`sect'", replace
			restore		
		}
		*
		foreach sect of num 11 12 13 15 {
			preserve
				gegen tot_woman = mean(woman) if og_sector==`sect'
				gunique beid if og_sector==`sect'
				gen n_org=r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = man if og_sector==`sect', by(withind)
				gen sex="Men"
				gen subpop=`sect'
				order subpop, before(withind)
				save "${adir}/withinq_m_`sect'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_15", replace
			append using "${adir}/withinq_w_11" "${adir}/withinq_w_12" ///
			"${adir}/withinq_w_13" "${adir}/withinq_m_11" ///
			"${adir}/withinq_m_12" "${adir}/withinq_m_13" ///
			"${adir}/withinq_m_15"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def sect_lbl 11"Sector: Non-financial companies" ///
				12"Sector: Financial organizations" ///
				13"Sector: Governmental organizations" ///
				15"Sector: Non-governmental non-profit organizations", replace
			lab val subpop sect_lbl
	
			save "${adir}/withinq_sector_`year'", replace
	
			foreach sect of num 11 12 13 15 {
				erase "${adir}/withinq_w_`sect'.dta"
				erase "${adir}/withinq_m_`sect'.dta"	
			}
			*
		restore
		
		*********
		* By size
		*********
		foreach gksbs of num 1/7 {
			preserve
				gegen tot_woman = mean(woman) if be_gksbs==`gksbs'
				gunique beid if be_gksbs==`gksbs'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = woman if be_gksbs==`gksbs', by(withind)
				gen sex="Women"
				gen subpop=`gksbs'
				order subpop, before(withind)
				save "${adir}/withinq_w_`gksbs'", replace
			restore		
		}
		*
		foreach gksbs of num 1/7 {
			preserve
				gegen tot_woman = mean(woman) if be_gksbs==`gksbs'
				gunique beid if be_gksbs==`gksbs'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = man if be_gksbs==`gksbs', by(withind)
				gen sex="Men"
				gen subpop=`gksbs'
				order subpop, before(withind)
				save "${adir}/withinq_m_`gksbs'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_7", replace
			append using "${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2" ///
			"${adir}/withinq_m_3" "${adir}/withinq_m_4" ///
			"${adir}/withinq_m_5" "${adir}/withinq_m_6" ///
			"${adir}/withinq_m_7"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def gksbs_lbl 1 "Size: 50-99 employees" 2 "Size: 100-149 employees" ///
				3 "Size: 150-199 employees" 4 "Size: 200-249 employees" 5 "Size: 250-499 employees" ///
				6 "Size: 500-999 employees" 7 "Size: 1000-1999 employees" 8 "Size: 2000+ employees", replace
			lab val subpop gksbs_lbl 
	
			save "${adir}/withinq_gksbs_`year'", replace
	
			foreach gksbs of num 1/7 {
				erase "${adir}/withinq_w_`gksbs'.dta"
				erase "${adir}/withinq_m_`gksbs'.dta"	
			}
			*
		restore
		
		***************
		* By legal form
		***************
		foreach legal of num 43 57 74 900 {
			preserve
				gegen tot_woman = mean(woman) if vep_legalform==`legal'
				gunique beid if vep_legalform==`legal'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = woman if vep_legalform==`legal', by(withind)
				gen sex="Women"
				gen subpop=`legal'
				order subpop, before(withind)
				save "${adir}/withinq_w_`legal'", replace
			restore		
		}
		*
		foreach legal of num 43 57 74 900  {
			preserve
				gegen tot_woman = mean(woman) if vep_legalform==`legal'
				gunique beid if vep_legalform==`legal'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = man if vep_legalform==`legal', by(withind)
				gen sex="Men"
				gen subpop=`legal'
				order subpop, before(withind)
				save "${adir}/withinq_m_`legal'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_900", replace
			append using "${adir}/withinq_w_43" "${adir}/withinq_w_57" ///
			"${adir}/withinq_w_74" ///
			"${adir}/withinq_m_43" "${adir}/withinq_m_57" ///
			"${adir}/withinq_m_74" "${adir}/withinq_m_900"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def legal_lbl 43 "Legal type: Besloten Vennootschap (bv)" ///
				57 "Legal type: Naamloze Vennootschap (nv)" 74 "Legal type: Stichting" ///
				900 "Legal type: Publiekrichtelijke instelling", replace
			lab val subpop legal_lbl 
	
			save "${adir}/withinq_legal_`year'", replace
	
			foreach legal of num 43 57 74 900 {
				erase "${adir}/withinq_w_`legal'.dta"
				erase "${adir}/withinq_m_`legal'.dta"	
			}
			*
		restore
		
		**************
		* By Ownership
		**************
		foreach owner of num 2 3 {
			preserve
				gegen tot_woman = mean(woman) if og_ownership==`owner'
				gunique beid if og_ownership==`owner'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = woman if og_ownership==`owner', by(withind)
				gen sex="Women"
				gen subpop=`owner'
				order subpop, before(withind)
				save "${adir}/withinq_w_`owner'", replace
			restore		
		}
		*
		foreach owner of num 2 3 {
			preserve
				gegen tot_woman = mean(woman) if og_ownership==`owner'
				gunique beid if og_ownership==`owner'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = man if og_ownership==`owner', by(withind)
				gen sex="Men"
				gen subpop=`owner'
				order subpop, before(withind)
				save "${adir}/withinq_m_`owner'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_3", replace
			append using "${adir}/withinq_w_2" ///
			"${adir}/withinq_m_2" "${adir}/withinq_m_3" 
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def owner_lbl 2 "Ownership: Domestic non-financial companies" ///
				3 "Ownership: Foreign non-financial companies", replace
			lab val subpop owner_lbl 
	
			save "${adir}/withinq_owner_`year'", replace
	
			foreach owner of num 2 3 {
				erase "${adir}/withinq_w_`owner'.dta"
				erase "${adir}/withinq_m_`owner'.dta"	
			}
			*
		restore
		
		**************
		* By Cao status
		**************
		foreach cao of num 0 1 2 {
			preserve
				gegen tot_woman = mean(woman) if cao==`cao'
				gunique beid if cao==`cao'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = woman if cao==`cao', by(withind)
				gen sex="Women"
				gen subpop=`cao'
				order subpop, before(withind)
				save "${adir}/withinq_w_`cao'", replace
			restore		
		}
		*
		foreach cao of num 0 1 2 {
			preserve
				gegen tot_woman = mean(woman) if cao==`cao'
				gunique beid if cao==`cao'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = man if cao==`cao', by(withind)
				gen sex="Men"
				gen subpop=`cao'
				order subpop, before(withind)
				save "${adir}/withinq_m_`cao'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_2", replace
			append using "${adir}/withinq_w_0" ///
			"${adir}/withinq_w_1" "${adir}/withinq_m_0" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def cao_lbl 0 "CAO: No collective agreement" ///
				1 "CAO: Sector-level collective agreement" ///
				2 "CAO: Firm-level collective agreement", replace
			lab val subpop cao_lbl 
	
			save "${adir}/withinq_cao_`year'", replace
	
			foreach cao of num 0 1 2 {
				erase "${adir}/withinq_w_`cao'.dta"
				erase "${adir}/withinq_m_`cao'.dta"	
			}
			*
		restore
		
	}
	*
	
	* Generate year variable
	foreach var in all industry sector gksbs legal owner cao {
		foreach year of num 2011/2023 {
			use "${adir}/withinq_`var'_`year'", replace
			gen year = `year'
			order year, before(withind)
			save "${adir}/withinq_`var'_`year'", replace
		}
		*
	}
	*
	
	* Append yearly datasets
	foreach var in all industry sector gksbs legal owner cao {
		use "${adir}/withinq_`var'_2011", replace
		
		append using "${adir}/withinq_`var'_2012" ///
			"${adir}/withinq_`var'_2013" ///
			"${adir}/withinq_`var'_2014" ///
			"${adir}/withinq_`var'_2015" ///
			"${adir}/withinq_`var'_2016" ///
			"${adir}/withinq_`var'_2017" ///
			"${adir}/withinq_`var'_2018" ///
			"${adir}/withinq_`var'_2019" ///
			"${adir}/withinq_`var'_2020" ///
			"${adir}/withinq_`var'_2021" ///
			"${adir}/withinq_`var'_2022" ///
			"${adir}/withinq_`var'_2023"
			
		save "${adir}/withind_`var'", replace
		
		foreach year of num 2011/2023 {
			erase "${adir}/withinq_`var'_`year'.dta"
		}
		*
	}
	*
	
* --------------------------------------------------------------------------- */
* 3. DECILE SHARES (WEIGHTED BY FIRM SIZE)
* ---------------------------------------------------------------------------- *

	foreach year of num 2011/2023 {
		use "${wdir}/data/d/wages_`year'", replace
		
		gen year = `year'
		sort beid year
		
		merge m:1 beid year using "${wdir}/data/d/analysis_org", ///
			keepusing(og_sector be_gksbs vep_legalform og_ownership) ///
			nogen keep(match)
			
		merge m:1 beid year using "${wdir}/data/cao_status", ///
			keepusing(cao) nogen keep(master match)
	
		// Collapse into summary datasets
		
		**********************
		* Overall labor market
		**********************
		preserve
			collapse (mean) share_be=woman (sum) N = woman, by(beid withind)
			gegen tot_woman = mean(share_be)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=share_be (median) tot_woman=tot_woman ///
				n_org=n_org (sum) N = N, by(withind)
			gen sex="Women"
			save "${adir}/withinq_women", replace
		restore
		preserve
			collapse (mean) share_be=man (sum) N = man, by(beid withind)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=share_be (median) n_org=n_org (sum) N = N, by(withind)
			drop if withind==.
			gen sex="Men"
			append using "${adir}/withinq_women"
			egen tw = max(tot_woman)
			drop tot_woman
			rename tw tot_woman
			erase "${adir}/withinq_women.dta"
			sort withind sex
			gen pc = round((share*100),.01) 
			save "${adir}/withinq_all_`year'", replace
		restore
		
		*************
		* By industry
		*************
		foreach ind of num 1/19 {
			preserve
				collapse (mean) share_be=woman (sum) N = woman if be_industry==`ind', by(beid withind)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = N, by(withind)
				gen sex="Women"
				gen subpop=`ind'
				order subpop, before(withind)
				save "${adir}/withinq_w_`ind'", replace
			restore		
		}
		*
		foreach ind of num 1/19 {
			preserve
				collapse (mean) share_be=man (sum) N = man if be_industry==`ind', by(beid withind)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) N = N, by(withind)
				gen sex="Men"
				gen subpop=`ind'
				order subpop, before(withind)
				save "${adir}/withinq_m_`ind'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_19", replace
			append using "${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7" "${adir}/withinq_w_8" ///
			"${adir}/withinq_w_9" "${adir}/withinq_w_10" ///
			"${adir}/withinq_w_11" "${adir}/withinq_w_12" ///
			"${adir}/withinq_w_13" "${adir}/withinq_w_14" ///
			"${adir}/withinq_w_15" "${adir}/withinq_w_16" ///
			"${adir}/withinq_w_17" "${adir}/withinq_w_18" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2" ///
			"${adir}/withinq_m_3" "${adir}/withinq_m_4" ///
			"${adir}/withinq_m_5" "${adir}/withinq_m_6" ///
			"${adir}/withinq_m_7" "${adir}/withinq_m_8" ///
			"${adir}/withinq_m_9" "${adir}/withinq_m_10" ///
			"${adir}/withinq_m_11" "${adir}/withinq_m_12" ///
			"${adir}/withinq_m_13" "${adir}/withinq_m_14" ///
			"${adir}/withinq_m_15" "${adir}/withinq_m_16" ///
			"${adir}/withinq_m_17" "${adir}/withinq_m_18" ///
			"${adir}/withinq_m_19"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def ind_lbl 1"Industry: Agriculture, forestry, and fishing (SBI08 A)" ///
				2"Industry: Mining and quarrying (SBI08 B)" ///
				3"Industry: Manufacturing (SBI08 C)" ///
				4"Industry: Electricity, gas, steam, and air conditioning supply (SBI08 D)" ///
				5"Industry: Water supply; sewerage, waste management and remidiation activities (SBI08 E)" ///
				6"Industry: Construction (SBI08 F)" ///
				7"Industry: Wholesale and retail trade; repair of motorvehicles and motorcycles (SBI08 G)" ///
				8"Industry: Transportation and storage (SBI08 H)" ///
				9"Industry: Accomodation and food service activities (SBI08 I)" ///
				10"Industry: Information and communication (SBI08 J)" ///
				11"Industry: Financial institutions (SBI08 K)" ///
				12"Industry: Renting, buying, and selling of real estate (SBI08 L)" ///
				13"Industry: Consultancy, research and other specialised business services (SBI08 M)" ///
				14"Industry: Renting and leasing of tangible goods and other business support services (SBI08 N)" ///
				15"Industry: Public administration, public services, and compulsory social security (SBI08 O)" ///
				16"Industry: Education (SBI08 P)" ///
				17"Industry: Human health and social work activities (SBI08 Q)" ///
				18"Industry: Culture, sports, and recreation (SBI08 R)" ///
				19"Industry: Other service activities (SBI08 S)" ///
				20"Activities of households as employers (SBI08 T)" ///
				21"Extraterritorial organizations and bodies (SBI08 U)", replace
			lab val subpop ind_lbl
	
			save "${adir}/withinq_industry_`year'", replace
	
			foreach ind of num 1/19 {
				erase "${adir}/withinq_w_`ind'.dta"
				erase "${adir}/withinq_m_`ind'.dta"	
			}
			*
		restore
		
		***********
		* By sector
		***********
		foreach sect of num 11 12 13 15 {
			preserve
				collapse (mean) share_be=woman (sum) N = woman if og_sector==`sect', by(beid withind)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = N, by(withind)
				gen sex="Women"
				gen subpop=`sect'
				order subpop, before(withind)
				save "${adir}/withinq_w_`sect'", replace
			restore		
		}
		*
		foreach sect of num 11 12 13 15 {
			preserve
				collapse (mean) share_be=man (sum) N = man if og_sector==`sect', by(beid withind)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) N = N, by(withind)
				gen sex="Men"
				gen subpop=`sect'
				order subpop, before(withind)
				save "${adir}/withinq_m_`sect'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_15", replace
			append using "${adir}/withinq_w_11" "${adir}/withinq_w_12" ///
			"${adir}/withinq_w_13" "${adir}/withinq_m_11" ///
			"${adir}/withinq_m_12" "${adir}/withinq_m_13" ///
			"${adir}/withinq_m_15"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def sect_lbl 11"Sector: Non-financial companies" ///
				12"Sector: Financial organizations" ///
				13"Sector: Governmental organizations" ///
				15"Sector: Non-governmental non-profit organizations", replace
			lab val subpop sect_lbl
	
			save "${adir}/withinq_sector_`year'", replace
	
			foreach sect of num 11 12 13 15 {
				erase "${adir}/withinq_w_`sect'.dta"
				erase "${adir}/withinq_m_`sect'.dta"	
			}
			*
		restore
		
		*********
		* By size
		*********
		foreach gksbs of num 1/7 {
			preserve
				collapse (mean) share_be=woman (sum) N = woman if be_gksbs==`gksbs', by(beid withind)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = N, by(withind)
				gen sex="Women"
				gen subpop=`gksbs'
				order subpop, before(withind)
				save "${adir}/withinq_w_`gksbs'", replace
			restore		
		}
		*
		foreach gksbs of num 1/7 {
			preserve
				collapse (mean) share_be=man (sum) N = man if be_gksbs==`gksbs', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) N = N, by(withind)
				gen sex="Men"
				gen subpop=`gksbs'
				order subpop, before(withind)
				save "${adir}/withinq_m_`gksbs'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_7", replace
			append using "${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2" ///
			"${adir}/withinq_m_3" "${adir}/withinq_m_4" ///
			"${adir}/withinq_m_5" "${adir}/withinq_m_6" ///
			"${adir}/withinq_m_7"
			
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def gksbs_lbl 1 "Size: 50-99 employees" 2 "Size: 100-149 employees" ///
				3 "Size: 150-199 employees" 4 "Size: 200-249 employees" 5 "Size: 250-499 employees" ///
				6 "Size: 500-999 employees" 7 "Size: 1000-1999 employees" 8 "Size: 2000+ employees", replace
			lab val subpop gksbs_lbl 
	
			save "${adir}/withinq_gksbs_`year'", replace
	
			foreach gksbs of num 1/7 {
				erase "${adir}/withinq_w_`gksbs'.dta"
				erase "${adir}/withinq_m_`gksbs'.dta"	
			}
			*
		restore
		
		***************
		* By legal form
		***************
		foreach legal of num 43 57 74 900 {
			preserve
				collapse (mean) share_be=woman (sum) N = woman if vep_legalform==`legal', by(beid withind)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = N, by(withind)
				gen sex="Women"
				gen subpop=`legal'
				order subpop, before(withind)
				save "${adir}/withinq_w_`legal'", replace
			restore		
		}
		*
		foreach legal of num 43 57 74 900  {
			preserve
				collapse (mean) share_be=man (sum) N = man if vep_legalform==`legal', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) N = N, by(withind)
				gen sex="Men"
				gen subpop=`legal'
				order subpop, before(withind)
				save "${adir}/withinq_m_`legal'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_900", replace
			append using "${adir}/withinq_w_43" "${adir}/withinq_w_57" ///
			"${adir}/withinq_w_74" ///
			"${adir}/withinq_m_43" "${adir}/withinq_m_57" ///
			"${adir}/withinq_m_74" "${adir}/withinq_m_900"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def legal_lbl 43 "Legal type: Besloten Vennootschap (bv)" ///
				57 "Legal type: Naamloze Vennootschap (nv)" 74 "Legal type: Stichting" ///
				900 "Legal type: Publiekrichtelijke instelling", replace
			lab val subpop legal_lbl 
	
			save "${adir}/withinq_legal_`year'", replace
	
			foreach legal of num 43 57 74 900 {
				erase "${adir}/withinq_w_`legal'.dta"
				erase "${adir}/withinq_m_`legal'.dta"	
			}
			*
		restore
		
		**************
		* By Ownership
		**************
		foreach owner of num 2 3 {
			preserve
				collapse (mean) share_be=woman (sum) N = woman if og_ownership==`owner', by(beid withind)
				gegen tot_woman = mean(share_be) 
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = N, by(withind)
				gen sex="Women"
				gen subpop=`owner'
				order subpop, before(withind)
				save "${adir}/withinq_w_`owner'", replace
			restore		
		}
		*
		foreach owner of num 2 3 {
			preserve
				collapse (mean) share_be=man (sum) N = man if og_ownership==`owner', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) N = N, by(withind)
				gen sex="Men"
				gen subpop=`owner'
				order subpop, before(withind)
				save "${adir}/withinq_m_`owner'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_3", replace
			append using "${adir}/withinq_w_2" ///
			"${adir}/withinq_m_2" "${adir}/withinq_m_3" 
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def owner_lbl 2 "Ownership: Domestic non-financial companies" ///
				3 "Ownership: Foreign non-financial companies", replace
			lab val subpop owner_lbl 
	
			save "${adir}/withinq_owner_`year'", replace
	
			foreach owner of num 2 3 {
				erase "${adir}/withinq_w_`owner'.dta"
				erase "${adir}/withinq_m_`owner'.dta"	
			}
			*
		restore
		
		**************
		* By Cao status
		**************
		foreach cao of num 0 1 2 {
			preserve
				collapse (mean) share_be=woman (sum) N = woman if cao==`cao', by(beid withind)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) N = N, by(withind)
				gen sex="Women" 
				gen subpop=`cao'
				order subpop, before(withind)
				save "${adir}/withinq_w_`cao'", replace
			restore		
		}
		*
		foreach cao of num 0 1 2 {
			preserve
				collapse (mean) share_be=man (sum) N = man if cao==`cao', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) N = N, by(withind)
				gen sex="Men"
				gen subpop=`cao'
				order subpop, before(withind)
				save "${adir}/withinq_m_`cao'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_2", replace
			append using "${adir}/withinq_w_0" ///
			"${adir}/withinq_w_1" "${adir}/withinq_m_0" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind sex
	
			lab def cao_lbl 0 "CAO: No collective agreement" ///
				1 "CAO: Sector-level collective agreement" ///
				2 "CAO: Firm-level collective agreement", replace
			lab val subpop cao_lbl 
	
			save "${adir}/withinq_cao_`year'", replace
	
			foreach cao of num 0 1 2 {
				erase "${adir}/withinq_w_`cao'.dta"
				erase "${adir}/withinq_m_`cao'.dta"	
			}
			*
		restore
		
	}
	*
	
	* Generate year variable
	foreach var in all industry sector gksbs legal owner cao {
		foreach year of num 2011/2023 {
			use "${adir}/withinq_`var'_`year'", replace
			gen year = `year'
			order year, before(withind)
			save  "${adir}/withinq_`var'_`year'", replace
		}
		*
	}
	*
	
	* Append yearly datasets
	foreach var in all industry sector gksbs legal owner cao {
		use "${adir}/withinq_`var'_2011", replace
		
		append using "${adir}/withinq_`var'_2012" ///
			"${adir}/withinq_`var'_2013" ///
			"${adir}/withinq_`var'_2014" ///
			"${adir}/withinq_`var'_2015" ///
			"${adir}/withinq_`var'_2016" ///
			"${adir}/withinq_`var'_2017" ///
			"${adir}/withinq_`var'_2018" ///
			"${adir}/withinq_`var'_2019" ///
			"${adir}/withinq_`var'_2020" ///
			"${adir}/withinq_`var'_2021" ///
			"${adir}/withinq_`var'_2022" ///
			"${adir}/withinq_`var'_2023"
			
		save "${adir}/withind_`var'_weighted", replace
		
		foreach year of num 2011/2023 {
			erase "${adir}/withinq_`var'_`year'.dta"
		}
		*
	}
	*
	
	* Fill missing of total average share of woman across quintiles
	foreach var in industry sector gksbs legal owner cao {
		use "${adir}/withind_`var'_weighted", replace
		
		egen tw = max(tot_woman), by(`var' year)
		replace tot_woman = tw if tot_woman==.
		drop tw 
		
		save "${adir}/withind_`var'_weighted", replace
	}
	*
	
	
* --------------------------------------------------------------------------- */
* 4. COMBINE FILES
* ---------------------------------------------------------------------------- *

	foreach var in all industry sector gksbs legal owner cao {
		
		use "${adir}/withind_`var'", replace
		
		gen wgt = "No"
		order wgt, before(year)
		capture order wgt, before(`var')
		
		append using "${adir}/withind_`var'_weighted"
		
		replace wgt = "Yes" if wgt==""
		
		save "${adir}/withind_`var'", replace
		
		erase "${adir}/withind_`var'_weighted.dta"
	
	}
	*
	
	* Generate percentage variable for tot_woman
	foreach var in all industry sector gksbs legal owner cao {
		
		use "${adir}/withind_`var'", replace
		gen pc_tw = round((tot_woman*100),.01)
		
		save "${adir}/withind_`var'", replace
	}
	*
	
	* Save subpop variable as string
	foreach var in industry sector gksbs legal owner cao {
		
		use "${adir}/withind_`var'", replace
		tostring subpop, replace
		
		save "${adir}/withind_`var'", replace
	}
	*
	
	* Combine in one file
	use "${adir}/withind_`var'", replace
	generate subpop = "Total population of large organizations"
	
	append using "${adir}/withind_industry" ///
		"${adir}/withind_sector" ///
		"${adir}/withind_gksbs" ///
		"${adir}/withind_legal" ///
		"${adir}/withind_owner" ///
		"${adir}/withind_cao"
		
	export excel using "${adir}/withind", firstrow(variables)