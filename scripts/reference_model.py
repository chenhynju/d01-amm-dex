#!/usr/bin/env python3
"""Independent rational AMM specification; deterministic generated differential vectors."""
from fractions import Fraction
from pathlib import Path
import random, json, argparse
ROOT=Path(__file__).resolve().parents[1]
def output(n,x,y):
    return (Fraction(y)*Fraction(n*997,x*1000+n*997)).numerator // (Fraction(y)*Fraction(n*997,x*1000+n*997)).denominator
def main():
    check=argparse.ArgumentParser()
    check.add_argument("--check",action="store_true")
    args=check.parse_args()
    rng=random.Random(20261105)
    rows=[]
    for i in range(10000):
        x=rng.randrange(1,2**112);y=rng.randrange(1,2**112);n=rng.randrange(1,2**112)
        out=output(n,x,y)
        assert 0<=out<y
        assert output(n+1,x,y)>=out
        assert (x*1000+n*997)*(y-out)>=x*y*1000
        # Tight floor: asking one more raw output unit violates the exact fee inequality.
        assert (x*1000+n*997)*(y-out-1)<x*y*1000
        if i<128: rows.extend([n,x,y,out])
    encoded="".join(v.to_bytes(32,"big").hex() for v in rows)
    source='''// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Test} from "forge-std/Test.sol";
import {Router} from "../src/Router.sol";
import {Factory} from "../src/Factory.sol";
contract DifferentialTest is Test {
    function testPythonRationalVectors() public {
        Router r=new Router(new Factory());
        bytes memory encoded=hex"%s";
        for(uint256 i;i<128;i++){
            uint256 n;uint256 x;uint256 y;uint256 expected;
            assembly {
                let ptr:=add(add(encoded,32),mul(i,128))
                n:=mload(ptr)
                x:=mload(add(ptr,32))
                y:=mload(add(ptr,64))
                expected:=mload(add(ptr,96))
            }
            assertEq(r.getAmountOut(n,x,y),expected);
        }
    }
}
''' % encoded
    target=ROOT/"test/Differential.t.sol"
    if args.check:
        assert ('hex"'+encoded+'"') in target.read_text(), "Generated vectors drifted"
    else: target.write_text(source)
    print(json.dumps({"status":"PASS","cases":10000,"differential_vectors":128,"seed":20261105}))
if __name__=="__main__":main()
