#!/usr/bin/env python

import argparse


def main():

        p = argparse.ArgumentParser(prog='hginit.py')
            p.add_argument('--', help = 'optional start_date of abstracts')
                p.add_argument('--day_range',  help = 'optional range from start_date')
                    p.add_argument('--test_login', help = 'optional test login')
                        p.add_argument('--no_send',
                                                          help = 'optional do not send generated email'
                                                          )
                        args = p.parse_args(sys.argv[1:])
                        # make localdir

                        # hg init localdir

                        # edit localdir/.hg/hgrc to add default-push

                        # make remotedir

                        # hg init remotedir

                        # edit remotedir/.hg/hgrc to add email and web options
                        
