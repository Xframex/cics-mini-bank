       >>SOURCE FORMAT FREE
identification division.
program-id. BKDAY.
environment division.
input-output section.
file-control.
    select snapshot-file assign to ACCTIN
        organization is sequential
        file status is fs.
data division.
file section.
fd  snapshot-file
    recording mode is F.
01  snapshot-record.
    05 acct-id       pic x(8).
    05 acct-owner    pic x(20).
    05 acct-balance  pic 9(11).
    05 acct-active   pic x.
working-storage section.
01  fs               pic xx.
01  eof              pic x value 'N'.
01  account-count    pic 9(6) value 0.
01  grand-cents      pic 9(14) value 0.
01  amount-dec       pic 9(9)v99.
01  amount-edit      pic zzz,zzz,zz9.99.
01  grand-dec        pic 9(12)v99.
01  grand-edit       pic zzz,zzz,zzz,zz9.99.
procedure division.
    open input snapshot-file
    if fs not = '00'
        display 'SNAPSHOT OPEN FAILED, FS=' fs
        move 12 to return-code
        goback
    end-if
    display 'MINI BANK - END-OF-DAY BALANCE SNAPSHOT'
    display 'ACCOUNT   OWNER                BALANCE      STATUS'
    perform until eof = 'Y'
        read snapshot-file
          at end move 'Y' to eof
          not at end
            if acct-balance is numeric
                add 1 to account-count
                add acct-balance to grand-cents
                compute amount-dec = acct-balance / 100
                move amount-dec to amount-edit
                display acct-id ' ' acct-owner ' '
                        amount-edit ' ' acct-active
            else
                display 'BAD RECORD ' acct-id
                move 8 to return-code
            end-if
        end-read
    end-perform
    close snapshot-file
    compute grand-dec = grand-cents / 100
    move grand-dec to grand-edit
    display 'ACCOUNTS: ' account-count
    display 'TOTAL BALANCE: ' grand-edit
    goback.