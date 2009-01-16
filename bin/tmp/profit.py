
refs = { 35 : 14, 100 : 40, 500 : 200 }

ref_click = 0.0125

for refcount, cost in refs.items():
    ads_per_day = 10
    gross_monthly = refcount * ads_per_day * 30 * ref_click
    net_monthly = gross_monthly - cost
    print refcount, "refs yields", net_monthly, "monthly profit", "for initial outlay of", cost
    


