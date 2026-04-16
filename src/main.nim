import board
import options
import strutils

let sgfs = [
  "(;GM[1]FF[3]AB[rd][rc][qc][pc][oc][nc][pb][oa]AW[mb][nb][ob][mc][nd][od][pd][qd][re][qf]PL[W]C[White to play and kill.]AP[MultiGo:3.9.3]SZ[19] (; W[sd](; B[rb]; W[qa]; B[pa]; W[sc]; B[sb]; W[ra])(; B[ra]; W[sb]; B[sc](; W[pa])(; W[rb]))( ; B[sc]; W[pa]))(; W[rb]TR[rb]; B[sb]; W[ra]; B[sd])(; W[ra]TR[ra]; B[sd]; W[sb]; B[rb]; W[qa]; B[pa])) ",
  "(;GM[1]FF[4]SZ[19]PB[芝野虎丸]BR[九段]PW[一力遼]WR[九段]KM[6.5]RE[W+R]DT[2025-05-14]GN[第80期本因坊戦挑戦手合五番勝負第1局];B[pd];W[dd];B[pq];W[dp];B[fq];W[qc];B[qd];W[pc];B[od];W[nb];B[ql];W[lp];B[cn];W[dn];B[dm];W[en];B[co];W[cp];B[iq];W[eq];B[fp];W[do];B[np];W[ck];B[cc];W[cd];B[dc];W[ed];B[fb];W[dl];B[jo];W[kn];B[jn];W[km];B[ko];W[lo];B[mn];W[ln];B[mm];W[jm];B[im];W[il];B[hm];W[jk];B[dj];W[cj];B[dh];W[fh];B[fj];W[hl];B[gm];W[gl];B[fg];W[gg];B[eg];W[fc];B[gb];W[gh];B[fe];W[gf];B[ee];W[ge];B[fd];W[ec];B[eb];W[gc];B[gd];W[hc];B[hd];W[ic];B[ie];W[kd];B[jf];W[lf];B[hj];W[jh];B[lg];W[kf];B[jg];W[kg];B[ih];W[gj];B[gk];W[ii];B[ji];W[kh];B[hi];W[gi];B[fk];W[ig];B[ij];W[if];B[je];W[hk];B[ki];W[li];B[hf];W[hg];B[he];W[hh];B[eh];W[ii];B[em];W[cm];B[ih];W[bc];B[ii];W[kj];B[fi];W[bb];B[nc];W[mb];B[mj];W[lj];B[rc];W[rb];B[re];W[sc];B[rd];W[oc];B[nh];W[qo];B[qq];W[qk];B[rk];W[pl];B[rl];W[pk];B[nk];W[qi];B[rj];W[on];B[no];W[oi];B[ni];W[og];B[ng];W[rg];B[qh];W[ph];B[qg];W[qf];B[nf];W[ri];B[qj];W[pj];B[rn];W[qn];B[qm];W[pm];B[md];W[ro]) ",
]
