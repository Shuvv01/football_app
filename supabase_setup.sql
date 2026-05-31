-- SHUVAM FC Supabase setup
-- Run this once in Supabase Dashboard > SQL Editor.
-- This demo setup allows public read/write through the anon key so your
-- in-app admin panel works without Google/Supabase Auth yet.
-- Before production, replace these grants with proper Supabase Auth + RLS.

create table if not exists players (
  id uuid primary key default gen_random_uuid(),
  number int not null,
  name text not null,
  position text not null,
  age int not null,
  created_at timestamptz default now(),
  unique (number)
);

create table if not exists matches (
  id uuid primary key default gen_random_uuid(),
  "homeTeam" text not null,
  "awayTeam" text not null,
  date text not null,
  time text not null,
  venue text not null,
  status text not null,
  competition text not null,
  result text default '',
  created_at timestamptz default now(),
  unique ("homeTeam", "awayTeam", date, time)
);

create table if not exists news (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  message text not null,
  detail text not null,
  created_at timestamptz default now(),
  unique (title)
);

create table if not exists updates (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text not null,
  created_at timestamptz default now(),
  unique (title)
);

create table if not exists formations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  style text not null,
  lines jsonb not null,
  created_at timestamptz default now(),
  unique (name)
);

create table if not exists members (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  "memberId" text not null,
  role text not null default 'member',
  "joinedAt" text not null,
  created_at timestamptz default now()
);

insert into players (number, name, position, age) values
(1, 'Ayush Giri', 'Goalkeeper', 23),
(4, 'Anil Neupane', 'Defender', 22),
(5, 'Suprim Rai', 'Defender', 22),
(8, 'Prashanna Bhattrai', 'Midfielder', 22),
(10, 'Shuvam Gautam', 'Midfielder', 22),
(9, 'Shri Manandhar', 'Forward', 22),
(11, 'Roshan Rijal', 'Forward', 21),
(21, 'Ishan Kafle', 'Forward', 23),
(13, 'Kamal Joshi', 'Forward', 23),
(12, 'Aasish Acharya', 'Forward', 22),
(19, 'Arpan B.K', 'Forward', 25)
on conflict do nothing;

insert into matches ("homeTeam", "awayTeam", date, time, venue, status, competition, result) values
('SHUVAM FC', 'Summit United', 'Sunday, June 2', '4:30 PM', 'Shuvam Arena', 'Upcoming', 'League', ''),
('SHUVAM FC', 'Valley Rangers', 'Saturday, June 8', '3:00 PM', 'City Stadium', 'Away', 'Cup', ''),
('Hill Stars', 'SHUVAM FC', 'Friday, June 14', '5:15 PM', 'Hill Ground', 'League', 'League', ''),
('SHUVAM FC', 'River Boys', 'Saturday, May 18', '4:00 PM', 'Shuvam Arena', 'Result', 'League', '3 - 1'),
('SHUVAM FC', 'Mountain City', 'Sunday, May 12', '2:30 PM', 'City Stadium', 'Result', 'Friendly', '2 - 2'),
('Green Valley', 'SHUVAM FC', 'Saturday, May 4', '5:00 PM', 'Valley Park', 'Result', 'Cup', '0 - 1')
on conflict do nothing;

insert into news (title, category, message, detail) values
('Training Schedule Updated', 'Training', 'Evening training starts at 5:30 PM every Monday, Wednesday, and Friday.', 'Players should arrive 15 minutes early for warm-up, hydration check, and tactical briefing.'),
('Home Match This Sunday', 'Match', 'SHUVAM FC hosts Summit United at Shuvam Arena this Sunday.', 'Supporters are encouraged to wear blue and green. Gates open one hour before kickoff.'),
('New Forward Joins Squad', 'Squad', 'SHUVAM FC welcomes young forward Anish Tamang to the senior team.', 'Anish brings pace, pressing, and confident finishing to the attacking unit.'),
('Community Coaching Day', 'Community', 'The club will host a free youth coaching session next weekend.', 'Young players can learn passing, movement, teamwork, and match basics from the SHUVAM FC squad.')
on conflict do nothing;

insert into updates (title, message) values
('Club Office Hours', 'The club office opens from 10 AM to 4 PM on training days.'),
('Kit Collection', 'Members can collect new blue-green kits after Friday training.')
on conflict do nothing;

insert into formations (name, style, lines) values
('4-3-3', 'Wide attack', '[["11 Roshan","9 Shri","21 Ishan"],["8 Prashanna","10 Shuvam","13 Kamal"],["4 Anil","5 Suprim","19 Arpan","12 Aasish"],["1 Ayush"]]'::jsonb),
('4-4-2', 'Balanced classic', '[["11 Roshan","9 Shri"],["21 Ishan","8 Prashanna","10 Shuvam","13 Kamal"],["4 Anil","5 Suprim","19 Arpan","12 Aasish"],["1 Ayush"]]'::jsonb),
('3-5-2', 'Midfield control', '[["11 Roshan","9 Shri"],["21 Ishan","8 Prashanna","10 Shuvam","13 Kamal","12 Aasish"],["4 Anil","5 Suprim","19 Arpan"],["1 Ayush"]]'::jsonb),
('4-2-3-1', 'Press and create', '[["9 Shri"],["11 Roshan","10 Shuvam","21 Ishan"],["8 Prashanna","13 Kamal"],["4 Anil","5 Suprim","19 Arpan","12 Aasish"],["1 Ayush"]]'::jsonb),
('5-3-2', 'Defensive wall', '[["11 Roshan","9 Shri"],["8 Prashanna","10 Shuvam","13 Kamal"],["4 Anil","5 Suprim","19 Arpan","12 Aasish","21 Ishan"],["1 Ayush"]]'::jsonb)
on conflict do nothing;

alter table players disable row level security;
alter table matches disable row level security;
alter table news disable row level security;
alter table updates disable row level security;
alter table formations disable row level security;
alter table members disable row level security;

grant select, insert, update, delete on players to anon;
grant select, insert, update, delete on matches to anon;
grant select, insert, update, delete on news to anon;
grant select, insert, update, delete on updates to anon;
grant select, insert, update, delete on formations to anon;
grant select, insert, update, delete on members to anon;
