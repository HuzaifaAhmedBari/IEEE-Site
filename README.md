# IEEE Xtreme Membership Qualification

Simple dark-mode static registration page built with plain HTML, CSS, and vanilla JavaScript. The form collects a team name, one exact team VJudge ID, and exactly three participants, including each participant's name, NU email, and phone number.

## Setup

1. In Supabase, open **SQL Editor**, paste in [`registrations.sql`](registrations.sql), and run it.
2. Open [`config.js`](config.js) and replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` with the values from **Project Settings → API**.
3. Deploy the folder as a static site on Netlify, Vercel, GitHub Pages, or any static host. It can also be previewed by opening `index.html` directly; submissions remain disabled until real Supabase values are added.

The page loads Supabase JS v2 from jsDelivr. The anon key is intended for browser use; Row Level Security limits the public client to inserts only. View registrations from the Supabase dashboard.
