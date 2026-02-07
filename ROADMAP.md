
# Roadmap

We will implement the app page by page, integrating features as we go. Here is the roadmap:

1.  **Project Setup & Dependencies (Done)**
    *   Initialize Flutter project.
    *   Add required packages (`http`, `intl`, `sqflite`, `path`, `provider`).
    *   Set up Material 3 theme and colors.
    *   Create Splash Screen with logo.

2.  **Database Implementation (SQLite)**
    *   Create `PrayerDatabase` helper using `sqflite`.
    *   Define `PrayerRecord` model (date, prayerName, status).
    *   Implement CRUD operations (create, read, update, delete).

3.  **API Integration (Al Adhan)**
    *   Create `PrayerTimesService` to fetch prayer times based on location/city.
    *   Parse API response and store/cache daily prayer times.

4.  **Home Page (Habit Tracking)**
    *   Display current date and location.
    *   List 5 daily prayers (Fajr, Dhuhr, Asr, Maghrib, Isha).
    *   Add checkboxes/buttons to mark prayers as completed.
    *   Save completion status to SQLite database.

5.  **History & Analytics (GitHub Contribution Grid)**
    *   Create a "History" or "Stats" page (or section on Home).
    *   Implement a heatmap widget to visualize prayer consistency over the last year/month based on database records.

6.  **Settings & Customization**
    *   Allow users to set location manually or automatically.
    *   Adjust calculation methods for prayer times.

7.  **Polish & Refinement**
    *   Add animations and transitions.
    *   Ensure responsiveness.
    *   Test on different devices.

Let's start implementing the **Database Implementation** next, as it's the foundation for tracking.
