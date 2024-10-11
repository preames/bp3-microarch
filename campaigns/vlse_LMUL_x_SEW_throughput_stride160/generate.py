

import os
template = os.path.join(os.path.dirname(__file__), 'template.s')

with open(template, "r") as f:
    template = f.read()

    for SEW in ["e8", "e16", "e32", "e64"]:
        for LMUL in ["mf8", "mf4", "mf2", "m1", "m2", "m4", "m8"]:
            s = template;
            s = s.replace("PARAM_LMUL", LMUL);
            s = s.replace("PARAM_SEW", SEW);
            name = "vlse-" + SEW + "_" + LMUL + "_vlmax.s"
            print ("Generating " + name)
            with open(name, "w") as of:
                of.write(s);
