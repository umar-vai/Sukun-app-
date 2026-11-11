# Staging Quran editorial verification — 2026-10-14

**Scope:** 101 staging editorial records (srg2024-qur-*). No production data or patient records.

**Comparison:** All 99 records with an existing chapter:ayah reference were compared against 6,236 Arabic verses from nuqayah/quran-text (GitHub blob fcc214311897921d08bbc56879b82aa38328a5f3), with 114 chapter verse counts checked against semarketir/quranjson.

**Results:** 96/99 have approximate normalized substring agreement of 95% or more; another 2 are 94–95%; 1 is below 90% (srg2024-qur-099: 17:49). These are mechanical text matches, not a canonical/Quran.com editorial signoff. At least 15 records quote only part of a verse and must not be labeled complete ayahs.

**Unmapped:** srg2024-qur-001 and srg2024-qur-047 are introductory formula passages, not standalone Quran verse entries.

**21 missing end-of-range numbers:**
002=1:2–7; 003=2:1–5; 004=2:163–164; 006=2:285–286; 008=7:54–56; 009=59:21–24; 011=112:1–4; 012=113:1–5; 013=114:1–6; 015=55:33–36; 017=23:115–118; 018=37:1–10; 026=14:15–18; 027=14:49–50; 038=7:117–122; 048=19:1–9; 055=2:161–162; 056=2:190–193; 061=2:168–169; 076=84:1–5; 095=36:78–79.

**Caution:** The source text contains editorial verse decorations and orthographic variants. Do not automatically replace the source Arabic with a re-rendered verse. No record should be marked canonical verified or made public on similarity alone. srg2024-qur-015 was observed in status published, but staff_only visibility and pending verification; it is not public.

**State at time of audit:** Comparison completed; final Staging metadata writes and authenticated editorial verification are not confirmed. No claim of all 101 corrections completed.
