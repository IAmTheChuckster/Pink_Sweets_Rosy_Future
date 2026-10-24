#!/usr/bin/env python3
"""
Pink Sweets Rosy Future - u4 patcher (Python 3, standard library only)

    python3 pinkswts_patch.py pinkswts.zip          -> writes pinkswts_u4 next to the zip
    python3 pinkswts_patch.py pinkswts.zip --zip    -> also writes pinkswts_patched.zip
    python3 pinkswts_patch.py pinkswts_u4           -> writes pinkswts_u4_patched
    python3 pinkswts_patch.py pinkswts.zip -o OUT   -> choose the output file

Original u4 CRC32 5d812c9e -> patched 2b1d0fb1. The game program is LZ-compressed,
so it is unpacked, patched and repacked (takes about a minute). No Cave code is stored here.
"""
import argparse, base64, os, sys, zipfile, zlib
ORIG_CRC, PATCHED_CRC, U4_SIZE = 0x5D812C9E, 0x2B1D0FB1, 0x200000
BLOB, BASE, HOOK = 0x51000, 0x0C051000, 0x100000
PROGRAM = [
    ("0c0720ec", "a0100000", "0c078f80"),
    ("0c06e64a", "d002400b0009a0130009a010049800090009000900090009000900090009000900090009000900090009000900090009", "d24d6020c933"),
    ("0c0754a0", "d001402b00090009a01006f0", "d525992e605304bc0b97d018"),
    ("0c1066f4", "20202050494e4b2053574545545320524f535920465554555245202020200020202020202020202043415645204f574e5321212120202020202020202000202020202020202020202020202020202020202020202020202020202020002020202020202020202020202020202020202020202020202020202020200020202020202020202020202020202020202020202020202020202020202000202020202020202020202020202020202020202020202020202020202020002020202020202020202020202020202020202020202020202020202020200020202020202020202020202020202020202020202020202020202020202000202020202020202020202020202020202020202020202020202020202020002020202020202020202020202020202020202020202020202020202020200020202020202020202020202020202020202020202020202020202020202000202020202020202020202020202020202020202020202020202020202020002020202020202020202020202020202020202020202020202020202020200020202020323032362f31302f313520524f5359204655545552452020202000", ""),
    ("0c1068a6", "20202050494e4b2053574545545320524f535920465554555245202020200020202020202020202043415645204f574e5321212120202020202020202000202020202020202020202020202020202020202020202020202020202020002020202020202020202020202020202020202020202020202020202020200020202020202020202020202020202020202020202020202020202020202000202020202020202020202020202020202020202020202020202020202020002020202020202020202020202020202020202020202020202020202020200020202020202020202020202020202020202020202020202020202020202000202020202020202020202020202020202020202020202020202020202020002020202020202020202020202020202020202020202020202020202020200020202020202020202020202020202020202020202020202020202020202000202020202020202020202020202020202020202020202020202020202020002020202020202020202020202020202020202020202020202020202020200020202020323032362f31302f313520524f5359204655545552452020202000", ""),
    ("0c0703d2", "0009", "430b"),
    ("0c0703e2", "0009", "4a0b"),
    ("0c0703f0", "0009", "480b"),
]
HOOK_CODE = base64.b64decode(
    "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"
    "DDrkkwxJyJQMB1VsDAdUrAxKIYgMScXc"
)

def unpack(b):
    n=int.from_bytes(b[0:4],"big"); nt=int.from_bytes(b[4:8],"big")
    fp=12; dp=int.from_bytes(b[8:12],"big"); out=bytearray(); bits=0; fl=0
    for _ in range(nt):
        if bits==0: fl=b[fp]; fp+=1; bits=8
        if fl&0x80:
            w=(b[dp]<<8)|b[dp+1]; dp+=2; d=w>>5
            for _ in range((w&31)+3): out.append(out[-d])
        else: out.append(b[dp]); dp+=1
        fl=(fl<<1)&0xFF; bits-=1
    if len(out)!=n: raise ValueError("program unpacked to the wrong size")
    return bytes(out), dp

