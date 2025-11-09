# Incomatic

A salary calculator app that helps you understand your take-home pay after taxes and deductions.

## Overview

Incomatic provides a simple way to calculate your actual paycheck amount based on your annual salary. Enter your salary information, and the app breaks down exactly where your money goes - from federal and state taxes to FICA, Medicare, and any deductions you might have.

## Features

- **Automatic Location Detection** - Uses your location to determine state tax rates
- **Multiple Pay Frequencies** - Calculate pay for weekly, biweekly, monthly, or annual periods
- **Detailed Breakdown** - See exactly how much goes to federal tax, state tax, FICA, Medicare, and deductions
- **Deductions Support** - Account for pre-tax deductions (401k, HSA) and post-tax deductions
- **Filing Status Options** - Calculate based on single or married filing status

## Requirements

- macOS/iOS device
- Backend API service running on `localhost:8080`

## How It Works

The app takes your salary information and sends it to a calculation service that applies the appropriate tax rules based on your location and filing status. It then displays a comprehensive breakdown of your gross pay, taxes, deductions, and net take-home pay.

## Getting Started

1. Open the app
2. Allow location access for automatic state detection
3. Enter your annual salary
4. Select your pay frequency and filing status
5. Add any deductions (optional)
6. Tap "Calculate" to see your breakdown

---

Built with Swift and SwiftUI
