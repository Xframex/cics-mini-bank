       >>SOURCE FORMAT FREE
identification division.
program-id. BKSEED.
environment division.
input-output section.
file-control.
    select account-file assign to ACCTVS
        organization is indexed
        access mode is dynamic
        record key is acct-id
        file status is fs.
data division.
file section.
fd  account-file.
01  account-record.
    05 acct-id       pic x(8).
    05 acct-owner    pic x(20).
    05 acct-balance  pic 9(11).
    05 acct-active   pic x.
working-storage section.
01  fs               pic xx.
procedure division.
    open output account-file
    if fs not = '00'
        display 'OPEN OUTPUT FAILED FS=' fs
        move 12 to return-code
        goback
    end-if
    move 'ACC00001' to acct-id
    move 'DEMO' to acct-owner
    move 100000 to acct-balance
    move 'A' to acct-active
    perform write-one
    move 'ACC00002' to acct-id
    move 'DEMO' to acct-owner
    move 50000 to acct-balance
    move 'A' to acct-active
    perform write-one
    move 'ACC00003' to acct-id
    move 'GUEST' to acct-owner
    move 25000 to acct-balance
    move 'A' to acct-active
    perform write-one
    close account-file
    display 'SEEDED THREE ACCOUNTS (CENTS STORAGE)'
    goback.
write-one.
    write account-record
    if fs not = '00'
        display 'WRITE FAILED FOR ' acct-id ' FS=' fs
        move 12 to return-code
        close account-file
        goback
    end-if.