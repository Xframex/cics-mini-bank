       >>SOURCE FORMAT FREE
identification division.
program-id. BKONL.
environment division.
data division.
working-storage section.
01  ws-session.
    05 ws-logged         pic x.
    05 ws-user           pic x(8).
01  ws-resp             pic s9(9) comp value 0.
01  ws-sync-resp        pic s9(9) comp value 0.
01  ws-message          pic x(60) value spaces.
01  ws-balance-text     pic x(14) value spaces.
01  ws-amount           pic 9(9) value zero.
01  ws-amount-dollars   pic 9(7) value zero.
01  ws-amount-cents     pic 99 value zero.
01  ws-from-key         pic x(8) value spaces.
01  ws-to-key           pic x(8) value spaces.
01  ws-first-key        pic x(8) value spaces.
01  ws-second-key       pic x(8) value spaces.
01  ws-active-key       pic x(8) value spaces.
01  ws-failed           pic x value 'N'.
01  ws-acc.
    05 ws-acc-id        pic x(8).
    05 ws-acc-owner     pic x(20).
    05 ws-acc-balance   pic 9(11).
    05 ws-acc-active    pic x.
01  ws-balance-dec      pic 9(9)v99 value zero.
01  ws-balance-edit     pic zzz,zzz,zz9.99.
copy 'DFHAID'.
copy 'BKMAP'.
linkage section.
01  dfhcommarea.
    05 ca-logged        pic x.
    05 ca-user          pic x(8).
procedure division.
main.
    initialize ws-session
    move spaces to ws-message ws-balance-text
    if eibcalen = length of ws-session
        move dfhcommarea to ws-session
    end-if

    if eibaid = dfhpf3 or eibaid = dfhclear
        exec cics return end-exec
    end-if

    if ws-logged = 'Y'
        if eibcalen > 0
            perform process-main
        end-if
        perform show-main
    else
        if eibcalen > 0
            perform process-login
        end-if
        if ws-logged = 'Y'
            perform show-main
        else
            perform show-login
        end-if
    end-if

    exec cics return transid('BK01')
         commarea(ws-session)
         length(length of ws-session)
    end-exec.

process-login.
    move low-values to bklgini
    exec cics receive map('BKLGIN') mapset('BKMAP')
         into(bklgini) resp(ws-resp)
    end-exec
    evaluate true
      when ws-resp not = dfhresp(normal)
          move 'Enter the user ID and PIN.' to ws-message
      when useridi = spaces
          move 'Enter a user ID.' to ws-message
      when useridi = 'DEMO' and pini = '1234'
          move 'Y' to ws-logged
          move 'DEMO' to ws-user
          move 'Signed on. Choose I or T.' to ws-message
      when other
          move 'Invalid demonstration credentials.' to ws-message
    end-evaluate.

process-main.
    move low-values to bkmaini
    exec cics receive map('BKMAIN') mapset('BKMAP')
         into(bkmaini) resp(ws-resp)
    end-exec
    if ws-resp not = dfhresp(normal)
        move 'Enter I or T and the required fields.'
          to ws-message
        exit paragraph
    end-if
    evaluate acti
      when 'I'
      when 'i'
          perform account-inquiry
      when 'T'
      when 't'
          perform transfer-money
      when other
          move 'Action must be I (inquiry) or T (transfer).'
            to ws-message
    end-evaluate.

account-inquiry.
    move fromai to ws-from-key
    if ws-from-key = spaces
        move 'Enter the From Account for inquiry.'
          to ws-message
        exit paragraph
    end-if
    exec cics read file('BKACCT')
         ridfld(ws-from-key) into(ws-acc)
         resp(ws-resp)
    end-exec
    evaluate ws-resp
      when dfhresp(normal)
        if ws-acc-owner not = ws-user
            move 'Inquiry not authorized for this account.'
              to ws-message
        else
            compute ws-balance-dec = ws-acc-balance / 100
            move ws-balance-dec to ws-balance-edit
            move ws-balance-edit to ws-balance-text
            move 'Account balance displayed.' to ws-message
        end-if
      when dfhresp(notfnd)
        move 'Account not found.' to ws-message
      when other
        move 'CICS READ failed. Check BKACCT status.'
          to ws-message
    end-evaluate.

