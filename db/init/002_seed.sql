\echo 'Seeding WTF LivePulse data...'
BEGIN;
SET LOCAL TIME ZONE 'Asia/Kolkata';
SET LOCAL synchronous_commit = OFF;

\echo 'Resetting seed tables...'
TRUNCATE TABLE checkins, payments, anomalies, members, gyms RESTART IDENTITY CASCADE;

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

CREATE TEMP TABLE tmp_seed_gyms AS
SELECT
  s.*,
  g.id AS gym_id,
  EXTRACT(HOUR FROM s.opens_at)::INTEGER AS open_hour,
  EXTRACT(MINUTE FROM s.opens_at)::INTEGER AS open_min,
  EXTRACT(HOUR FROM s.closes_at)::INTEGER AS close_hour_raw,
  EXTRACT(MINUTE FROM s.closes_at)::INTEGER AS close_min_raw,
  CASE
    WHEN EXTRACT(MINUTE FROM s.closes_at)::INTEGER = 0
      THEN EXTRACT(HOUR FROM s.closes_at)::INTEGER - 1
    ELSE EXTRACT(HOUR FROM s.closes_at)::INTEGER
  END AS close_hour,
  CASE
    WHEN EXTRACT(MINUTE FROM s.closes_at)::INTEGER = 0
      THEN 59
    ELSE EXTRACT(MINUTE FROM s.closes_at)::INTEGER
  END AS close_min
FROM tmp_gym_specs s
JOIN gyms g
  ON g.name = s.name;

