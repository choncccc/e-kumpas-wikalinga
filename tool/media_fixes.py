"""Per-recording fixes applied when clips are compressed for the app.

Keys are paths relative to the recordings folder; lesson clips use the same
path in both "E-Kumpas Wikalinga Videos" and "..._v2". Values may have:

  start: seconds to skip, e.g. the signer walking up after pressing record.
  end:   where to stop, in seconds of the original. Cuts off the signer
         turning, walking away or reaching for the camera once the sign is
         done.
  crop:  (left, right) or (left, right, top, bottom) fractions of the frame
         to cut off, for posters, wall charts, pillars and furniture at the
         edges, or to bring a small, far-away signer closer.

Found by reviewing every quiz clip frame by frame (Nov 2026). After changing
an entry, delete that clip's output in assets/signs/ or assets/quizzes/ so the
build scripts encode it again.
"""

FIXES = {
    # ---- Signer turns or walks out at the end ----
    'Hypertension Quiz/QUIZ NO. 2/Q#2. (B) I take medication_ Umiinom ako ng gamot.mov':
        {'end': 5.1},
    'Hypertension Quiz/QUIZ NO. 2/Q#3. (C) I don_t feel headache_ Hindi ako nakararamdam ng sakit ng ulo.mov':
        {'end': 6.6},
    'Hypertension Quiz/QUIZ NO. 2/Q#6. (A) Check blood pressure regularly_ Regular na suriin ang presyon ng dugo.mov':
        {'end': 5.3},
    'Hypertension Quiz/QUIZ NO. 2/Q#10. (A) Normal blood pressure_ Normal na presyon ng dugo.mov':
        {'end': 3.9},
    'Medical and Family Hx/Family Relationship/DOES ANYONE IN YOUR FAMILY HAVE HIGH BLOOD PRESSURE_ _ Meron bang may mataas na alta-presyon sa pamilya niyo__.mov':
        {'end': 9.6},
    'Procedures & Health Adv/Hypertension Prevention & Nursing Advice/Check your blood pressure regularly _ Regular na suriin ang blood pressure.mov':
        {'end': 6.2},
}

