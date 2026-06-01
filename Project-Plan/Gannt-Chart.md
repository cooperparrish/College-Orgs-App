```mermaid
gantt
    title Unnamed StartUp - 12-Week MVP Timeline (June - August)
    dateFormat  YYYY-MM-DD
    axisFormat  %b-%d
    tickInterval 1w

    section Phase 1: Design & Infrastructure
    Figma Wireframes (Apple HIG)      :active, p1_1, 2026-06-01, 2026-06-08
    Supabase Schema & Database Setup  :p1_2, 2026-06-08, 2026-06-15
    Supabase Auth & Login Flow        :p1_3, 2026-06-15, 2026-06-22

    section Phase 2: Feature Engineering
    App Navigation Shell & Assets     :p2_1, 2026-06-22, 2026-06-29
    Hybrid Calendar UI & Backend      :p2_2, 2026-06-29, 2026-07-13
    Realtime Chat System              :p2_3, 2026-07-13, 2026-07-27
    Media Handling & Storage Buckets  :p2_4, 2026-07-27, 2026-08-03

    section Phase 3: Testing & Polish
    Apple TestFlight & Provisioning   :p3_1, 2026-08-03, 2026-08-10
    Beta Testing & Bug Squashing      :crit, p3_2, 2026-08-10, 2026-08-24
    August Launch Prep & Deck         :p3_3, 2026-08-24, 2026-08-31
