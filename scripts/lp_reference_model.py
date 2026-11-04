#!/usr/bin/env python3
"""Independent arbitrary-precision LP issuance/redemption model and fixed differential vectors."""
from pathlib import Path
import random,math,json,argparse
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument("--check",action="store_true");args=parser.parse_args()
rng=random.Random(2026110502);rows=[]
for i in range(10000):
    a0=rng.randrange(10**15,10**24);a1=rng.randrange(10**15,10**24)
    d0=rng.randrange(10**15,10**24);d1=rng.randrange(10**15,10**24)
    supply=math.isqrt(a0*a1)
    lp=min(d0*supply//a0,d1*supply//a1)
    assert supply*supply<=a0*a1<(supply+1)**2
    assert lp*a0<=d0*supply and lp*a1<=d1*supply
    b0=lp*(a0+d0)//(supply+lp);b1=lp*(a1+d1)//(supply+lp)
    assert b0<=a0+d0 and b1<=a1+d1
    if i<16:rows.extend([a0,a1,d0,d1,supply,lp,b0,b1])
encoded="".join(v.to_bytes(32,"big").hex() for v in rows)
source='''// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Test} from "forge-std/Test.sol";
import {MockToken} from "./AMM.t.sol";
import {Pair} from "../src/Pair.sol";
contract LPReferenceTest is Test {
    struct Case {uint256 a0;uint256 a1;uint256 d0;uint256 d1;uint256 supply;uint256 lp;uint256 burn0;uint256 burn1;}
    function testPythonLPIssuanceAndBurn() public {
        Case[16] memory cases=abi.decode(hex"%s",(Case[16]));
        for(uint256 i;i<16;i++) _check(cases[i]);
    }
    function _check(Case memory c) private {
        MockToken x=new MockToken("X");MockToken y=new MockToken("Y");
        (MockToken a,MockToken b)=address(x)<address(y)?(x,y):(y,x);
        Pair pair=new Pair(address(a),address(b));
        a.mint(address(pair),c.a0);b.mint(address(pair),c.a1);
        assertEq(pair.mint(address(this)),c.supply-1000);
        a.mint(address(pair),c.d0);b.mint(address(pair),c.d1);
        address bob=address(0xB0B);
        assertEq(pair.mint(bob),c.lp);
        assertEq(pair.totalSupply(),c.supply+c.lp);
        vm.prank(bob);pair.transfer(address(pair),c.lp);
        (uint256 out0,uint256 out1)=pair.burn(bob);
        assertEq(out0,c.burn0);assertEq(out1,c.burn1);
        assertEq(a.balanceOf(bob),c.burn0);assertEq(b.balanceOf(bob),c.burn1);
        assertEq(pair.totalSupply(),c.supply);
    }
}
''' % encoded
target=root/"test/LPReference.t.sol"
if args.check:assert ('hex"'+encoded+'"') in target.read_text(),"LP vectors drifted"
else:target.write_text(source)
print(json.dumps({"status":"PASS","cases":10000,"differential_vectors":16,"seed":2026110502}))
