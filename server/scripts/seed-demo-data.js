/*
 * Idempotently seeds production-shaped demo data for one already-existing user.
 *
 * Credentials are intentionally supplied at runtime only. This script never
 * creates users, never deletes records, and refuses to run without an explicit
 * --confirm-demo-seed acknowledgement.
 *
 * Examples:
 *   $env:DEMO_SEED_EMAIL = 'you@example.com'
 *   node scripts/seed-demo-data.js --confirm-demo-seed --password-stdin
 *   # Type the password when prompted; it is not echoed or logged.
 */

const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '.env') });

const { connectDb } = require('../src/config/db');
const User = require('../src/models/User');
const Client = require('../src/models/Client');
const Event = require('../src/models/Event');
const Payment = require('../src/models/Payment');
const Expense = require('../src/models/Expense');
const Deliverable = require('../src/models/Deliverable');
const MonthlySummary = require('../src/models/MonthlySummary');
const { Invoice } = require('../src/models/Invoice');

const argv = new Set(process.argv.slice(2));
const email = String(process.env.DEMO_SEED_EMAIL || '').trim().toLowerCase();

function fail(message) {
  throw new Error(message);
}

function dateAt(daysFromToday, hour = 10) {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() + daysFromToday);
  date.setHours(hour, 0, 0, 0);
  return date;
}

function monthOffset(offset) {
  const date = new Date();
  date.setDate(1);
  date.setHours(12, 0, 0, 0);
  date.setMonth(date.getMonth() + offset);
  return { year: date.getFullYear(), month: date.getMonth() + 1 };
}

function promptPassword() {
  return new Promise((resolve, reject) => {
    process.stdout.write('Target account password: ');
    const input = process.stdin;
    let answer = '';
    const onData = (chunk) => {
      for (const code of chunk) {
        if (code === 3) {
          cleanup();
          reject(new Error('Seed cancelled.'));
          return;
        }
        if (code === 13 || code === 10) {
          cleanup();
          process.stdout.write('\n');
          resolve(answer);
          return;
        }
        if (code === 127 || code === 8) {
          answer = answer.slice(0, -1);
        } else if (code >= 32) {
          answer += String.fromCharCode(code);
        }
      }
    };
    const cleanup = () => {
      input.off('data', onData);
      if (input.isTTY) input.setRawMode(false);
      input.pause();
    };
    if (input.isTTY) input.setRawMode(true);
    input.resume();
    input.on('data', onData);
  });
}

async function upsert(model, filter, values) {
  return model.findOneAndUpdate(
    filter,
    { $set: values },
    { upsert: true, new: true, runValidators: true, setDefaultsOnInsert: true },
  );
}

function sum(items) {
  return items.reduce((total, item) => total + Number(item.amount || 0), 0);
}

