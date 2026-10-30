// Keep in sync with the actual app features.
// To add / edit questions: update the `faqs` array inside each category.
// Do NOT invent features not present in the codebase.

const KB_CATEGORIES = [
  {
    id: 'about',
    icon: '✨',
    label: 'About Clients Hub',
    desc: 'What is Clients Hub and who is it for?',
    faqs: [
      {
        q: 'What is Clients Hub?',
        a: 'Clients Hub is a studio management app built specifically for photographers and videographers. It helps you organise clients, schedule shoots, track payments, manage expenses, and generate invoices — all in one place.',
      },
      {
        q: 'Who should use Clients Hub?',
        a: 'Clients Hub is designed for freelance photographers, videographers, and small photography studios who want a simple but powerful way to manage their business. You must be 18 years or older to create an account.',
      },
      {
        q: 'Is Clients Hub a payment gateway?',
        a: 'No. Clients Hub does not process payments or hold money. It is a record-keeping tool — you record payments that have already happened (via UPI, cash, bank transfer, card, or other methods) directly between you and your clients.',
      },
      {
        q: 'What data does Clients Hub store?',
        a: 'Clients Hub stores your account details (username, email, phone), your studio profile, and the business records you create — clients, events, deliverables, payments, expenses, and invoices. Images such as your logo, payment QR code, and payment proof screenshots are stored securely with a cloud provider.',
      },
      {
        q: 'Is my data secure?',
        a: 'Yes. All data is sent over encrypted HTTPS connections and stored on secure servers. Sensitive fields are encrypted in the database. Your password is stored only in hashed form and is never readable by anyone, including our team. We will never ask you for your password or OTP.',
      },
    ],
  },
  {
    id: 'events',
    icon: '📅',
    label: 'Events & Scheduling',
    desc: 'Creating and managing shoots and events.',
    faqs: [
      {
        q: 'How do I create a new event?',
        a: 'Tap the <strong>Events</strong> tab, then tap the <strong>+</strong> button. Fill in the event title, type (e.g. Wedding, Portrait), start date and time, end date and time (optional), location, and total amount. You can also add notes. Tap <strong>Save</strong> to create the event.',
      },
      {
        q: 'What event types are supported?',
        a: 'You can enter any event type you like, such as Wedding, Portrait, Corporate, Maternity, Product, or any custom type that fits your work. The field is free-text.',
      },
      {
        q: 'What statuses can an event have?',
        a: 'Events can be in one of five states: <strong>Upcoming</strong> — shoot is scheduled; <strong>In Progress</strong> — shoot is happening now; <strong>Payment Due</strong> — shoot is done but payment is pending; <strong>Completed</strong> — shoot and payment are both done; <strong>Cancelled</strong> — shoot has been cancelled.',
      },
      {
        q: 'Can I link a client to an event?',
        a: 'Yes. When creating or editing an event, you can select an existing client from your client list to link them to that event. This makes it easy to see all events for a particular client.',
      },
      {
        q: 'How do I add deliverables to an event?',
        a: 'Open the event, then go to the <strong>Deliverables</strong> section. Tap <strong>Add Deliverable</strong>, enter a title (e.g. "Edited photos"), an optional stage (e.g. "Post-production"), and save. You can mark deliverables as completed when they are done.',
      },
      {
        q: 'Can I record the location of a shoot?',
        a: 'Yes. When creating an event, enter the shoot location in the location field. The app can also store GPS coordinates (latitude and longitude) for the event location, which can be set from within the app.',
      },
      {
        q: 'How do I edit or delete an event?',
        a: 'Open the event you want to change, then tap the edit icon or the menu to find the edit and delete options. Deleting an event will also remove the associated payments and expenses for that event.',
      },
    ],
  },
  {
    id: 'clients',
    icon: '🤝',
    label: 'Client Management',
    desc: 'Adding, editing, and organising your clients.',
    faqs: [
      {
        q: 'How do I add a new client?',
        a: 'Go to the <strong>Clients</strong> tab and tap <strong>+</strong>. Enter the client\'s name (required), phone number (required — 10 digits), and optionally their email address, physical address, and any notes. Tap <strong>Save</strong>.',
      },
      {
        q: 'What client statuses are available?',
        a: 'Each client has a status that helps you track the relationship: <strong>Information</strong> — lead or enquiry; <strong>Coming Up</strong> — event is booked and scheduled; <strong>Completed</strong> — shoot is done; <strong>Not Responded</strong> — client has not replied to your outreach.',
      },
      {
        q: 'Can I store notes about a client?',
        a: 'Yes. Each client record has a notes field where you can store anything useful — preferences, shoot details, referral source, and so on. Notes are encrypted in the database.',
      },
      {
        q: 'How is client data protected?',
        a: 'Client email addresses, physical addresses, and notes are stored encrypted in the database. Phone numbers are stored securely and displayed in masked form (e.g. ×××××12345) when needed. You are responsible for having your clients\' permission to store their information.',
      },
      {
        q: 'Can I search or filter my client list?',
        a: 'Yes. The app includes a fuzzy-search feature that lets you find clients by name or other details, even with approximate spelling.',
      },
      {
        q: 'How do I edit or delete a client?',
        a: 'Open the client\'s profile from the Clients tab, then use the edit or delete option from the menu. Deleting a client removes their record but does not delete any events or invoices already linked to them.',
      },
    ],
  },
  {
    id: 'payments',
    icon: '💳',
    label: 'Payments & Expenses',
    desc: 'Recording what you received and what you spent.',
    faqs: [
      {
        q: 'How do I record a payment for an event?',
        a: 'Open the event, go to the <strong>Payments</strong> section, and tap <strong>Add Payment</strong>. Enter a title (e.g. "Advance"), the amount, the date it was paid, the payment method (Cash, UPI, Bank Transfer, Card, or Other), and optionally a reference number and a payment proof screenshot. Tap Save.',
      },
      {
        q: 'Which payment methods can I record?',
        a: 'You can record payments made by <strong>Cash</strong>, <strong>UPI</strong>, <strong>Bank Transfer</strong>, <strong>Card</strong>, or <strong>Other</strong>. These are record-keeping labels only — the app does not process any actual payments.',
      },
      {
        q: 'Can I upload a payment proof screenshot?',
        a: 'Yes. When adding a payment, you can attach a payment proof image (e.g. a UPI screenshot). The image is uploaded and stored securely with our cloud provider and linked to that payment record.',
      },
      {
        q: 'How do I track expenses for a shoot?',
        a: 'Open the event, navigate to the <strong>Expenses</strong> section, and tap <strong>Add Expense</strong>. Enter a title (e.g. "Travel"), the amount, a category (e.g. "Transport", "Equipment"), and the date it was incurred. All expenses are linked to that event.',
      },
      {
        q: 'Does the app automatically calculate profit?',
        a: 'Yes. Monthly summaries track <strong>Total Booked</strong> (revenue from events) and <strong>Total Expenses</strong>, and calculate your <strong>Profit</strong> (Total Booked minus Total Expenses) for each month.',
      },
      {
        q: 'Can I see all payments and expenses at once?',
        a: 'Payments and expenses are shown per event. For a higher-level view, check the <strong>Monthly Summary</strong> section, which shows your shoot count, total booked amount, total expenses, and net profit for each calendar month.',
      },
    ],
  },
  {
    id: 'invoices',
    icon: '🧾',
    label: 'Invoices & Receipts',
    desc: 'Creating, managing, and sharing invoices.',
    faqs: [
      {
        q: 'How do I create an invoice?',
        a: 'Go to the <strong>Invoices</strong> section and tap <strong>Create Invoice</strong>. Fill in the invoice number, event name, client name, client phone, client address, issue date, due date, and add line items (deliverable name + cost). You can also add your UPI ID. The app calculates the total automatically.',
      },
      {
        q: 'What is the difference between a receipt and an estimate?',
        a: 'Clients Hub supports two document types: a <strong>Receipt</strong> records a payment that has been made or partially made; an <strong>Estimate</strong> is a price quote sent before any payment. Select the appropriate type when creating the document.',
      },
      {
        q: 'What invoice statuses exist?',
        a: 'An invoice can be: <strong>Pending</strong> — not yet due and no payment received; <strong>Partial</strong> — some payment has been received; <strong>Paid</strong> — full amount received; <strong>Overdue</strong> — the due date has passed and the full amount is not yet received.',
      },
      {
        q: 'How do I mark an invoice as paid?',
        a: 'Open the invoice and select <strong>Mark as Paid</strong>. This sets the amount received to the full invoice total and changes the status to Paid. You can also use <strong>Mark as Partial</strong> to record a partial payment, or <strong>Extend Due Date</strong> to push back the due date.',
      },
      {
        q: 'Do invoices include my studio branding?',
        a: 'Yes. Invoices are generated with your studio name and other profile details. If you have uploaded a logo and a UPI ID, these appear on the invoice, giving it a professional, branded look.',
      },
      {
        q: 'How do I share an invoice with a client?',
        a: 'Open the invoice and use the <strong>Share</strong> option to send it via WhatsApp, email, or any other app installed on your device. Clients Hub generates a shareable version of the invoice for you.',
      },
      {
        q: 'Can I link an invoice to an event or payment?',
        a: 'Yes. When creating an invoice, you can link it to a specific event and to a specific payment record. This creates a connected record that ties your financial documents to your shoot history.',
      },
    ],
  },
  {
    id: 'studio',
    icon: '🏢',
    label: 'Studio Profile & Photographer Discovery',
    desc: 'Your public profile and photographer discovery.',
    faqs: [
      {
        q: 'How do I update my studio profile?',
        a: 'Go to <strong>Profile</strong> &gt; <strong>Edit Profile</strong>. You can update your studio name, owner name, email address, city, state, district, address, a short bio (About), specialties, photography categories, social links (Instagram, YouTube, website), and UPI ID.',
      },
      {
        q: 'How do I upload or change my studio logo?',
        a: 'In your profile, tap the logo area or the camera icon. Select an image from your device. The logo is uploaded securely to our cloud storage and used on your invoices and your public photographer profile.',
      },
      {
        q: 'What is the payment QR code for?',
        a: 'You can upload a UPI payment QR code image to your profile. This QR code appears on your invoices, making it easy for clients to scan and pay you directly.',
      },
      {
        q: 'What is the Discover / Nearby Photographers feature?',
        a: 'The Discover section lets you find other photographers and studios on Clients Hub near you. You can search by city, state, district, category (e.g. Wedding, Portrait), or keywords. Results are sorted by distance when you share your location, or alphabetically otherwise.',
      },
      {
        q: 'How do I appear in Discover search results?',
        a: 'Make sure your profile has a city, state, or address filled in, and select your photography categories (e.g. Wedding, Portrait, Commercial). Profiles with complete information and GPS coordinates are more likely to appear prominently in location-based searches.',
      },
      {
        q: 'What information is visible to other users in Discover?',
        a: 'Other users can see your studio name, owner name, city, state, bio, specialties, categories, logo, Instagram, YouTube, and website. Your payment QR code and Google account ID are never shared. Your phone number and email are visible to authenticated users searching the directory.',
      },
    ],
  },
  {
    id: 'settings',
    icon: '⚙️',
    label: 'Settings & Personalisation',
    desc: 'App preferences and customisation options.',
    faqs: [
      {
        q: 'Can I change the app theme or colour scheme?',
        a: 'Theme customisation is not available in the current version of Clients Hub. If you would like this feature, please let us know at <a href="mailto:istudio2512@gmail.com">istudio2512@gmail.com</a> — your feedback helps us prioritise what to build next.',
      },
      {
        q: 'Can I change my username?',
        a: 'Username changes are not currently supported in the app. Your username is set at the time of registration. If you need help with your username, contact our support team.',
      },
      {
        q: 'How do I change my password?',
        a: 'Go to <strong>Profile</strong> &gt; <strong>Account Settings</strong> &gt; <strong>Change Password</strong>. Enter your current password and then your new password. Passwords must be at least 8 characters long.',
      },
      {
        q: 'Can I add a team member or second user to my account?',
        a: 'Multi-user or team accounts are not currently supported. Each account is for a single studio owner or photographer.',
      },
      {
        q: 'How do I update my email address?',
        a: 'You can update your email address from your profile edit screen. Your email is used for account-related communications and appears on your invoices.',
      },
      {
        q: 'Does the app send push notifications?',
        a: 'Yes. Clients Hub sends reminders and notifications related to your upcoming shoots and events. You can manage notification permissions through your device\'s system settings.',
      },
    ],
  },
  {
    id: 'account',
    icon: '🔐',
    label: 'Account & Privacy',
    desc: 'Sign-up, login, data, and account deletion.',
    faqs: [
      {
        q: 'How do I create an account?',
        a: 'Download the Clients Hub app and tap <strong>Sign Up</strong>. You can register with your phone number (an OTP will be sent for verification) or sign in with your Google account. You will also choose a unique username.',
      },
      {
        q: 'Can I sign in with Google?',
        a: 'Yes. Clients Hub supports Google Sign-In. If you use this option, your Google name, email, and profile picture are used to set up your account. You can still add a phone number later.',
      },
      {
        q: 'I forgot my password. How do I reset it?',
        a: 'On the login screen, tap <strong>Forgot Password?</strong> and enter your registered email address. We will send you a password reset link. Check your spam or junk folder if you do not receive it within a few minutes. We will <strong>never</strong> ask for your password or OTP.',
      },
      {
        q: 'How do I delete my account?',
        a: 'Go to <strong>Profile</strong> &gt; <strong>Account Settings</strong> &gt; <strong>Delete Account</strong>. This permanently removes your account and all associated data (clients, events, payments, invoices) from our active systems. Backups are cleared within a reasonable period. If you cannot sign in, submit a request at <a href="/delete-data">/delete-data</a>.',
      },
      {
        q: 'Can I export or download my data?',
        a: 'You can share individual invoices and receipts from within the app. A full data export feature is not yet available. For specific data access or deletion requests, email us at <a href="mailto:istudio2512@gmail.com">istudio2512@gmail.com</a>.',
      },
      {
        q: 'How long is my data kept?',
        a: 'Your data is stored while your account is active. When you delete your account, your data is removed from our active systems, and backup copies are cleared within a reasonable period.',
      },
      {
        q: 'What are my privacy rights?',
        a: 'You can access, correct, or delete your information from within the app at any time. Where applicable law — including India\'s Digital Personal Data Protection Act, 2023 — gives you additional rights, we will honour them. See the full <a href="/privacy-policy">Privacy Policy</a> for details.',
      },
    ],
  },
];

module.exports = { KB_CATEGORIES };
