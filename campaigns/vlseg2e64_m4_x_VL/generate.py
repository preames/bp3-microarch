

import os
template = os.path.join(os.path.dirname(__file__), 'template.s')

def is_valid_combination(SEW, LMUL):
    # Hard coded for VLEN=256 (i.e. bp3)
    if SEW == "e64":
        return LMUL != "m8";
    return True

with open(template, "r") as f:
    template = f.read()

    SEW = "e64"
    LMUL = "m4" # Should be m8, but hard to independent chains
    for VL in range(0, 31):
        s = template;
        s = s.replace("PARAM_VL", str(VL));
        s = s.replace("PARAM_LMUL", LMUL);
        s = s.replace("PARAM_SEW", SEW);
        name = "vlseg2e64-" + SEW + "_" + LMUL + "_vl" + str(VL) + ".s"
        print ("Generating " + name)
        with open(name, "w") as of:
            of.write(s);
