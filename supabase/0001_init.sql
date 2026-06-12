-- Extensions 

-- Location Services
CREATE EXTENSION IF NOT EXISTS "postgis";
-- Enables case-sensitive text
CREATE EXTENSION IF NOT EXISTS "citext";
-- Enables UUID generation functions 
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Custom Enums
CREATE TYPE public.org_type AS ENUM ('fraternity', 'sorority', 'club', 'organization');
CREATE TYPE public.account_type AS ENUM ('student', 'alumni');
CREATE TYPE public.affiliation_status AS ENUM ('current', 'past');
CREATE TYPE public.verification_method AS ENUM ('email_otp', 'sso', 'sheerid', 'document');
CREATE TYPE public.membership_role AS ENUM ('admin', 'user', 'alumni');
CREATE TYPE public.membership_status AS ENUM ('pending', 'active', 'removed');
CREATE TYPE public.invitation_status AS ENUM ('');


  
-- Anchor Tables 


-- Core Tables (Profiles, National Orgs, etc)

-- Chapters

-- Membership 

-- Events Dues Features

-- Security 
