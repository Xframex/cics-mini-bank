# Mini Bank test plan

Start with the seeded file. Don't run BKSEED again after transfers.

1. BK01 first invocation: login map shown.
2. DEMO/1234: main map shown.
3. I + ACC00001: displays 1,000.00.
4. T ACC00001 -> ACC00002, amount 0000012.50: success.
5. I + ACC00001: displays 987.50.
6. I + ACC00002: displays 512.50.
7. T ACC00001 -> ACC00001: rejected; no change.
8. T ACC00001 -> ACC00002, 0000000.00: rejected.
9. T ACC00001 -> ACC00002, 9999999.99: rejected.
10. T ACC00003 -> ACC00001, 0000010.00: rejected
    because DEMO does not own ACC00003.
11. T ACC00001 -> ACC99999: rejected, rollback first update.
12. Test F3: session returns to CICS; next BK01 requires login.
13. Quiesce and close file, run end-of-day snapshot job.
    Check total remains 1,750.00 across all three accounts.

WARNING: Another user/transaction can change these balances; all
expectations assume a clean seed and only this scripted transfer.
