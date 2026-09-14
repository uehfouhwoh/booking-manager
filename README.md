# FlowSlot Campus Booking System

FlowSlot Campus is a Flutter and Firebase mobile application for managing campus service appointments and staff facility reservations. The app supports student, staff, and admin roles with live Firestore data, approval workflows, booking conflict prevention, and operational insights.

## Key Features

- Student service booking for departments such as IT Helpdesk, Finance, Admissions, and Academic Advising.
- Staff facility reservation for rooms, labs, equipment, studios, and event spaces.
- One active booking per service or facility per hour across all accounts.
- Admin approval, rejection, status update, record editing, and record deletion.
- User booking history with hide and restore controls.
- Admin insights for pending approvals, active bookings, slot conflicts, hourly demand, and resource usage.
- SDG 11 alignment through reduced crowding, fewer unnecessary walk-ins, and digital queue management.

## Database

Firebase Firestore stores and retrieves live app data:

- `queue`: student service and staff facility booking records.
- `settings/campus`: configurable `departments`, `facilities`, and analytics settings.
- `users`: account profile, role, avatar, and notification preference.
- `bookingSlots`: one-hour reservation locks that prevent double booking.

CRUD coverage:

- Create: users submit booking requests.
- Read: users and admins view live records.
- Update: admins update booking data and statuses; users hide or restore history.
- Delete: admins delete booking records.

## Roles

- Student: view app info, submit service requests, track status, view calculations, manage history, and log out.
- Staff: reserve facilities, track approval, mark facility use completed, manage history, and log out.
- Admin: review approvals, view all input data, update records, delete records, manage departments/facilities, view insights, and log out.

## Run

```powershell
flutter pub get
flutter run
```

Deploy Firestore rules after changing `firestore.rules`:

```powershell
firebase deploy --only firestore:rules
```