\echo 'Seeding 5000 members...'
CREATE TEMP TABLE tmp_member_rows AS
WITH base AS (
  SELECT
    sg.*,
    gs AS seq,
    CASE
      WHEN gs <= sg.monthly_count THEN 'monthly'
      WHEN gs <= (sg.monthly_count + sg.quarterly_count) THEN 'quarterly'
      ELSE 'annual'
    END AS plan_type,
    CASE
      WHEN gs <= sg.active_count THEN 'active'
      WHEN gs <= (sg.active_count + sg.inactive_count) THEN 'inactive'
      ELSE 'frozen'
    END AS member_status
  FROM tmp_seed_gyms sg
  JOIN LATERAL generate_series(1, sg.member_count) gs ON TRUE
),
tagged AS (
  SELECT
    b.*,
    SUM(
      CASE WHEN b.plan_type IN ('monthly', 'quarterly') THEN 1 ELSE 0 END
    ) OVER (
      PARTITION BY b.gym_no
      ORDER BY b.seq DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS renewal_seq
  FROM base b
),
typed AS (
  SELECT
    t.*,
    CASE
      WHEN t.plan_type IN ('monthly', 'quarterly') AND t.renewal_seq <= t.renewal_count THEN 'renewal'
      ELSE 'new'
    END AS member_type
  FROM tagged t
),
joined AS (
  SELECT
    x.*,
    SUM(CASE WHEN x.member_type = 'new' THEN 1 ELSE 0 END) OVER (
      PARTITION BY x.gym_no
      ORDER BY x.seq
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS new_seq
  FROM typed x
)
SELECT
  j.*,
  CASE
    -- Salt Lake revenue-drop scenario: strong same-day-last-week payments
    WHEN j.gym_no = 9 AND j.seq IN (1,2,3,4,5,6,7,8,181,182) THEN
      date_trunc('day', NOW() - INTERVAL '7 days')
      + make_interval(hours => (9 + (j.seq % 4)), mins => ((j.seq * 7) % 60))
    -- Salt Lake today revenue intentionally low (<= 3000)
    WHEN j.gym_no = 9 AND j.seq = 9 THEN
      date_trunc('day', NOW()) + INTERVAL '00:10:00'
    WHEN j.member_type = 'renewal' AND j.plan_type = 'monthly' THEN
      NOW() - make_interval(
        days => (70 + FLOOR(random() * 71))::INTEGER,
        hours => FLOOR(random() * 18)::INTEGER,
        mins => FLOOR(random() * 60)::INTEGER
      )
    WHEN j.member_type = 'renewal' AND j.plan_type = 'quarterly' THEN
      NOW() - make_interval(
        days => (130 + FLOOR(random() * 91))::INTEGER,
        hours => FLOOR(random() * 18)::INTEGER,
        mins => FLOOR(random() * 60)::INTEGER
      )
    WHEN j.member_status = 'inactive' THEN
      NOW() - make_interval(
        days => (120 + FLOOR(random() * 61))::INTEGER,
        hours => FLOOR(random() * 18)::INTEGER,
        mins => FLOOR(random() * 60)::INTEGER
      )
    WHEN j.member_status = 'frozen' THEN
      NOW() - make_interval(
        days => (60 + FLOOR(random() * 91))::INTEGER,
        hours => FLOOR(random() * 18)::INTEGER,
        mins => FLOOR(random() * 60)::INTEGER
      )
    WHEN j.member_type = 'new' AND j.new_seq <= j.recent_new_count THEN
      NOW() - make_interval(
        days => (10 + FLOOR(random() * 21))::INTEGER,
        hours => FLOOR(random() * 18)::INTEGER,
        mins => FLOOR(random() * 60)::INTEGER
      )
    ELSE
      NOW() - make_interval(
        days => (31 + FLOOR(random() * 60))::INTEGER,
        hours => FLOOR(random() * 18)::INTEGER,
        mins => FLOOR(random() * 60)::INTEGER
      )
  END AS joined_at
FROM joined j;

CREATE TEMP TABLE tmp_name_seed AS
WITH named AS (
  SELECT
    mr.*,
    ROW_NUMBER() OVER (ORDER BY mr.gym_no, mr.seq) AS global_seq,
    (ARRAY[
      'Rahul','Aarav','Arjun','Kabir','Aditya','Rohan','Kunal','Ankit','Siddharth','Nikhil',
      'Vivek','Manish','Varun','Amit','Sanjay','Harsh','Yash','Ishaan','Pranav','Rajat',
      'Priya','Neha','Ananya','Sneha','Pooja','Aisha','Riya','Meera','Kavya','Nisha',
      'Isha','Divya','Ankita','Shreya','Radhika','Simran','Maya','Tanya','Aditi','Sana'
    ])[1 + ((mr.gym_no * 17 + mr.seq * 11) % 40)] AS first_name,
    (ARRAY[
      'Sharma','Verma','Patel','Gupta','Mehta','Nair','Reddy','Rao','Singh','Khan',
      'Kapoor','Mishra','Yadav','Chopra','Iyer','Das','Agarwal','Bose','Malhotra','Pillai',
      'Joshi','Chawla','Kulkarni','Jain','Bhat','Saxena','Pandey','Arora','Sethi','Bhattacharya',
      'Dutta','Menon','Chandra','Desai','Tiwari','Srivastava','Thakur','Bansal','Ghosh','Sinha'
    ])[1 + ((mr.gym_no * 19 + mr.seq * 7) % 40)] AS last_name
  FROM tmp_member_rows mr
)
SELECT
  n.*,
  (n.first_name || ' ' || n.last_name) AS full_name,
  LOWER(n.first_name || '.' || n.last_name || n.global_seq::TEXT || '@gmail.com') AS email,
  (
    CASE
      WHEN (n.global_seq % 3) = 0 THEN '9'
      WHEN (n.global_seq % 3) = 1 THEN '8'
      ELSE '7'
    END
    || LPAD((500000000 + n.global_seq)::TEXT, 9, '0')
  ) AS phone
FROM named n;

INSERT INTO members (
  gym_id, name, email, phone,
  plan_type, member_type, status,
  joined_at, plan_expires_at
)
SELECT
  ns.gym_id,
  ns.full_name,
  ns.email,
  ns.phone,
  ns.plan_type,
  ns.member_type,
  ns.member_status,
  ns.joined_at,
  CASE
    WHEN ns.member_type = 'renewal' AND ns.plan_type = 'monthly' THEN ns.joined_at + INTERVAL '60 days'
    WHEN ns.member_type = 'renewal' AND ns.plan_type = 'quarterly' THEN ns.joined_at + INTERVAL '180 days'
    WHEN ns.member_type = 'renewal' AND ns.plan_type = 'annual' THEN ns.joined_at + INTERVAL '730 days'
    WHEN ns.plan_type = 'monthly' THEN ns.joined_at + INTERVAL '30 days'
    WHEN ns.plan_type = 'quarterly' THEN ns.joined_at + INTERVAL '90 days'
    ELSE ns.joined_at + INTERVAL '365 days'
  END AS plan_expires_at
FROM tmp_name_seed ns
ORDER BY ns.gym_no, ns.seq;

\echo 'Seeding payments...'
INSERT INTO payments (member_id, gym_id, amount, plan_type, payment_type, paid_at)
SELECT
  m.id,
  m.gym_id,
  CASE m.plan_type
    WHEN 'monthly' THEN 1499
    WHEN 'quarterly' THEN 3999
    ELSE 11999
  END AS amount,
  m.plan_type,
  'new' AS payment_type,
  LEAST(
    NOW() - INTERVAL '1 minute',
    m.joined_at + make_interval(mins => ((FLOOR(random() * 11)::INTEGER) - 5))
  ) AS paid_at
FROM members m;

INSERT INTO payments (member_id, gym_id, amount, plan_type, payment_type, paid_at)
SELECT
  m.id,
  m.gym_id,
  CASE m.plan_type
    WHEN 'monthly' THEN 1499
    WHEN 'quarterly' THEN 3999
    ELSE 11999
  END AS amount,
  m.plan_type,
  'renewal' AS payment_type,
  CASE
    WHEN m.plan_type = 'monthly' THEN m.joined_at + INTERVAL '30 days'
    WHEN m.plan_type = 'quarterly' THEN m.joined_at + INTERVAL '90 days'
    ELSE m.joined_at + INTERVAL '365 days'
  END AS paid_at
FROM members m
WHERE m.member_type = 'renewal'
  AND m.plan_type IN ('monthly', 'quarterly')
  AND (
    CASE
      WHEN m.plan_type = 'monthly' THEN m.joined_at + INTERVAL '30 days'
      WHEN m.plan_type = 'quarterly' THEN m.joined_at + INTERVAL '90 days'
      ELSE m.joined_at + INTERVAL '365 days'
    END
  ) < NOW();

\echo 'Building churn-risk cohorts...'
CREATE TEMP TABLE tmp_churn_high AS
SELECT m.id AS member_id, m.gym_id
FROM members m
WHERE m.status = 'active'
ORDER BY random()
LIMIT 150;

CREATE TEMP TABLE tmp_churn_critical AS
SELECT m.id AS member_id, m.gym_id
FROM members m
WHERE m.status = 'active'
  AND NOT EXISTS (
    SELECT 1
    FROM tmp_churn_high h
    WHERE h.member_id = m.id
  )
ORDER BY random()
LIMIT 80;

\echo 'Seeding 90-day weighted check-ins (~270k)...'
CREATE TEMP TABLE tmp_member_pool AS
SELECT
  sg.gym_id,
  sg.open_hour,
  sg.open_min,
  sg.close_hour,
  sg.close_min,
  ARRAY_AGG(m.id) AS member_ids,
  COUNT(*)::INTEGER AS member_count
FROM tmp_seed_gyms sg
JOIN members m
  ON m.gym_id = sg.gym_id
 AND m.status = 'active'
WHERE NOT EXISTS (SELECT 1 FROM tmp_churn_high h WHERE h.member_id = m.id)
  AND NOT EXISTS (SELECT 1 FROM tmp_churn_critical c WHERE c.member_id = m.id)
GROUP BY sg.gym_id, sg.open_hour, sg.open_min, sg.close_hour, sg.close_min;

CREATE TEMP TABLE tmp_hour_template AS
SELECT
  h AS hour_of_day,
  CASE
    WHEN h BETWEEN 0 AND 4 THEN 0.00
    WHEN h = 5 THEN 0.30
    WHEN h = 6 THEN 0.60
    WHEN h BETWEEN 7 AND 9 THEN 1.00
    WHEN h BETWEEN 10 AND 11 THEN 0.40
    WHEN h BETWEEN 12 AND 13 THEN 0.30
    WHEN h BETWEEN 14 AND 16 THEN 0.20
    WHEN h BETWEEN 17 AND 20 THEN 0.90
    WHEN h = 21 THEN 0.35
    WHEN h = 22 THEN 0.35
    ELSE 0.00
  END::NUMERIC(8,4) AS base_weight
FROM generate_series(0, 23) h;

CREATE TEMP TABLE tmp_gym_hour_weights AS
WITH weighted AS (
  SELECT
    mp.gym_id,
    ht.hour_of_day,
    CASE
      WHEN ht.base_weight = 0 THEN 0::NUMERIC
      WHEN ht.hour_of_day < mp.open_hour OR ht.hour_of_day > mp.close_hour THEN 0::NUMERIC
      WHEN ht.hour_of_day = mp.open_hour AND mp.open_min > 0
        THEN ht.base_weight * ((60 - mp.open_min)::NUMERIC / 60)
      WHEN ht.hour_of_day = mp.close_hour AND mp.close_min < 59
        THEN ht.base_weight * ((mp.close_min + 1)::NUMERIC / 60)
      ELSE ht.base_weight
    END AS weight
  FROM tmp_member_pool mp
  CROSS JOIN tmp_hour_template ht
)
SELECT
  w.gym_id,
  w.hour_of_day,
  w.weight,
  SUM(w.weight) OVER (PARTITION BY w.gym_id ORDER BY w.hour_of_day) AS cum_weight,
  SUM(w.weight) OVER (PARTITION BY w.gym_id) AS total_weight
FROM weighted w;

CREATE TEMP TABLE tmp_event_base AS
WITH dow_multiplier AS (
  SELECT * FROM (VALUES
    (0, 0.45::NUMERIC),
    (1, 1.00::NUMERIC),
    (2, 0.95::NUMERIC),
    (3, 0.90::NUMERIC),
    (4, 0.95::NUMERIC),
    (5, 0.85::NUMERIC),
    (6, 0.70::NUMERIC)
  ) AS t(dow, multiplier)
),
day_targets AS (
  SELECT
    sg.gym_id,
    d::DATE AS day_date,
    GREATEST(
      0,
      ROUND(sg.base_daily * dm.multiplier * (0.92 + random() * 0.16))::INTEGER
    ) AS event_count
  FROM tmp_seed_gyms sg
  JOIN generate_series(CURRENT_DATE - INTERVAL '89 days', CURRENT_DATE - INTERVAL '1 day', INTERVAL '1 day') d ON TRUE
  JOIN dow_multiplier dm
    ON dm.dow = EXTRACT(DOW FROM d)::INTEGER
)
SELECT
  dt.gym_id,
  dt.day_date,
  random() AS r_hour,
  random() AS r_min,
  random() AS r_sec,
  random() AS r_member
FROM day_targets dt
JOIN LATERAL generate_series(1, dt.event_count) gs ON TRUE;

INSERT INTO checkins (member_id, gym_id, checked_in, checked_out)
SELECT
  mp.member_ids[1 + FLOOR(eb.r_member * mp.member_count)::INTEGER] AS member_id,
  eb.gym_id,
  ts.checked_in,
  ts.checked_in + make_interval(mins => (45 + FLOOR(random() * 46))::INTEGER) AS checked_out
FROM tmp_event_base eb
JOIN tmp_member_pool mp
  ON mp.gym_id = eb.gym_id
JOIN LATERAL (
  SELECT ghw.hour_of_day
  FROM tmp_gym_hour_weights ghw
  WHERE ghw.gym_id = eb.gym_id
    AND ghw.weight > 0
    AND ghw.cum_weight >= (eb.r_hour * ghw.total_weight)
  ORDER BY ghw.hour_of_day
  LIMIT 1
) hr ON TRUE
JOIN LATERAL (
  SELECT (
    eb.day_date::TIMESTAMPTZ
    + make_interval(
      hours => hr.hour_of_day,
      mins => (
        CASE
          WHEN hr.hour_of_day = mp.open_hour AND hr.hour_of_day = mp.close_hour THEN
            mp.open_min + FLOOR(eb.r_min * (mp.close_min - mp.open_min + 1))::INTEGER
          WHEN hr.hour_of_day = mp.open_hour THEN
            mp.open_min + FLOOR(eb.r_min * (60 - mp.open_min))::INTEGER
          WHEN hr.hour_of_day = mp.close_hour THEN
            FLOOR(eb.r_min * (mp.close_min + 1))::INTEGER
          ELSE
            FLOOR(eb.r_min * 60)::INTEGER
        END
      ),
      secs => FLOOR(eb.r_sec * 60)::INTEGER
    )
  ) AS checked_in
) ts ON TRUE;

\echo 'Seeding open check-ins for live occupancy...'
INSERT INTO checkins (member_id, gym_id, checked_in, checked_out)
SELECT
  candidate.member_id,
  candidate.gym_id,
  NOW() - make_interval(mins => FLOOR(random() * 90)::INTEGER) AS checked_in,
  NULL::TIMESTAMPTZ AS checked_out
FROM (
  SELECT
    m.id AS member_id,
    m.gym_id,
    ROW_NUMBER() OVER (PARTITION BY m.gym_id ORDER BY random()) AS rn
  FROM members m
  WHERE m.status = 'active'
    AND NOT EXISTS (SELECT 1 FROM tmp_churn_high h WHERE h.member_id = m.id)
    AND NOT EXISTS (SELECT 1 FROM tmp_churn_critical c WHERE c.member_id = m.id)
) candidate
JOIN tmp_seed_gyms sg
  ON sg.gym_id = candidate.gym_id
 AND sg.open_seed_count > 0
 AND candidate.rn <= sg.open_seed_count;

\echo 'Injecting churn-risk check-ins (150 HIGH, 80 CRITICAL)...'
INSERT INTO checkins (member_id, gym_id, checked_in, checked_out)
SELECT
  h.member_id,
  h.gym_id,
  old_checkin AS checked_in,
  old_checkin + make_interval(mins => (45 + FLOOR(random() * 46))::INTEGER) AS checked_out
FROM (
  SELECT
    member_id,
    gym_id,
    NOW()
      - make_interval(
          days => (50 + FLOOR(random() * 10))::INTEGER,
          hours => FLOOR(random() * 10)::INTEGER
        ) AS old_checkin
  FROM tmp_churn_high
) h;

INSERT INTO checkins (member_id, gym_id, checked_in, checked_out)
SELECT
  c.member_id,
  c.gym_id,
  old_checkin AS checked_in,
  old_checkin + make_interval(mins => (45 + FLOOR(random() * 46))::INTEGER) AS checked_out
FROM (
  SELECT
    member_id,
    gym_id,
    NOW()
      - make_interval(
          days => (65 + FLOOR(random() * 20))::INTEGER,
          hours => FLOOR(random() * 10)::INTEGER
        ) AS old_checkin
  FROM tmp_churn_critical
) c;

\echo 'Applying required anomaly scenarios...'
-- Scenario A: Velachery must have 0 open check-ins and last check-in > 2h10m
DELETE FROM checkins
WHERE gym_id = (SELECT gym_id FROM tmp_seed_gyms WHERE gym_no = 10)
  AND checked_in >= NOW() - INTERVAL '2 hours 10 minutes';

INSERT INTO checkins (member_id, gym_id, checked_in, checked_out)
SELECT
  m.id,
  sg.gym_id,
  NOW() - INTERVAL '2 hours 20 minutes',
  NOW() - INTERVAL '1 hour 20 minutes'
FROM tmp_seed_gyms sg
JOIN LATERAL (
  SELECT id
  FROM members
  WHERE gym_id = sg.gym_id
  ORDER BY random()
  LIMIT 1
) m ON TRUE
WHERE sg.gym_no = 10;

-- Ensure Salt Lake has 0-2 payments today (we keep exactly 1)
DELETE FROM payments
WHERE gym_id = (SELECT gym_id FROM tmp_seed_gyms WHERE gym_no = 9)
  AND paid_at >= date_trunc('day', NOW())
  AND paid_at < date_trunc('day', NOW()) + INTERVAL '1 day'
  AND id NOT IN (
    SELECT p.id
    FROM payments p
    JOIN members m ON m.id = p.member_id
    JOIN tmp_name_seed ns
      ON ns.gym_id = m.gym_id
     AND ns.email = m.email
    WHERE ns.gym_no = 9
      AND ns.seq = 9
    ORDER BY p.paid_at
    LIMIT 1
  );

\echo 'Updating member last_checkin_at...'
UPDATE members m
SET last_checkin_at = lc.max_checked_in
FROM (
  SELECT member_id, MAX(checked_in) AS max_checked_in
  FROM checkins
  GROUP BY member_id
) lc
WHERE lc.member_id = m.id;

\echo 'Refreshing analytics materialized view...'
REFRESH MATERIALIZED VIEW gym_hourly_stats;

ANALYZE gyms;
ANALYZE members;
ANALYZE checkins;
ANALYZE payments;
ANALYZE anomalies;

COMMIT;

\echo 'Seed complete. Validation snapshot:'
SELECT
  (SELECT COUNT(*) FROM gyms) AS gyms_count,
  (SELECT COUNT(*) FROM members) AS members_count,
  (SELECT COUNT(*) FROM checkins) AS checkins_count,
  (SELECT COUNT(*) FROM checkins WHERE checked_out IS NULL) AS open_checkins_count,
  (SELECT COUNT(*) FROM payments) AS payments_count,
  (
    SELECT COUNT(*)
    FROM members
    WHERE status = 'active'
      AND last_checkin_at < NOW() - INTERVAL '45 days'
  ) AS churn_risk_active_count;

