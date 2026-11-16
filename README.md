# Madhav Mango Farm: setup
1. Create a Supabase project. Run `schema.sql` in the SQL Editor.
2. Authentication > Users > Add user (the owner's email and password). Then run the `insert into owners ...` line at the bottom of schema.sql. Turn OFF public sign-ups.
3. Put your Project URL and **anon** key in `config.js` (never the service-role key).
4. Host the folder on any static host (Netlify, Vercel, Cloudflare Pages, GitHub Pages). Admin is at `/admin.html` (add a rewrite from `/admin` if you want that exact URL).
5. Log in at /admin, upload real mango photos for A1/A2/A3, set prices, and paste a hero photo URL (upload one to the product-images bucket).
Security: RLS limits all writes to the `owners` table's user; orders are created only through `place_order()`, which recomputes totals from DB prices.
