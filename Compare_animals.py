import os
os.chdir('/Users/davidprotter/Documents/Donaldson Lab/Don_Git/Cleversys Scripts')
import random
from Cleversys_Parser import parse
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
df, ani = parse("/Volumes/SamsungT5/Results/Short Term PPT_4_TCR.TXT")
import pandas as pd

huddle_novel = len(df.loc[df['huddle_novel'] >0.5]) / 29.97
huddle_partner = len(df.loc[df['huddle_partner'] >0.5]) / 29.97
plt.bar([0,1],[huddle_novel,huddle_partner])
def assemble_names(directory, suppress_output = True, only_fresh = False):
    '''return a list of paths to files to parse'''
    os.chdir(directory)

    #create an empty 2d list
    out_names = []

    #this will assemble a list of ALL filenames for images, sorted by timestamp of acquisition


    for root, dirs, files in os.walk(directory):
        out = [os.path.join(root, f) for f in sorted(files) if f.endswith('TCR.TXT') if not f.startswith('.')]
        out_names += out
    return out_names

names = assemble_names('/Volumes/SamsungT5/Results')
names

pp ={}

hp = []
hn = []
for name in names:
    df, ani = parse(name)
    huddle_novel = len(df.loc[df['huddle_novel'] >0.5]) / 29.97
    huddle_partner = len(df.loc[df['huddle_partner'] >0.5]) / 29.97
    pp[ani] = {'hp':huddle_partner, 'hn':huddle_novel, 'norm_pref' : huddle_partner / (huddle_partner + huddle_novel)}
    hp.append(huddle_partner)
    hn.append(huddle_novel)


hpx = [(0 + random.random())/4 for _ in range(16)]
hnx = [1+(0 + random.random())/4 for _ in range(16)]
plt.plot(hpx, hp, '.')
plt.plot(hnx, hn, '.')
plt.title('Partner Preference: 2week Cohab')
plt.xlabel('huddle time')
plt.ylabel(['Partner', 'Novel'])

sns.boxplot(x=[0,1], y = [hp,hn])

for k in pp.keys():
    plt.plot(pp[k]['norm_pref'], '.')
    if pp[k]['norm_pref'] <0.6:
        print(k)
df = pd.DataFrame.from_dict(pp, orient='index')

sns.stripplot(data = df, y = 'norm_pref' )
df



# total huddle time.
plt.plot(np.asarray(hpx)/5, np.asarray(hp)+np.asarray(hn), '.')
plt.ylim(0,8000)
plt.xlim(-0.05,0.1)
