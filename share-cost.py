#!/usr/bin/env python

import argh



def main(spend, sharecost, gainpercentage=5):
    spend = float(spend)
    sharecost = float(sharecost)

    shares_to_buy = int(spend / sharecost)

    print "To spend {} with shares costing {} you should buy {}".format(
        spend, sharecost, shares_to_buy)

    profit_point = sharecost * (gainpercentage / 100.0) + sharecost

    print "For a {} percent gain place your stop limit at {}".format(
        gainpercentage, profit_point)

if __name__ == '__main__':
    argh.dispatch_command(main)