# ---- Wall chart, poster or pillar at the edge of the frame ----
# (left, right) widths, measured from a median background frame plus a
# small margin. Brown-wall clips flagged by the same scan were only stains
# and shadows, so they are left uncropped.
CROPS = {
    'Hypertension Quiz/QUIZ NO. 2/Q#1. (A) I have hypertension_ Ako ay may altapresyon.mov':
        (0.0, 0.025),
    'Hypertension Quiz/QUIZ NO. 2/Q#10. (A) Normal blood pressure_ Normal na presyon ng dugo.mov':
        (0.0, 0.037),
    'Hypertension Quiz/QUIZ NO. 2/Q#12. (B) Manage stress and rest_  Kontrolin ang stress at magpahinga.mov':
        (0.0, 0.028),
    'Hypertension Quiz/QUIZ NO. 2/Q#13. (A) Take blood test_ Magpasuri ng dugo.mov':
        (0.0, 0.018),
    'Hypertension Quiz/QUIZ NO. 2/Q#14. (A) Consult a doctor_ Kumonsulta sa doktor.mov':
        (0.0, 0.031),
    'Hypertension Quiz/QUIZ NO. 2/Q#15. (B) Stage 2 high blood pressure_ Ikalawang yugto ng mataas na presyon ng dugo.mov':
        (0.0, 0.062),
    'Hypertension Quiz/QUIZ NO. 2/Q#2. (B) I take medication_ Umiinom ako ng gamot.mov':
        (0.0, 0.021),
    'Hypertension Quiz/QUIZ NO. 2/Q#3. (C) I don_t feel headache_ Hindi ako nakararamdam ng sakit ng ulo.mov':
        (0.0, 0.021),
    'Hypertension Quiz/QUIZ NO. 2/Q#4. (A) Eat less salty food_ Kumain ng mas kaunting pagkaing maalat_.mov':
        (0.0, 0.025),
    'Hypertension Quiz/QUIZ NO. 2/Q#5. (C) Limit coffee and other drinks_ Limitahan ang pag-inom ng kape at iba pang inumin.mov':
        (0.0, 0.025),
    'Hypertension Quiz/QUIZ NO. 2/Q#6. (A) Check blood pressure regularly_ Regular na suriin ang presyon ng dugo.mov':
        (0.0, 0.025),
    'Hypertension Quiz/QUIZ NO. 2/Q#7. (A) Family has hypertension_ May altapresyon sa pamilya.mov':
        (0.0, 0.021),
    'Hypertension Quiz/QUIZ NO. 2/Q#9. (C) Exercise regularly_ Regular na mag-ehersisyo.mov':
        (0.0, 0.025),
    'Hypertension Quiz/Quiz 3/QUIZ 3_ 2. B. I DON_T TAKE ANY MEDICATIONS AS I ONLY HAVE 120_80 BP_.mov':
        (0.0, 0.018),
    'Hypertension Quiz/quiz 4/item 10-B. Stop Smoking and Vape.mov':
        (0.0, 0.034),
    'Hypertension Quiz/quiz 4/item 13-A. Do you have a severe headache__.mov':
        (0.0, 0.037),
    'Hypertension Quiz/quiz 4/item 5-B. Urinate First Before Checking Blood Pressure.mov':
        (0.0, 0.034),
    'Hypertension Quiz/quiz 4/item 6-A. Do you experience sudden chest pain__.mov':
        (0.0, 0.021),
    'Hypertension Quiz/quiz 4/item 8-B. Limit your caffeine intake.mov':
        (0.0, 0.037),
    'Procedures & Health Adv/Hypertension Prevention & Nursing Advice/Avoid drinking too much alcohol.mov':
        (0.034, 0.0),
    'Procedures & Health Adv/Hypertension Prevention & Nursing Advice/Check your blood pressure regularly _ Regular na suriin ang blood pressure.mov':
        (0.0, 0.071),
    'Procedures & Health Adv/Hypertension Prevention & Nursing Advice/Control Cholesterol and Sugar _ KONTROLIN ANG KOLESTEROL AT ANG ASUKAL SA DUGO.mov':
        (0.028, 0.0),
    'Procedures & Health Adv/Hypertension Prevention & Nursing Advice/Eat healthy foods _ KUMAIN NG MGA MASUSTANSIYANG PAGKAIN.mov':
        (0.0, 0.071),
    'Procedures & Health Adv/Hypertension Prevention & Nursing Advice/Take your medication on time _ INUMIN ANG GAMOT SA TAMANG ORAS.mov':
        (0.15, 0.0),
    'Procedures & Health Adv/Hypertension Prevention & Nursing Advice/Weight control_Healthy weight _ KONTROLIN ANG TIMBANG _ TAMANG TIMBANG.mov':
        (0.0, 0.043),
    'Procedures & Health Adv/Medical Procedures/Check Eyes, Vision Screening _ MAGPACHECK-UP NG MATA.mov':
        (0.0, 0.071),
    'Procedures & Health Adv/Medical Procedures/ECG.mov':
        (0.0, 0.031),
    'Procedures & Health Adv/Medical Procedures/Laboratory _ LABORATORYO.mov':
        (0.0, 0.031),
    'Procedures & Health Adv/Medical Procedures/Physical Examination _ PISIKAL NA PAGSUSURI.mov':
        (0.0, 0.062),
    'Procedures & Health Adv/Medical Procedures/Urine test _ PAGSUSURI SA IHI.mov':
        (0.0, 0.031),
}

for _path, _crop in CROPS.items():
    FIXES.setdefault(_path, {})['crop'] = _crop


