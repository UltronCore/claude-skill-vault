# EDC Vegas Notion Trip OS Skill

## Purpose
Create, maintain, QA, and continuously improve a shared Notion trip operating system for an EDC Las Vegas / Vegas vacation. This skill is designed for Claude, ChatGPT, and Codex handoff workflows where research, planning, Notion databases, and GitHub documentation need to stay aligned.

## When to use
Use this skill when the user asks to plan a Las Vegas, EDC, festival, creator, couple, or multi-day travel project in Notion. Trigger strongly when the request includes any of these words or concepts:

- EDC, Las Vegas, Vegas, festival, rave, pool party, club, casino, hotel, itinerary
- Notion base, Notion workspace, dashboard, tracker, CRM, database
- Mariana, Bryan, couple trip, outfits, restaurants, events, things to buy
- brand outreach, PR outreach, emails, DMs, creator collabs
- research in background, update later, keep improving, GitHub copy, Claude pickup, Codex pickup

## Operating rules
1. Build first, then refine.
2. Do not wait for perfect research if the user asks to create the Notion now.
3. Create a clean base with placeholder rows, then replace placeholders with verified research as it becomes available.
4. Keep private details out of public GitHub files. Do not commit confirmation numbers, personal emails, payment methods, account numbers, or private reservation PDFs to public repos.
5. Store personal/private trip details only in Notion or private docs when the user explicitly wants them there.
6. Every researched venue, restaurant, event, shuttle detail, or policy should have a source in the research notes before it is treated as final.
7. For dates far in the future, mark event/lineup/nightlife details as provisional until official sources confirm them.
8. Keep language practical, direct, and useful. Avoid over-polished AI travel fluff.

## Required Notion structure
Create a main dashboard page and the following databases.

### Main dashboard page
Recommended title: `EDC + Vegas Trip Hub`

Include:
- trip dates
- hotel and reservation overview when provided by the user
- quick links to all databases
- next actions
- private sharing note before inviting another person
- questions still needed
- research status
- update log

### Database: Day-by-Day Trip Plan
Purpose: one row per trip day.

Properties:
- Day — title
- Date — date
- Day Type — multi-select: Travel, Vegas, Pool, EDC, Club, Casino, Recovery, Shopping, Content
- Main Plan — text
- Morning — text
- Afternoon — text
- Evening — text
- Late Night — text
- Reservation / Ticket Status — select: Not needed, Need to book, Booked, Waitlist, Canceled
- Transportation — text
- Bryan Outfit — text
- Mariana Outfit — text
- Content Ideas — text
- Budget Estimate — dollar number
- Actual Spend — dollar number
- Notes — text

### Database: Email + DM Outreach Tracker
Purpose: track brand, venue, hotel, restaurant, PR, and creator outreach.

Properties:
- Contact / Brand — title
- Category — select: Brand PR, Hotel, Restaurant, Club, Pool Party, Event, Creator Collab, Travel, Other
- Platform — select: Email, Instagram DM, TikTok DM, Website Form, Phone, Other
- Contact Name — text
- Email — email
- Profile / Website — URL
- Status — select: Need to contact, Draft ready, Sent, Follow up, Interested, Confirmed, Declined, No response
- Date Sent — date
- Follow Up Date — date
- Priority — select: High, Medium, Low
- Owner — select: Bryan, Mariana, Both
- Notes — text

### Database: Outfit Planner
Purpose: plan every look by person, day, event, cost, comfort, and packing status.

Properties:
- Outfit — title
- Person — select: Bryan, Mariana, Both / Matching
- Use Case — multi-select: Travel, EDC, Pool, Pool Party, Club, Casino, Restaurant, Shopping, Content, Recovery
- Day / Event — text
- Status — select: Idea, Need to buy, Ordered, Delivered, Needs return, Packed, Worn
- Top — text
- Bottom — text
- Shoes — text
- Accessories — text
- Bag — text
- Weather Notes — text
- Comfort Risk — select: Low, Medium, High
- Cost — dollar number
- Purchase Link — URL
- Photo / Inspo — URL
- Notes — text

### Database: Shopping + Stuff to Buy
Purpose: purchase tracker for clothes, luggage, travel gear, toiletries, tech, festival supplies, and last-minute needs.

Properties:
- Item — title
- Category — select: Outfit, EDC Gear, Travel Gear, Luggage, Toiletries, Tech, Medicine, Food / Snacks, Beauty, Other
- For — select: Bryan, Mariana, Both
- Status — select: Idea, Need to buy, Ordered, Delivered, Packed, Return, Skip
- Priority — select: Must have, Should have, Nice to have
- Needed By — date
- Store / Brand — text
- Link — URL
- Estimated Cost — dollar number
- Actual Cost — dollar number
- Notes — text

### Database: Restaurants + Food List
Purpose: track restaurants, casual food, brunch, desserts, late-night food, and recovery food.

