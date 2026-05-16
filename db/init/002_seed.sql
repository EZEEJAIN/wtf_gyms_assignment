\echo 'Seeding WTF LivePulse data...'
BEGIN;
SET LOCAL TIME ZONE 'Asia/Kolkata';
SET LOCAL synchronous_commit = OFF;

\echo 'Resetting seed tables...'
TRUNCATE TABLE lead_master RESTART IDENTITY CASCADE;

\echo 'Seeding gyms...'
CREATE TEMP TABLE tmp_gym_specs (
  gym_no INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  city TEXT NOT NULL,
  capacity INTEGER NOT NULL,
  opens_at TIME NOT NULL,
  closes_at TIME NOT NULL,
  member_count INTEGER NOT NULL,
  monthly_count INTEGER NOT NULL,
  quarterly_count INTEGER NOT NULL,
  annual_count INTEGER NOT NULL,
  active_count INTEGER NOT NULL,
  inactive_count INTEGER NOT NULL,
  frozen_count INTEGER NOT NULL,
  renewal_count INTEGER NOT NULL,
  recent_new_count INTEGER NOT NULL,
  base_daily INTEGER NOT NULL,
  open_seed_count INTEGER NOT NULL
);

INSERT INTO tmp_gym_specs (
  gym_no, name, city, capacity, opens_at, closes_at,
  member_count, monthly_count, quarterly_count, annual_count,
  active_count, inactive_count, frozen_count,
  renewal_count, recent_new_count, base_daily, open_seed_count
)
VALUES
  (1,  U&'WTF Gyms \2014 Lajpat Nagar',      'New Delhi', 220, '05:30', '22:30', 650, 325, 195, 130, 572, 52, 26, 130, 72, 470, 7),
  (2,  U&'WTF Gyms \2014 Connaught Place',   'New Delhi', 180, '06:00', '22:00', 550, 220, 220, 110, 468, 55, 27, 110, 60, 398, 6),
  (3,  U&'WTF Gyms \2014 Bandra West',       'Mumbai',    300, '05:00', '23:00', 750, 300, 300, 150, 675, 50, 25, 150, 98, 543, 280),
  (4,  U&'WTF Gyms \2014 Powai',             'Mumbai',    250, '05:30', '22:30', 600, 240, 240, 120, 522, 52, 26, 120, 78, 434, 8),
  (5,  U&'WTF Gyms \2014 Indiranagar',       'Bengaluru', 200, '05:30', '22:00', 550, 220, 220, 110, 490, 40, 20, 110, 66, 398, 6),
  (6,  U&'WTF Gyms \2014 Koramangala',       'Bengaluru', 180, '06:00', '22:00', 500, 200, 200, 100, 430, 47, 23, 100, 55, 362, 5),
  (7,  U&'WTF Gyms \2014 Banjara Hills',     'Hyderabad', 160, '06:00', '22:00', 450, 225, 135,  90, 378, 48, 24,  90, 45, 326, 5),
  (8,  U&'WTF Gyms \2014 Sector 18 Noida',   'Noida',     140, '06:00', '21:30', 400, 240, 100,  60, 328, 48, 24,  80, 52, 290, 3),
  (9,  U&'WTF Gyms \2014 Salt Lake',         'Kolkata',   120, '06:00', '21:00', 300, 180,  90,  30, 240, 40, 20,  60, 30, 217, 3),
  (10, U&'WTF Gyms \2014 Velachery',         'Chennai',   110, '06:00', '21:00', 250, 150,  75,  25, 195, 37, 18,  50, 28, 181, 0);

INSERT INTO gyms (name, city, capacity, opens_at, closes_at, status)
SELECT
  name,
  city,
  capacity,
  opens_at,
  closes_at,
  'active'
FROM tmp_gym_specs
ORDER BY gym_no;

