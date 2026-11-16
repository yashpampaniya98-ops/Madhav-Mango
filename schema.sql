-- Madhav Mango Farm: run in Supabase SQL Editor
create table products(id uuid primary key default gen_random_uuid(),name text not null,grade text unique not null check(grade in('A1','A2','A3')),
 description_en text,description_gu text,price numeric check(price is null or price>=0),unit_weight int not null default 10 check(unit_weight=10),
 available boolean not null default true,active boolean not null default true,stock_note text,created_at timestamptz default now(),updated_at timestamptz default now());
create table product_images(id uuid primary key default gen_random_uuid(),product_id uuid references products on delete cascade,image_url text not null,display_order int default 0);
create table orders(id uuid primary key default gen_random_uuid(),customer_name text,phone text,address text,city text,district text,pincode text,note text,
 items jsonb,total_weight numeric,total_amount numeric,status text default 'new',created_at timestamptz default now());
create table site_settings(id int primary key default 1 check(id=1),shop_name text,tagline text,announcement text,primary_whatsapp text,secondary_whatsapp text,
 delivery_information text,hero_image_url text,about_en text,about_gu text,delivery_en text,delivery_gu text);
create table owners(user_id uuid primary key references auth.users);
create function is_owner() returns boolean language sql security definer stable set search_path=public as $$select exists(select 1 from owners where user_id=auth.uid())$$;
alter table products enable row level security;alter table product_images enable row level security;alter table orders enable row level security;
alter table site_settings enable row level security;alter table owners enable row level security;
create policy p_read on products for select using(active or is_owner());
create policy p_write on products for all using(is_owner()) with check(is_owner());
create policy i_read on product_images for select using(true);
create policy i_write on product_images for all using(is_owner()) with check(is_owner());
create policy s_read on site_settings for select using(true);
create policy s_write on site_settings for all using(is_owner()) with check(is_owner());
create policy o_read on orders for select using(is_owner());
create policy o_upd on orders for update using(is_owner());
-- customers cannot insert directly: orders go through place_order(), which recomputes totals from DB prices
create function place_order(p_name text,p_phone text,p_address text,p_city text,p_district text,p_pin text,p_note text,p_items jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare it jsonb;pr products;w numeric:=0;a numeric:=0;n int;lines jsonb:='[]';
begin
 if length(trim(p_name))<2 or p_phone !~ '^[6-9][0-9]{9}$' or p_pin !~ '^[0-9]{6}$' or length(trim(p_address))<5 then raise exception 'invalid details';end if;
 for it in select * from jsonb_array_elements(p_items) loop
  n:=(it->>'boxes')::int;
  select * into pr from products where grade=it->>'grade' and active and available and price is not null;
  if not found or n<1 or n>100 then raise exception 'unavailable item';end if;
  w:=w+n*pr.unit_weight;a:=a+n*pr.price;
  lines:=lines||jsonb_build_object('grade',pr.grade,'name',pr.name,'boxes',n,'price',pr.price);
 end loop;
 if jsonb_array_length(lines)=0 then raise exception 'empty order';end if;
 insert into orders(customer_name,phone,address,city,district,pincode,note,items,total_weight,total_amount)
 values(p_name,p_phone,p_address,p_city,p_district,p_pin,p_note,lines,w,a);
 return jsonb_build_object('total_weight',w,'total_amount',a);
end$$;
grant execute on function place_order to anon,authenticated;
insert into products(name,grade,description_en,description_gu) values
('A1 Premium','A1','Our highest quality grade of Kesar mangoes, sold in 10 kg boxes.','અમારી કેસર કેરીનો સર્વોચ્ચ ગુણવત્તાનો ગ્રેડ, 10 કિલોના બોક્સમાં.'),
('A2 Standard','A2','Our standard grade of Kesar mangoes, slightly below A1, sold in 10 kg boxes.','અમારી કેસર કેરીનો સ્ટાન્ડર્ડ ગ્રેડ, A1 કરતાં થોડો ઓછો, 10 કિલોના બોક્સમાં.'),
('A3 Value','A3','Our value grade of Kesar mangoes, slightly below A2, sold in 10 kg boxes.','અમારી કેસર કેરીનો વેલ્યુ ગ્રેડ, A2 કરતાં થોડો ઓછો, 10 કિલોના બોક્સમાં.');
insert into site_settings(shop_name,tagline,announcement,primary_whatsapp,secondary_whatsapp,about_en,about_gu,delivery_en,delivery_gu) values
('Madhav Mango Farm','Experience the Golden Goodness of Kesar','Fresh Kesar Mangoes Directly From Our Farm','919712306108','919879278980',
'Madhav Mango Farm offers Kesar mangoes directly from our own farm in Gujarat.','માધવ મેંગો ફાર્મ ગુજરાતમાં અમારા પોતાના ફાર્મમાંથી સીધી કેસર કેરી આપે છે.',
'We deliver across Gujarat. After you send your order on WhatsApp, we will confirm it and the delivery details with you.','અમે સમગ્ર ગુજરાતમાં ડિલિવરી કરીએ છીએ. તમે WhatsApp પર ઓર્ડર મોકલ્યા પછી અમે ઓર્ડર અને ડિલિવરીની વિગતો કન્ફર્મ કરીશું.');
insert into storage.buckets(id,name,public) values('product-images','product-images',true) on conflict do nothing;
create policy pi_read on storage.objects for select using(bucket_id='product-images');
create policy pi_write on storage.objects for all to authenticated using(bucket_id='product-images' and public.is_owner()) with check(bucket_id='product-images' and public.is_owner());
-- AFTER creating the owner user in Authentication > Users, run (with their real email):
-- insert into owners select id from auth.users where email='OWNER_EMAIL';
-- Then disable public sign-ups: Authentication > Providers > Email > turn off "Allow new users to sign up".