Properties:
- Place — title
- Cuisine / Type — text
- Meal — multi-select: Breakfast, Brunch, Lunch, Dinner, Dessert, Late Night, Recovery Food, Drinks
- Location / Casino — text
- Priority — select: Must try, Strong option, Maybe
- Status — select: Idea, Need reservation, Reserved, Visited, Skip
- Reservation Date — date
- Price Level — select: $, $$, $$$, $$$$
- Must Order — text
- Link — URL
- TikTok / IG Saved — checkbox
- Notes — text

### Database: Events + Nightlife + EDC Planner
Purpose: track EDC, pool parties, clubs, casino nightlife, brand events, shows, and pop-ups.

Properties:
- Event — title
- Event Type — select: EDC, Pool Party, Club, Casino, Show, Restaurant Event, Brand Event, Free Event, Other
- Date — date
- Venue — text
- Status — select: Research, Interested, Need tickets, Booked, Waitlist, Skip
- Priority — select: Must do, Strong option, Maybe
- Cost Estimate — dollar number
- Ticket / RSVP Link — URL
- Dress Code — text
- Transportation Notes — text
- Artist / Host — text
- Set / Time — text
- Notes — text

### Database: Packing List + Travel Logistics
Purpose: checklist for flight, hotel, EDC, outfits, documents, medicine, transportation, tech, and emergency prep.

Properties:
- Task / Item — title
- Section — select: Documents, Hotel, Flight, EDC, Outfits, Toiletries, Tech, Medicine, Snacks, Transportation, Money, Emergency, Other
- Owner — select: Bryan, Mariana, Both
- Status — select: Not started, In progress, Done, Packed, Issue
- Due Date — date
- Needed For — text
- Location Packed — text
- Confirmation / Detail — text
- Cost — dollar number
- Notes — text

### Database: Budget + Expense Tracker
Purpose: estimate and reconcile spend before, during, and after the trip.

Properties:
- Expense — title
- Category — select: Hotel / Resort Fees, Flights, Food, Drinks, EDC, Club, Pool Party, Outfits, Shopping, Transportation, Gambling, Emergency, Other
- Date — date
- Who Paid — select: Bryan, Mariana, Both
- Status — select: Estimated, Planned, Paid, Refund Needed, Canceled
- Estimated Cost — dollar number
- Actual Cost — dollar number
- Payment Method — text
- Receipt / Link — URL
- Notes — text

### Database: Places to Go + Photo Spots
Purpose: track casinos, attractions, hidden gems, shopping, lounges, content spots, and free activities.

Properties:
- Place — title
- Type — multi-select: Casino, Photo Spot, Attraction, Shopping, Hotel, Lounge, Hidden Gem, Content Spot, Free, Other
- Area — text
- Priority — select: Must go, Strong option, Maybe
- Status — select: Idea, Planned, Visited, Skip
- Best Time — text
- Outfit Notes — text
- Cost Estimate — dollar number
- Link — URL
- Notes — text

## Starter row logic
If the user provides hotel dates, create one day row per date. For an EDC trip, assume a pattern like:
- arrival / check-in day
- one or two Vegas setup days
- EDC nights
- recovery day
- checkout day

Do not treat exact EDC schedule, artists, shuttles, or nightlife as final until verified.

## Research workflow
Use official and high-quality sources first:
1. Official EDC / Insomniac pages
2. Official hotel pages and reservation confirmation uploaded by the user
3. Official club / pool party / venue pages
4. Official restaurant reservation pages
5. Venue social media only when official websites are stale
6. Creator/TikTok/social recommendations only as ideas, not facts

For future dates, research should produce:
- what is confirmed now
- what is likely but not confirmed
- when to check again
- what should be added to Notion now as placeholders

## QA checklist
Before finishing, verify:
- each database exists
- every trip date has a day row
- placeholders are clearly marked
- private data is not pushed to public GitHub
- hotel check-in/check-out details match the user-provided confirmation if present
- budget includes resort fees, transport, food, outfits, clubs, pool parties, EDC, shopping, gambling, and emergency fund
- outfit categories include travel, non-EDC, EDC, pool, pool party, club, casino, restaurant, recovery
- outreach tracker includes follow-up dates and owner fields
- research updates are logged after every major revision

## Handoff prompt for Claude or Codex
Continue the EDC Vegas Notion Trip OS. Use the Notion page as the source of truth for private details. Use GitHub only for reusable public-safe skills, schemas, prompts, and QA checklists. Do not commit personal reservation details or payment/account information. First audit the existing Notion databases, then add missing rows, improve views, add source-backed research, and update the dashboard with a concise change log. Mark anything unverified as provisional.

## Output format
End every run with:

### Updates Made
- Notion changes
- GitHub changes
- Research added
- Items still needing user input

### Next Best Moves
- 3 to 7 concrete next actions
