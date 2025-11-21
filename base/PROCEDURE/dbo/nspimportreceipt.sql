SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspImportReceipt]
 AS
 BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 DECLARE     @n_continue    int      ,  
             @n_starttcnt   int      , -- Holds the current transaction count
             @n_cnt         int      , -- Holds @@ROWCOUNT after certain operations
             @c_preprocess  NVARCHAR(250), -- preprocess
             @c_pstprocess  NVARCHAR(250), -- post process
             @n_err2        int      , -- For Additional Error Detection
             @b_debug       int      , -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
             @b_success     int      ,
             @n_err         int      ,   
             @c_errmsg      NVARCHAR(250),
             @errorcount    int

 DECLARE @c_hikey            NVARCHAR(10),
         @c_externreceiptkey NVARCHAR(30),
         @c_storerkey        NVARCHAR(15)

 SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, 
        @n_err=0,                 @n_cnt = 0,    @c_errmsg="",
        @n_err2=0

 SELECT @b_debug = 0
    /* Start Main Processing */
    -- get the hikey,
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
    SELECT @b_success = 0
    EXECUTE nspg_GetKey
          "hirun",
          10,
          @c_hikey OUTPUT,
          @b_success   	 OUTPUT,
          @n_err       	 OUTPUT,
          @c_errmsg    	 OUTPUT
    IF NOT @b_success = 1
    BEGIN
       SELECT @n_continue = 3
    END
 END
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
    INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
    VALUES ( @c_hikey, ' -> The HI Run Identifer Is ' + @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')
    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspImportReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 -- BEGIN VALIDATION SECTION
 -- do all the validation on the WMSRCM and WMSRCD tables first before inserting into temp table
 -- 'ERROR CODES -> E1 for blank externreceiptkey, E2 for blank storerkey, E3 for Invalid Storerkey, E4 for Invalid sku
 -- E5 for repeating externreceiptkey, E6 for non existing externreceiptkey in header file
 -- check for existing externreceiptkey, E7 for wrong SKU and Storerkey combination
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
   declare @count1 int

    -- this will make sure that the default flag before processing is 'N'
   UPDATE WMSRCM
   SET WMS_FLAG = 'N'
   WHERE ( dbo.fnc_LTrim(dbo.fnc_RTrim(WMS_FLAG)) = '' OR dbo.fnc_LTrim(dbo.fnc_RTrim(WMS_FLAG)) IS NULL )

   UPDATE WMSRCD
   SET WMS_FLAG = 'N'
   WHERE ( dbo.fnc_LTrim(dbo.fnc_RTrim(WMS_FLAG)) = '' OR dbo.fnc_LTrim(dbo.fnc_RTrim(WMS_FLAG)) IS NULL )

   IF EXISTS (SELECT 1 FROM WMSRCM WHERE WMS_FLAG = 'N')
   BEGIN
 	SELECT @n_continue = 1
         -- update the hikey to the column addwho in the tables WMSRCM and WMSRCD 
         Update WMSRCM
         SET ADDWHO = @c_hikey
         WHERE WMS_FLAG = 'N'
         AND ( dbo.fnc_LTrim(dbo.fnc_RTrim(ADDWHO)) = '' OR dbo.fnc_LTrim(dbo.fnc_RTrim(ADDWHO)) IS NULL )
         UPDATE WMSRCD
         SET ADDWHO = @c_hikey
         WHERE WMS_FLAG = 'N'
         AND (dbo.fnc_LTrim(dbo.fnc_RTrim(ADDWHO)) = '' OR dbo.fnc_LTrim(dbo.fnc_RTrim(ADDWHO)) IS NULL )
   END
   ELSE
   BEGIN
      SELECT @n_continue = 4
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspImportReceipt -- There is no records to be processed for ' + @c_hikey + '. Process ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspImportReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
    UPDATE WMSRCM
    SET WMS_FLAG = 'E5'
    FROM WMSRCM 
    JOIN RECEIPT (NOLOCK) ON (RECEIPT.ExternReceiptkey = WMSRCM.ExternReceiptkey )
    WHERE WMSRCM.WMS_FLAG = 'N'

    Update WMSRCD
    SET WMS_FLAG = 'E5'
    FROM WMSRCD
    JOIN RECEIPT (NOLOCK) ON (RECEIPT.ExternReceiptkey = WMSRCD.ExternReceiptkey)
    WHERE WMSRCD.WMS_FLAG = 'N'

 -- check for blank externreceiptkey
    UPDATE WMSRCM
    SET WMS_FLAG = 'E1'
    WHERE (EXTERNRECEIPTKEY = '' OR EXternReceiptkey IS NULL)
    AND WMS_FLAG = 'N'

 -- check for blank externreceiptkey in detail 
    UPDATE WMSRCD
    SET WMS_FLAG = 'E1'
    WHERE (EXTERNRECEIPTKEY = '' OR EXternReceiptkey IS NULL)
    AND WMS_FLAG = 'N'

    -- check for blank storerkey
    UPDATE WMSRCM
    SET WMS_FLAG = 'E2'
    WHERE (Storerkey = '' OR Storerkey IS NULL )
    AND WMS_FLAG = 'N'

    -- if header has a storerkey, and not detail, populate the header storerkey (valid one) based on the externreceiptkey
    UPDATE WMSRCD
    SET WMSRCD.Storerkey = WMSRCM.Storerkey
    FROM WMSRCD 
       JOIN WMSRCM ON (WMSRCM.ExternReceiptkey = WMSRCD.ExternReceiptkey)
       JOIN STORER (NOLOCK) ON ( WMSRCM.Storerkey = STORER.StorerKey )
    WHERE WMSRCM.WMS_FLAG = 'N'
    AND WMSRCD.WMS_Flag = 'N'

    -- check for invalid storerkey
    UPDATE WMSRCM
      SET WMS_FLAG = 'E3'
    FROM WMSRCM
    LEFT JOIN STORER (NOLOCK) ON ( WMSRCM.StorerKey = STORER.StorerKey )
    WHERE WMS_FLAG = 'N'
    AND STORER.StorerKey IS NULL

    -- make the detail invalid too once the storerkey in the header is invalid
    UPDATE WMSRCD
      SET WMS_FLAG = 'E3'
    FROM WMSRCD
    JOIN WMSRCM ON (WMSRCM.ExternReceiptkey = WMSRCD.ExternReceiptkey AND WMSRCM.WMS_Flag = 'E3')
    WHERE WMSRCD.WMS_FLAG = 'N'

    -- wrong sku & storerkey combination
    Update WMSRCD
       SET WMS_FLAG = 'E7'
    FROM WMSRCD 
    LEFT JOIN SKU (NOLOCK) ON ( WMSRCD.StorerKey = SKU.StorerKey AND WMSRCD.SKU = SKU.SKU)
    WHERE SKU.SKU IS NULL
    AND WMSRCD.WMS_FLAG = 'N'

    -- reject the header for error code E7
    UPDATE WMSRCM
    SET WMSRCM.WMS_FLAG = 'E7'
    FROM WMSRCM
       JOIN WMSRCD ON (WMSRCM.ExternReceiptkey = WMSRCD.ExternReceiptkey AND WMSRCD.WMS_Flag = 'E7')
    WHERE WMSRCM.WMS_FLAG = 'N'

    -- check for invalid sku
    UPDATE WMSRCD
    SET WMS_FLAG = 'E4'
    FROM WMSRCD 
    LEFT JOIN SKU (NOLOCK) ON ( WMSRCD.SKU = SKU.SKU)
    WHERE SKU.SKU IS NULL
    AND WMSRCD.WMS_FLAG = 'N'

    -- once we found the invalid sku, reject the rest of the detail lines as well as the header 
    UPDATE WMSRCM
    SET WMS_FLAG = 'E4'
    FROM WMSRCM
    JOIN WMSRCD ON (WMSRCM.ExternReceiptkey = WMSRCD.ExternReceiptkey AND WMSRCD.WMS_Flag = 'E4')
    WHERE WMSRCM.WMS_FLAG = 'N'

 -- check this one, might now work
    UPDATE WMSRCD
    SET WMS_FLAG = 'E4'
    FROM WMSRCD
       JOIN WMSRCM ON (WMSRCM.ExternReceiptkey = WMSRCD.ExternReceiptkey AND WMSRCM.WMS_Flag = 'E4')
    WHERE WMSRCD.WMS_FLAG = 'N'

 -- check for externreceiptkey that only exist in detail but not header
    Update WMSRCD
       SET WMS_FLAG = 'E6'
    FROM WMSRCD
       LEFT OUTER JOIN WMSRCM ON (WMSRCD.ExternReceiptkey = WMSRCM.ExternReceiptKey)
    WHERE WMSRCD.WMS_FLAG = 'N'
    AND WMSRCM.ExternReceiptKey IS NULL
   END

    IF EXISTS (SELECT 1 FROM WMSRCM WHERE SUBSTRING(WMS_FLAG,1,1) = 'E' AND AddWho = @c_hikey)
    BEGIN
          INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType, sourcekey )
          VALUES ( @c_hikey, 'There are invalid externreceiptkeys and/or storerkey' , 'GENERAL', ' ')
          SELECT @n_err = @@ERROR
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspImportReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
          END
    END
 END -- @n_continue
 -- END OF VALIDATION SECTION
 Declare @c_lastexternreceiptkey    NVARCHAR(30),
         @c_currentexternreceiptkey NVARCHAR(30),
         @c_receiptkey              NVARCHAR(10),
         @c_receiptlinenumber       NVARCHAR(5),
         @c_receiptdate             NVARCHAR(10),
         @c_effectivedate           NVARCHAR(10)

 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
 select @c_lastexternreceiptkey = ''
 -- the date format is yyyymmdd   
 DECLARE cur_mas CURSOR FAST_FORWARD READ_ONLY FOR 
 SELECT dbo.fnc_RTrim(dbo.fnc_LTrim(ExternReceiptkey)), STORERKEY,  convert(char(10), RECEIPTDATE) , convert(char(10), EFFECTIVEDATE)
 FROM WMSRCM
 WHERE WMS_FLAG = 'N'
 OPEN cur_mas
 WHILE (1 = 1) --(@@FETCH_STATUS <> -1)
 BEGIN
    FETCH NEXT FROM cur_mas INTO @c_currentexternreceiptkey , @c_storerkey , @c_receiptdate, @c_effectivedate
    IF @@FETCH_STATUS <> 0 BREAK
    IF @c_lastexternreceiptkey <> @c_currentexternreceiptkey
    BEGIN
       -- generate a new receiptkey
       IF @n_continue = 1 OR @n_continue = 2
       BEGIN
          SELECT @b_success = 0
          EXECUTE nspg_GetKey
          "receipt",
          10,
          @c_receiptkey OUTPUT,
          @b_success   	 OUTPUT,
          @n_err       	 OUTPUT,
          @c_errmsg    	 OUTPUT
          IF NOT @b_success = 1
          BEGIN
             SELECT @n_continue = 3
          END
       END
 --       SELECT @c_receiptlinenumber = 1
    END
    -- change the date format, from AS/400, it's numeric
    IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_receiptdate)) = '0'
    BEGIN
      SELECT @c_receiptdate = convert ( NVARCHAR(10), getdate(), 101)   
    END
    ELSE
    BEGIN      -- yyyymmdd
       SELECT @c_receiptdate = SUBSTRING(@c_receiptdate, 5,2) + '/' + SUBSTRING(@c_receiptdate, 7,2) + '/' + Substring(@c_receiptdate, 1,4)
    END
    IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_effectivedate)) = '0'
    BEGIN
      SELECT @c_effectivedate = convert ( NVARCHAR(10), getdate(), 101)   
    END
    ELSE
    BEGIN      -- yyyymmdd
       SELECT @c_effectivedate = SUBSTRING(@c_effectivedate, 5,2) + '/' + SUBSTRING(@c_effectivedate, 7,2) + '/' + Substring(@c_effectivedate, 1,4)
    END
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       INSERT INTO RECEIPT ( ReceiptKey, ExternReceiptKey, ReceiptGroup, StorerKey, ReceiptDate, POKey,CarrierKey, 
                             CarrierName, CarrierAddress1, CarrierAddress2, CarrierCity, CarrierState, CarrierZip, 
                             CarrierReference, WarehouseReference, OriginCountry , DestinationCountry, VehicleNumber,
                             PlaceOfLoading, PlaceOfDischarge, PlaceofDelivery, IncoTerms,  TermsNote, ContainerKey, 
                             Signatory, PlaceofIssue, OpenQty, Status, Notes, Effectivedate, ContainerType, 
                             ContainerQty, BilledContainerQty, RECType, ASNStatus )
       SELECT @c_receiptkey, dbo.fnc_RTrim(dbo.fnc_LTrim(ExternReceiptkey)), RECEIPTGROUP, STORERKEY, convert( datetime, @c_receiptdate) , POKEY, CARRIERKEY,
              CARRIERNAME ,CARRIERADDRESS1 , CARRIERADDRESS2, CARRIERCITY, CARRIERSTATE, CARRIERZIP,
              CARRIERREFERENCE, WAREHOUSEREFERENCE, ORIGINCOUNTRY, DESTINATIONCOUNTRY,VEHICLENUMBER, 
              PLACEOFLOADING, PLACEOFDISCHARGE, PLACEOFDELIVERY, INCOTERMS,  TERMSNOTE, CONTAINERKEY,
              SIGNATORY, PLACEOFISSUE,0,  '0' , NOTES, convert (datetime, @c_effectivedate) , CONTAINERTYPE, 
              CONTAINERQTY, BILLEDCONTAINERQTY, 
              case
             	  when rectype > '' then rectype
                 else 'NORMAL'
              end ,
 				  '0'
       FROM WMSRCM
       WHERE WMS_FLAG = 'N'
       AND ExternReceiptkey = @c_currentexternReceiptkey 
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62103   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Receipt (nspImportReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
       -- update the original table, to indicate that the receipt header has been successfully downloaded   
       IF @n_continue = 1 OR @n_continue = 2
       BEGIN
          UPDATE WMSRCM
          SET Receiptkey = @c_receiptkey, WMS_FLAG = 'R'
          WHERE ExternReceiptkey = @c_currentexternreceiptkey
          SELECT @n_err = @@ERROR
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62111   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On WMSRCM (nspImportReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
          END
       END 
       -- send confirmation back to ILS, indicating this externreceiptkey has been successfully downloaded.
       IF @n_continue = 1 OR @n_continue = 2
       BEGIN
          INSERT INTO WMS_DAILY..ASNConf (ExternReceiptkey)
          VALUES ( @c_currentExternReceiptkey)
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62113   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to insert Confirmation record(nspImportReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
          END
       END
       IF @n_continue = 1 OR @n_continue = 2
       BEGIN
          SELECT @c_receiptlinenumber = 1
          declare @c_lottable04 NVARCHAR(10), @c_lottable05 NVARCHAR(10), @c_det_externreceiptkey NVARCHAR(30), @c_det_storerkey NVARCHAR(15),
                  @c_det_sku NVARCHAR(20) , @c_packkey NVARCHAR(10), @c_externlineno NVARCHAR(20)
          -- inserting lines into receiptdetail, have to use cursor
          DECLARE CUR_Det CURSOR FAST_FORWARD READ_ONLY FOR
          SELECT dbo.fnc_RTrim(dbo.fnc_LTrim(ExternReceiptkey)), Storerkey, SKU, convert(char(10), Lottable04 ), Convert (char(10), Lottable05), 
                convert (char(10), Effectivedate ), ExternLineNo
          FROM WMSRCD
          WHERE ExternReceiptkey = @c_currentexternReceiptkey
          AND WMS_FLAG = 'N'
          OPEN cur_det
          WHILE (1 = 1) --(@@FETCH_STATUS <> -1) or ( @n_continue <> '3' )
          BEGIN 
             FETCH NEXT FROM cur_det INTO @c_det_externreceiptkey , @c_det_storerkey , @c_det_sku, @c_lottable04, @c_lottable05, 
                                       @c_effectivedate, @c_externlineno        
 	          IF @@Fetch_Status <> 0 BREAK
             -- get the packkey
             SELECT @c_packkey = PACKKEY 
             FROM SKU (NOLOCK)
             WHERE SKU = @c_det_sku   
             AND   Storerkey = @c_det_storerkey 

             -- convert the lottable04 and lottable05 if any
             IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable04)) = '0'
             BEGIN
               SELECT @c_lottable04 = '' -- null
             END
             ELSE
             BEGIN      -- yyyymmdd
                SELECT @c_lottable04 = SUBSTRING(@c_lottable04, 5,2) + '/' + SUBSTRING(@c_lottable04, 7,2) + '/' + Substring(@c_lottable04, 1,4)
             END            
             IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable05)) = '0'
             BEGIN
               SELECT @c_lottable05 = '' -- null
             END
             ELSE
             BEGIN      -- yyyymmdd
                SELECT @c_lottable05 = SUBSTRING(@c_lottable05, 5,2) + '/' + SUBSTRING(@c_lottable05, 7,2) + '/' + Substring(@c_lottable05, 1,4)
             END            
             IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_effectivedate)) = '0'
             BEGIN
               SELECT @c_effectivedate = convert ( NVARCHAR(10), getdate(), 101)   
             END
             ELSE
             BEGIN      -- yyyymmdd
                SELECT @c_effectivedate = SUBSTRING(@c_effectivedate, 5,2) + '/' + SUBSTRING(@c_effectivedate, 7,2) + '/' + Substring(@c_effectivedate, 1,4)
             END
             -- Obtain packuom3 from pack table
             declare @c_uom NVARCHAR(10)             
             SELECT @c_uom = PACKUOM3 
             FROM PACK (NOLOCK) 
             JOIN SKU (NOLOCK) ON (PACK.PACKKEY = SKU.PACKKEY) 
             WHERE SKU.sku = @c_det_sku 
               and SKU.storerkey = @c_det_storerkey


             -- generate the receiptlinenumber 
             select @c_receiptlinenumber = convert (char(5), replicate ('0', ( 5 - len(@c_receiptlinenumber))) + @c_receiptlinenumber)    
             INSERT INTO RECEIPTDETAIL ( ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, StorerKey, 
                                         POKey, Sku, AltSku, Id, Status, QtyExpected, QtyAdjusted, Toloc,
                                         UOM, PackKey , SubReasonCode, Lottable01, Lottable02, Lottable03, 
                                         Lottable04, Lottable05, EffectiveDate, Finalizeflag, Toid)
             SELECT @c_receiptkey, @c_receiptlinenumber, @c_currentexternreceiptkey, @c_externlineno, STORERKEY, 
                    POKEY, SKU, ALTSKU, ID, '0', QTYEXPECTED , QTYADJUSTED, TOLOC,
                    @c_uom, @c_packkey , SubReasonCode, LOTTABLE01, LOTTABLE02, LOTTABLE03, 
                    convert(datetime, @c_lottable04), Convert(datetime, @c_LOTTABLE05),
                    convert(datetime, @c_effectivedate),'N', TOID 
             FROM WMSRCD
             WHERE WMS_FLAG = 'N'
             AND ExternReceiptkey = @c_currentexternreceiptkey
             AND ExternLineNo = @c_externLineno
 --            AND SKU = @c_det_sku
             SELECT @n_err = @@ERROR
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62104   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On ReceiptDetail (nspImportReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
             END
             -- update the status WMSRCD after it has been successfully inserted into receiptdetail table.
             IF @n_continue = 1 OR @n_continue = 2
             BEGIN
                UPDATE WMSRCD
                SET Receiptkey = @c_receiptkey, Receiptlinenumber = @c_receiptlinenumber, WMS_FLAG = 'R'
                WHERE ExternReceiptkey = @c_currentexternreceiptkey
                AND ExternLineno = @c_externlineno
                SELECT @n_err = @@ERROR
                IF @n_err <> 0
                BEGIN
                   SELECT @n_continue = 3
                   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On WMSRCD (nspImportReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                END
             END
             SELECT @c_receiptlinenumber = @c_receiptlinenumber + 1  
          END -- end while for detail
 	CLOSE cur_det
 	DEALLOCATE cur_det
       END 
    END
    SELECT @c_lastexternreceiptkey = @c_currentexternreceiptkey
 END -- while
 CLOSE cur_mas
 DEALLOCATE cur_mas
END -- @n_continue 
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
   INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
   VALUES ( @c_hikey, ' -> nspImportReceipt . Process completed for ' + @c_hikey + '. Process ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspImportReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
 END
 IF @n_continue=3  -- Error Occured - Process And Return
 BEGIN
    SELECT @b_success = 0
    IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
    BEGIN
       ROLLBACK TRAN
    END
    ELSE
    BEGIN
       WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
             COMMIT TRAN
       END
    END
    execute nsp_logerror @n_err, @c_errmsg, "nspImportReceipt"
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
    RETURN
 END
 ELSE
 BEGIN
    SELECT @b_success = 1
    WHILE @@TRANCOUNT > @n_starttcnt
    BEGIN
       COMMIT TRAN
    END
    RETURN
 END
 END -- end of procedure

GO