async function seed(user) {
  const userId = user._id;
  const clients = [
    ['Aanya Sharma', '9000001001', 'aanya.sharma+demo@clients-hub.example', 'Bride and groom prefer warm, candid coverage.'],
    ['Rohan Mehta', '9000001002', 'rohan.mehta+demo@clients-hub.example', 'Engagement portraits with a relaxed editorial finish.'],
    ['Kavya Iyer', '9000001003', 'kavya.iyer+demo@clients-hub.example', 'Pre-wedding story across the old city and lakeside.'],
    ['Northwind Atelier', '9000001004', 'campaigns+demo@northwind-atelier.example', 'Commercial campaign; deliver web, print, and social crops.'],
    ['Mira Desai', '9000001005', 'mira.desai+demo@clients-hub.example', 'Family portrait session with grandparents included.'],
    ['Ishaan & Tara', '9000001006', 'ishaan.tara+demo@clients-hub.example', 'Full wedding weekend with album and highlight film.'],
    ['Veda Kapoor', '9000001007', 'veda.kapoor+demo@clients-hub.example', 'Heritage wedding; coordinate with venue production team.'],
    ['The Nair Family', '9000001008', 'nair.family+demo@clients-hub.example', 'Newborn portraits and a small framed print set.'],
    ['Bluebird Homeware', '9000001009', 'studio+demo@bluebird-homeware.example', 'Product editorial for a festive home collection.'],
    ['Arjun & Leela', '9000001010', 'arjun.leela+demo@clients-hub.example', 'Anniversary portrait session at sunset.'],
  ];
  const clientDocs = {};
  for (const [name, phone, clientEmail, notes] of clients) {
    const doc = await upsert(Client, { userId, email: clientEmail }, {
      userId, name, phone, email: clientEmail, address: 'Demo contact · India', notes,
      status: name === 'Northwind Atelier' || name === 'Bluebird Homeware' ? 'comingUp' : 'information',
    });
    clientDocs[name] = doc;
  }

  const eventSpecs = [
    ['Aanya Sharma', 'Aanya & Dev — Garden Wedding', 'Wedding', 45, 'The Courtyard Gardens, Jaipur', 280000, 'Two-camera coverage, sunset portraits, and a 90-second teaser.', ['Ceremony coverage', 'Candid photographs', 'Wedding album', 'Highlight video']],
    ['Rohan Mehta', 'Rohan & Siya — Engagement Portraits', 'Engagement', 20, 'Cubbon Park, Bengaluru', 65000, 'Golden-hour portraits with a short vertical reel for invitations.', ['Engagement portraits', 'Retouched gallery', 'Vertical teaser']],
    ['Kavya Iyer', 'Kavya & Aditya — Monsoon Pre-wedding', 'Pre-wedding', 7, 'Fort Kochi & Vypin Beach, Kochi', 90000, 'Early call time; rain covers and backup indoor location confirmed.', ['Pre-wedding photographs', 'Digital gallery', 'Highlight reel']],
    ['Northwind Atelier', 'Northwind Atelier — Festive Collection', 'Commercial', 12, 'Indiranagar Studio, Bengaluru', 175000, 'Product, lifestyle, and detail frames for the festive catalogue.', ['Campaign stills', 'Social media crops', 'Colour-graded masters']],
    ['Mira Desai', 'Mira Desai — Family Portraits', 'Portrait', 3, 'Lalbagh Botanical Garden, Bengaluru', 32000, 'Four generations; prioritize group combinations before noon.', ['Family portraits', 'Fine-art retouching', 'Print-ready files']],
    ['Ishaan & Tara', 'Ishaan & Tara — Lakeside Wedding', 'Wedding', -12, 'The Lakeview Estate, Udaipur', 240000, 'Delivered wedding coverage with album proof approved by the couple.', ['Wedding coverage', 'Wedding album', 'Highlight video', 'Digital gallery']],
    ['Veda Kapoor', 'Veda Kapoor — Heritage Wedding', 'Wedding', -45, 'Rambagh Courtyard, Jaipur', 310000, 'Three-day wedding story; final gallery delivered in October.', ['Full wedding coverage', 'Full-length video', 'Wedding album', 'Digital gallery']],
    ['The Nair Family', 'The Nair Family — Newborn Portraits', 'Portrait', -22, 'Lumen Studio, Bengaluru', 42000, 'Quiet morning session; wooden print box selected.', ['Newborn portraits', 'Edited photographs', 'Framed print set']],
    ['Bluebird Homeware', 'Bluebird Homeware — Editorial Catalogue', 'Commercial', -65, 'Whitefield Loft Studio, Bengaluru', 125000, 'Catalogue delivered with web and print colour profiles.', ['Product stills', 'Editorial set', 'Retouched masters']],
    ['Arjun & Leela', 'Arjun & Leela — Anniversary Portraits', 'Portrait', -80, 'Sanjay Van, New Delhi', 48000, 'Sunset session delivered with a small keepsake gallery.', ['Portrait session', 'Edited photographs', 'Digital gallery']],
  ];
  const eventDocs = {};
  for (const [clientName, title, eventType, day, location, totalAmount, notes, receiptItems] of eventSpecs) {
    const startsAt = dateAt(day, day < 0 ? 16 : 9);
    const endsAt = new Date(startsAt.getTime() + (eventType === 'Wedding' ? 8 : 4) * 60 * 60 * 1000);
    const status = day < 0 ? 'completed' : day <= 3 ? 'paymentDue' : 'upcoming';
    const event = await upsert(Event, { userId, title }, {
      userId, clientId: clientDocs[clientName]._id, title, eventType, startsAt, endsAt,
      startTime: day < 0 ? '04:00 PM' : '09:00 AM', endTime: day < 0 ? '11:00 PM' : '05:00 PM',
      location, status, totalAmount, paymentTotal: 0, notes, receiptItems,
    });
    eventDocs[title] = event;
  }

  const paymentSpecs = [
    ['Aanya & Dev — Garden Wedding', [['Booking advance', 140000, 30, 'upi'], ['Second instalment', 60000, 5, 'bankTransfer']]],
    ['Rohan & Siya — Engagement Portraits', [['Booking advance', 32500, 10, 'upi']]],
    ['Kavya & Aditya — Monsoon Pre-wedding', [['Booking advance', 45000, -2, 'upi']]],
    ['Northwind Atelier — Festive Collection', [['Creative retainer', 87500, -6, 'bankTransfer']]],
    ['Mira Desai — Family Portraits', [['Session advance', 16000, -1, 'card']]],
    ['Ishaan & Tara — Lakeside Wedding', [['Booking advance', 100000, -80, 'bankTransfer'], ['Second instalment', 80000, -30, 'upi'], ['Final settlement', 60000, -13, 'card']]],
    ['Veda Kapoor — Heritage Wedding', [['Booking advance', 120000, -120, 'bankTransfer'], ['Second instalment', 100000, -75, 'upi'], ['Final settlement', 90000, -46, 'cash']]],
    ['The Nair Family — Newborn Portraits', [['Session advance', 22000, -35, 'upi'], ['Balance payment', 20000, -22, 'cash']]],
    ['Bluebird Homeware — Editorial Catalogue', [['Project retainer', 62500, -90, 'bankTransfer'], ['Final settlement', 62500, -66, 'bankTransfer']]],
    ['Arjun & Leela — Anniversary Portraits', [['Session advance', 24000, -90, 'upi'], ['Balance payment', 24000, -80, 'card']]],
  ];
  const paymentsByEvent = {};
  for (const [title, payments] of paymentSpecs) {
    const event = eventDocs[title];
    paymentsByEvent[title] = [];
    for (const [paymentTitle, amount, day, method] of payments) {
      const payment = await upsert(Payment, { userId, eventId: event._id, title: paymentTitle }, {
        userId, eventId: event._id, title: paymentTitle, amount, paidAt: dateAt(day, 12), method,
        reference: `DEMO-${event._id.toString().slice(-6)}-${paymentTitle.replace(/\W/g, '').slice(0, 8).toUpperCase()}`,
      });
      paymentsByEvent[title].push(payment);
    }
    await Event.updateOne({ _id: event._id, userId }, { $set: { paymentTotal: sum(paymentsByEvent[title]) } });
  }

  const expenseSpecs = [
    ['Aanya & Dev — Garden Wedding', [['Second photographer', 28000, 'Freelancer', 35], ['Album printing deposit', 24000, 'Album printing', 28], ['Travel and stay', 18000, 'Travel', 40]]],
    ['Rohan & Siya — Engagement Portraits', [['Location permit and assistant', 5500, 'Venue', 17], ['Local travel', 3200, 'Travel', 18]]],
    ['Kavya & Aditya — Monsoon Pre-wedding', [['Freelance cinematographer', 12000, 'Freelancer', 4], ['Travel and permits', 9000, 'Travel', 5]]],
    ['Northwind Atelier — Festive Collection', [['Lighting equipment rental', 18000, 'Equipment rental', 10], ['Stylist and set dressing', 22000, 'Decorations', 9], ['Studio day rental', 15000, 'Venue', 11]]],
    ['Mira Desai — Family Portraits', [['Assistant photographer', 4500, 'Freelancer', 1], ['Garden permit', 1800, 'Venue', 2]]],
    ['Ishaan & Tara — Lakeside Wedding', [['Second photographer', 24000, 'Freelancer', -80], ['Album printing', 38000, 'Album printing', -20], ['Travel and accommodation', 26000, 'Travel', -78], ['Drone equipment rental', 12000, 'Equipment rental', -14]]],
    ['Veda Kapoor — Heritage Wedding', [['Second shooter team', 42000, 'Freelancer', -120], ['Album and prints', 46000, 'Album printing', -65], ['Venue production', 18000, 'Venue', -46], ['Intercity travel', 28000, 'Travel', -115]]],
    ['The Nair Family — Newborn Portraits', [['Props and wraps', 3800, 'Decorations', -34], ['Fine-art printing', 6200, 'Album printing', -20]]],
    ['Bluebird Homeware — Editorial Catalogue', [['Lighting rental', 14000, 'Equipment rental', -91], ['Set decoration', 8500, 'Decorations', -89], ['Freelance retoucher', 18000, 'Freelancer', -62]]],
    ['Arjun & Leela — Anniversary Portraits', [['Local travel', 2800, 'Travel', -89], ['Print order', 4200, 'Album printing', -78]]],
  ];
  for (const [title, expenses] of expenseSpecs) {
    const event = eventDocs[title];
    for (const [expenseTitle, amount, category, day] of expenses) {
      await upsert(Expense, { userId, eventId: event._id, title: expenseTitle }, {
        userId, eventId: event._id, title: expenseTitle, amount, category, incurredAt: dateAt(day, 13),
      });
    }
  }

  const deliverableSpecs = [
    ['Aanya & Dev — Garden Wedding', [['Edited photographs', 'Editing', false], ['Wedding album', 'Album', false], ['Highlight video', 'Video', false], ['Digital gallery', 'Delivery', false]]],
    ['Ishaan & Tara — Lakeside Wedding', [['Edited photographs', 'Editing', true], ['Wedding album', 'Album', true], ['Highlight video', 'Video', true], ['Full-length video', 'Video', false], ['Digital gallery', 'Delivery', true]]],
    ['Veda Kapoor — Heritage Wedding', [['Edited photographs', 'Editing', true], ['Wedding album', 'Album', true], ['Full-length video', 'Video', true], ['Digital gallery', 'Delivery', true]]],
    ['Northwind Atelier — Festive Collection', [['Campaign stills', 'Editing', true], ['Social media crops', 'Delivery', true], ['Colour-graded masters', 'Delivery', false]]],
    ['The Nair Family — Newborn Portraits', [['Edited photographs', 'Editing', true], ['Wooden print box', 'Prints', false]]],
  ];
  for (const [title, deliverables] of deliverableSpecs) {
    const event = eventDocs[title];
    for (const [deliverableTitle, stage, isCompleted] of deliverables) {
      await upsert(Deliverable, { userId, eventId: event._id, title: deliverableTitle }, {
        userId, eventId: event._id, title: deliverableTitle, stage, isCompleted,
        completedAt: isCompleted ? dateAt(-3, 18) : null,
      });
    }
  }

  const invoiceSpecs = [
    ['DEMO-INV-001', 'Aanya & Dev — Garden Wedding', 'Aanya Sharma', 280000, 200000, 38],
    ['DEMO-INV-002', 'Rohan & Siya — Engagement Portraits', 'Rohan Mehta', 65000, 32500, 12],
    ['DEMO-INV-003', 'Northwind Atelier — Festive Collection', 'Northwind Atelier', 175000, 87500, 20],
    ['DEMO-INV-004', 'Ishaan & Tara — Lakeside Wedding', 'Ishaan & Tara', 240000, 240000, -12],
    ['DEMO-INV-005', 'Veda Kapoor — Heritage Wedding', 'Veda Kapoor', 310000, 310000, -45],
    ['DEMO-INV-006', 'Bluebird Homeware — Editorial Catalogue', 'Bluebird Homeware', 125000, 125000, -65],
  ];
  for (const [number, eventName, contactName, total, received, issueDay] of invoiceSpecs) {
    const event = eventDocs[eventName];
    const client = Object.values(clientDocs).find((item) => item.name === contactName);
    await upsert(Invoice, { userId, number }, {
      userId, number, eventName, contactName, phone: client.phone, address: client.address,
      issuedOn: dateAt(issueDay, 11), dueDate: dateAt(issueDay + 14, 11),
      deliverables: [{ id: `demo-${number}-1`, name: `${eventName} package`, cost: total }],
      amountReceived: received, documentType: 'receipt', eventId: event._id, paymentId: null,
    });
  }

  const months = [monthOffset(0), monthOffset(-1), monthOffset(-2), monthOffset(-3)];
  for (const month of months) {
    const start = new Date(month.year, month.month - 1, 1);
    const end = new Date(month.year, month.month, 1);
    const [monthEvents, monthExpenses] = await Promise.all([
      Event.find({ userId, startsAt: { $gte: start, $lt: end } }),
      Expense.find({ userId, incurredAt: { $gte: start, $lt: end } }),
    ]);
    const totalBooked = monthEvents.reduce((total, event) => total + event.totalAmount, 0);
    const totalExpenses = monthExpenses.reduce((total, expense) => total + expense.amount, 0);
    await upsert(MonthlySummary, { userId, year: month.year, month: month.month }, {
      userId, year: month.year, month: month.month, shootCount: monthEvents.length,
      totalBooked, totalExpenses,
      notes: `${monthEvents.length} event${monthEvents.length === 1 ? '' : 's'} recorded; summary reflects event bookings and recorded expenses.`,
    });
  }

  // Only populate an empty studio profile; existing profile data is preserved.
  const profileDefaults = {
    studioName: 'Lumen Studio', ownerName: 'Studio Owner', city: 'Bengaluru', state: 'Karnataka', district: 'Bengaluru Urban',
    about: 'Candid wedding, portrait, and commercial photography with a calm, editorial finish.',
    specialties: 'Wedding Photography, Portraits, Commercial Photography',
    categories: ['Traditional Photographer', 'Candid Photographer', 'Cinematographer'],
  };
  const profileSet = {};
  for (const [key, value] of Object.entries(profileDefaults)) {
    if (!user[key] || (Array.isArray(user[key]) && user[key].length === 0)) profileSet[key] = value;
  }
  if (Object.keys(profileSet).length > 0) await User.updateOne({ _id: userId }, { $set: profileSet });

  const [clientCount, eventCount, paymentCount, expenseCount, deliverableCount, invoiceCount, summaryCount] = await Promise.all([
    Client.countDocuments({ userId }), Event.countDocuments({ userId }), Payment.countDocuments({ userId }),
    Expense.countDocuments({ userId }), Deliverable.countDocuments({ userId }), Invoice.countDocuments({ userId }),
    MonthlySummary.countDocuments({ userId }),
  ]);
  const seededEvents = await Event.find({ userId, title: { $in: eventSpecs.map((item) => item[1]) } });
  const seededPayments = await Payment.find({ userId, eventId: { $in: seededEvents.map((event) => event._id) } });
  const seededExpenses = await Expense.find({ userId, eventId: { $in: seededEvents.map((event) => event._id) } });
  const booked = seededEvents.reduce((total, event) => total + event.totalAmount, 0);
  const received = sum(seededPayments);
  const expenses = sum(seededExpenses);
  if (received > booked + 0.01) fail('Verification failed: payments exceed booked event totals.');
  for (const event of seededEvents) {
    const eventPayments = seededPayments.filter((payment) => String(payment.eventId) === String(event._id));
    const eventReceived = sum(eventPayments);
    if (Math.abs(eventReceived - event.paymentTotal) > 0.01 || eventReceived > event.totalAmount + 0.01) {
      fail(`Verification failed for event ${event.title}.`);
    }
  }
  const seededInvoices = await Invoice.find({ userId, number: { $in: invoiceSpecs.map((item) => item[0]) } });
  for (const invoice of seededInvoices) {
    const invoiceTotal = invoice.deliverables.reduce((total, item) => total + item.cost, 0);
    if (invoice.amountReceived > invoiceTotal + 0.01) fail(`Verification failed for invoice ${invoice.number}.`);
    const linkedPayments = seededPayments.filter((payment) => String(payment.eventId) === String(invoice.eventId));
    if (Math.abs(sum(linkedPayments) - invoice.amountReceived) > 0.01) fail(`Invoice/payment mismatch for ${invoice.number}.`);
  }

  return { clientCount, eventCount, paymentCount, expenseCount, deliverableCount, invoiceCount, summaryCount, booked, received, pending: booked - received, expenses, netProfit: received - expenses };
}

async function main() {
  if (!argv.has('--confirm-demo-seed')) fail('Refusing to write data without --confirm-demo-seed.');
  if (!email || !email.includes('@')) fail('Set DEMO_SEED_EMAIL to the existing account email.');
  await connectDb();
  if (mongoose.connection.readyState !== 1) fail('MongoDB is required; refusing to seed the non-persistent memory store.');
  const user = await User.findOne({ email }).select('+password');
  if (!user) fail('Target account was not found; no data was written.');
  const password = process.env.DEMO_SEED_PASSWORD || (argv.has('--password-stdin') ? await promptPassword() : '');
  if (!password || !user.password || !(await bcrypt.compare(password, user.password))) fail('Target account ownership could not be verified; no data was written.');
  const result = await seed(user);
  console.log(JSON.stringify({ success: true, targetUserId: user._id.toString(), ...result }));
}

main()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (mongoose.connection.readyState !== 0) await mongoose.disconnect();
  });