# ---- Client request (Nov 2026): recorded selfie-style, so each starts with
# the signer walking back from the phone and ends with her reaching for it.
# Cut both, and crop the sides and bottom so she fills more of the frame and
# the bottle and clutter along the bottom edge are gone. Cut points were
# picked frame by frame; the crop keeps every handshape in view.
_SELFIE = (0.10, 0.10, 0.0, 0.08)
for _path, _start, _end in [
    ('Basic Sign Language (Foundation)/Time/once.MOV', 0.9, 6.0),
    ('Basic Sign Language (Foundation)/Time/twice.MOV', 0.9, 6.6),
    ('Basic Sign Language (Foundation)/Time/thrice.MOV', 0.9, 6.5),
    ('Med & Triage/heart.MOV', 1.0, 6.4),
    ('Med & Triage/how many days_.MOV', 0.9, 7.1),
    ('Med & Triage/Chief Complains/where does it hurt_.MOV', 0.9, 8.4),
    ('Med & Triage/Red-Flag Symptoms (Hypertension)/severe swelling of feet.MOV', 1.0, 10.8),
    ('Medical and Family Hx/Family Relationship/single.MOV', 0.9, 6.2),
    ('Medical and Family Hx/General Health History/do you have other illness_.MOV', 1.0, 8.7),
    ('Medical and Family Hx/Medications/are you taking your medicine for hpt_.MOV', 1.0, 12.7),
    ('Procedures & Health Adv/Hypertension Prevention & Nursing Advice/regular check up.MOV', 1.0, 7.3),
]:
    FIXES[_path] = {'start': _start, 'end': _end, 'crop': _SELFIE}

# Wall corner on the right; window frame and blue table at the left/bottom.
FIXES['Basic Sign Language (Foundation)/Time/Minute.mov'] = {'crop': (0.0, 0.07)}
for _path in [
    'Procedures & Health Adv/Pre-Measurment Instructions/Rest for 5 min _ MAGPAHINGA NG 5 MINUTO.mov',
    'Procedures & Health Adv/Pre-Measurment Instructions/Empty bladder _ urinate first _ UMIHI KA MUNA.mov',
]:
    FIXES[_path] = {'crop': (0.08, 0.0, 0.07, 0.09)}

# ---- Follow-up scan (2026-11-24) of every bundled clip's first and last
# frames for the same client request: signer still walking into frame or
# turning, laughing or walking out at the end. Times are in the original.
for _path, _fix in [
    ('Convo/Common Greetings & Introduction/Good Afternoon_ Magandang Hapon.mov',
     {'end': 4.7}),                     # turns her head away
    ('Basic Sign Language (Foundation)/Dates/Month_ Buwan.mov',
     {'start': 0.5}),                   # arm still coming up into frame
    ('Nutritional and Lifestyle Hx/Dietary Habits/prutas_fruits.MOV',
     {'end': 6.0}),                     # laughs, walks out, empty wall
    ('Nutritional and Lifestyle Hx/Vices & Risk Screening/Kape _ coffee.MOV',
     {'start': 0.5, 'end': 3.5}),       # arm enters late and drops early
    ('Procedures & Health Adv/Hypertension Prevention & Nursing Advice/Weight control_Healthy weight _ KONTROLIN ANG TIMBANG _ TAMANG TIMBANG.mov',
     {'end': 7.2}),                     # turns and reaches for the camera
    # Client's list (2026-11-24): Prutas, Gulay, Temperature, Fever, Why are
    # you here today, Check BP regularly, Weight control. The others on it
    # were already fixed above.
    ('Nutritional and Lifestyle Hx/Dietary Habits/gulay _ vegetable.MOV',
     {'end': 5.3}),                     # flings both arms out to the edges
    ('Med & Triage/Chief Complains/Why are you here today_ Bakit ka naparito_.mov',
     {'end': 6.1}),                     # bursts out laughing
    ('Med & Triage/Vital Signs/Temperature_ Temperatura.mov',
     {'end': 3.8}),                     # long idle tail, starts moving
    ('Med & Triage/Chief Complains/Fever_ Lagnat.mov',
     {'end': 5.6}),                     # idle tail, starts moving
]:
    FIXES.setdefault(_path, {}).update(_fix)
