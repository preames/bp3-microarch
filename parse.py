
import sys
import os

fname = sys.argv[1]
assert(os.path.exists(fname))

active = None
results = {}
with open(fname, "r") as f:
    for line in f.readlines():
        if line.startswith("Running"):
            active = line[len("Running "):].strip()
            continue;
        if "cycles-per-inst" in line:
            num = line.strip().split(" ")[0]
            if "." in num:
                # Incorrect rounding..
                num = num[0:num.find(".") + 3]
                pass
            if num == "nan":
                num = ""
#            print (active)
#            print (num)
            LMUL = None
            SEW = None
            for key in active.replace('-', '_').split("_"):
                if key in ["mf8", "mf4", "mf2", "m1", "m2", "m4", "m8"]:
                    LMUL = key
                    continue
                if key in ["e8", "e16", "e32", "e64"]:
                    SEW = key
                    continue
                pass
            assert(SEW != None and LMUL != None)
            if active.startswith("vlseg"):
                NF = active[5:6];
                if sys.argv[2] and NF != sys.argv[2]:
                    continue
                pass
            if LMUL not in results:
                results[LMUL] = {}
            results[LMUL][SEW] = num
            continue
        pass
    pass
print (results)
                

import pandas as pd

df = pd.DataFrame.from_dict(results)
df = df.reindex(['e8', 'e16', 'e32', 'e64'])
df = df.reindex(columns=["mf8", "mf4", "mf2", "m1", "m2", "m4", "m8"])

print(df.to_markdown(index=True))