transfer-money.
    move fromai to ws-from-key
    move toai to ws-to-key
    if ws-from-key = spaces or ws-to-key = spaces
        move 'Both From and To accounts are required.'
          to ws-message
        exit paragraph
    end-if
    if ws-from-key = ws-to-key
        move 'Source and destination must differ.'
          to ws-message
        exit paragraph
    end-if
    if amti(1:7) is not numeric or
       amti(8:1) not = '.' or
       amti(9:2) is not numeric
        move 'Use amount format 0000012.50 (10 chars).'
          to ws-message
        exit paragraph
    end-if
    move amti(1:7) to ws-amount-dollars
    move amti(9:2) to ws-amount-cents
    compute ws-amount = (ws-amount-dollars * 100)
                      + ws-amount-cents
    if ws-amount = 0
        move 'Transfer amount must be greater than zero.'
          to ws-message
        exit paragraph
    end-if

    *> Consistent key order reduces risk of deadlocks.
    if ws-from-key < ws-to-key
        move ws-from-key to ws-first-key
        move ws-to-key to ws-second-key
    else
        move ws-to-key to ws-first-key
        move ws-from-key to ws-second-key
    end-if
    move 'N' to ws-failed
    move ws-first-key to ws-active-key
    perform apply-update
    if ws-failed = 'N'
        move ws-second-key to ws-active-key
        perform apply-update
    end-if

    if ws-failed = 'Y'
        exec cics syncpoint rollback resp(ws-sync-resp)
        end-exec
        if ws-sync-resp not = dfhresp(normal)
            move 'ROLLBACK ERROR - contact CICS operator.'
              to ws-message
        end-if
    else
        exec cics syncpoint resp(ws-sync-resp)
        end-exec
        if ws-sync-resp = dfhresp(normal)
            move 'Transfer committed successfully.'
              to ws-message
        else
            move 'COMMIT ERROR - investigate transaction state.'
              to ws-message
        end-if
    end-if.

apply-update.
    *> READ UPDATE and REWRITE must be paired for BKACCT.
    exec cics read file('BKACCT')
         ridfld(ws-active-key) into(ws-acc) update
         resp(ws-resp)
    end-exec
    if ws-resp not = dfhresp(normal)
        move 'Account not found or locked / CICS error.'
          to ws-message
        move 'Y' to ws-failed
        exit paragraph
    end-if
    if ws-acc-active not = 'A'
        move 'Inactive account: transfer cancelled.'
          to ws-message
        move 'Y' to ws-failed
        exit paragraph
    end-if
    if ws-active-key = ws-from-key
        if ws-acc-owner not = ws-user
            move 'Source account not authorized.'
              to ws-message
            move 'Y' to ws-failed
            exit paragraph
        end-if
        if ws-acc-balance < ws-amount
            move 'Insufficient funds: transfer cancelled.'
              to ws-message
            move 'Y' to ws-failed
            exit paragraph
        end-if
        subtract ws-amount from ws-acc-balance
    else
        if ws-acc-balance > 99999999999 - ws-amount
            move 'Destination balance would overflow.'
              to ws-message
            move 'Y' to ws-failed
            exit paragraph
        end-if
        add ws-amount to ws-acc-balance
    end-if
    exec cics rewrite file('BKACCT') from(ws-acc)
         resp(ws-resp)
    end-exec
    if ws-resp not = dfhresp(normal)
        move 'REWRITE failed; transaction being backed out.'
          to ws-message
        move 'Y' to ws-failed
    end-if.

show-login.
    move low-values to bklgino
    move ws-message to lmsgo
    exec cics send map('BKLGIN') mapset('BKMAP')
         from(bklgino) erase freekb
    end-exec.

show-main.
    move low-values to bkmaino
    move ws-user to whoo
    move ws-message to msgo
    move ws-balance-text to balo
    exec cics send map('BKMAIN') mapset('BKMAP')
         from(bkmaino) erase freekb
    end-exec.