def pack(data, maxd=2047, maxl=34):
    n=len(data); head={}; matches=[None]*n
    for i in range(n):
        best=[]
        if i+3<=n:
            lst=head.setdefault(data[i:i+3],[]); bl=0; mx=min(maxl,n-i)
            for j in reversed(lst):
                d=i-j
                if d>maxd: break
                l=3
                while l<mx and data[j+l]==data[i+l]: l+=1
                if l>bl: bl=l; best.append((l,d))
                if l==maxl: break
            lst.append(i)
            if len(lst)>4096: del lst[:2048]
        matches[i]=best
    cost=[0]*(n+1); ch=[None]*n
    for i in range(n-1,-1,-1):
        c=cost[i+1]+9; b=(1,0); prev=3
        for l,d in matches[i]:
            for L in range(prev,l+1):
                cc=cost[i+L]+17
                if cc<c: c=cc; b=(L,d)
            prev=l+1
        cost[i]=c; ch[i]=b
    flags=[]; st=bytearray(); i=0
    while i<n:
        L,d=ch[i]
        if d==0: st.append(data[i]); flags.append(0); i+=1
        else: w=(d<<5)|(L-3); st+=bytes([w>>8,w&255]); flags.append(1); i+=L
    fb=bytearray((len(flags)+7)//8)
    for k,f in enumerate(flags):
        if f: fb[k>>3]|=0x80>>(k&7)
    return n.to_bytes(4,"big")+len(flags).to_bytes(4,"big")+(12+len(fb)).to_bytes(4,"big")+bytes(fb)+bytes(st)

def swap(b):
    o=bytearray(len(b)); o[0::2]=b[1::2]; o[1::2]=b[0::2]; return o

def apply_patch(data):
    if len(data)!=U4_SIZE: raise ValueError("u4 is %d bytes, expected %d" % (len(data),U4_SIZE))
    c=zlib.crc32(data)&0xFFFFFFFF
    if c==PATCHED_CRC: raise ValueError("this u4 is already patched")
    if c!=ORIG_CRC: raise ValueError("u4 CRC is %08x, expected the original 5d812c9e" % c)
    be=swap(data); print("unpacking program...")
    game,end=unpack(bytes(be[BLOB:])); game=bytearray(game)
    for a,new,exp in PROGRAM:
        o=int(a,16)-BASE; e=bytes.fromhex(exp)
        if game[o:o+len(e)]!=e: raise ValueError("unexpected bytes at "+a)
        nb=bytes.fromhex(new); game[o:o+len(nb)]=nb
    print("packing program (about a minute)...")
    blob=pack(bytes(game))
    if len(blob)>end: raise ValueError("packed program does not fit")
    be[BLOB:BLOB+len(blob)]=blob; be[BLOB+len(blob):BLOB+end]=b"\xff"*(end-len(blob))
    if any(x!=0xFF for x in be[HOOK:HOOK+len(HOOK_CODE)]): raise ValueError("free space is not empty")
    be[HOOK:HOOK+len(HOOK_CODE)]=HOOK_CODE
    out=bytes(swap(be)); c=zlib.crc32(out)&0xFFFFFFFF
    if c!=PATCHED_CRC: raise ValueError("patched CRC is %08x, expected 2b1d0fb1" % c)
    return out

def main():
    ap=argparse.ArgumentParser(description="Patch Pink Sweets u4 (Rosy Future)")
    ap.add_argument("input"); ap.add_argument("-o","--output"); ap.add_argument("--zip",action="store_true")
    a=ap.parse_args(); name=None
    if zipfile.is_zipfile(a.input):
        with zipfile.ZipFile(a.input) as z:
            name=next((n for n in z.namelist() if os.path.basename(n).lower() in ("pinkswts_u4","u4")),None)
            if not name: sys.exit("no pinkswts_u4 in "+a.input)
            data=z.read(name)
        dflt=os.path.join(os.path.dirname(os.path.abspath(a.input)),os.path.basename(name))
    else:
        if a.zip: sys.exit("--zip needs a zip as input")
        data=open(a.input,"rb").read(); dflt=a.input+"_patched"
    try: out=apply_patch(data)
    except ValueError as e: sys.exit("error: %s" % e)
    dst=a.output or dflt; open(dst,"wb").write(out); print("wrote %s (CRC 2b1d0fb1)" % dst)
    if a.zip:
        zd=os.path.join(os.path.dirname(os.path.abspath(a.input)),"pinkswts_patched.zip")
        with zipfile.ZipFile(a.input) as zi, zipfile.ZipFile(zd,"w",zipfile.ZIP_DEFLATED) as zo:
            for i in zi.infolist(): zo.writestr(i, out if i.filename==name else zi.read(i.filename))
        print("wrote "+zd)

if __name__=="__main__": main()
