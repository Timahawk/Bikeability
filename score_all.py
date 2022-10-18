import csv
import os
from os.path import exists
from subprocess import Popen


with open('stadtliste.csv', newline='', encoding="utf-8") as csvfile:
    stadt = csv.reader(csvfile, delimiter=';', quotechar='|')
    next(stadt)
    for row in stadt:
        if len(row) == 6: # -> berechnet ist nein
            os.environ["cityname"] = row[0]
            os.environ["schemaname"] = row[1]
            os.environ["file"] = row[5]
            # print("Next City: ", row[0])
            # p = Popen("batchscript.bat", cwd=r"D:\Master\Masterarbeit\brouter_caller", env=dict(os.environ))
            # stdout, stderr = p.communicate()

            if exists(row[5]):
                print("Next City: ", row[0], ", File Vorhanden")

                p = Popen("batchscript.bat", cwd=r"D:\Master\Masterarbeit\brouter_caller", env=dict(os.environ))
                stdout, stderr = p.communicate()
                # pass
            else:
                print("Next City: ", row[0],", File fehlt ", row[5] )

            # break