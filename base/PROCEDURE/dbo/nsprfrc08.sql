SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****** Object:  Stored Procedure dbo.nspRFRC08    Script Date: 18/10/2000 11:56:51 ******/
CREATE PROC    [dbo].[nspRFRC08]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,	       @c_storer	   NVARCHAR(15)
,              @c_asn       	   NVARCHAR(10)
,              @c_muid		   NVARCHAR(18)
,	       @c_epo		   NVARCHAR(20)
,              @c_sku       	   NVARCHAR(30)
,              @c_lot2       	   NVARCHAR(18)
,              @c_cnt      	   NVARCHAR(20)
,              @n_qty		   int
,	       @c_uom		   NVARCHAR(10)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @b_debug int
SELECT @b_debug = 0
IF @c_taskId = 'DS1'
BEGIN
SELECT @b_debug = 1
END
--IF @b_debug = 1
--BEGIN
--SELECT @c_receiptkey "@c_receiptkey"
--END
DECLARE  @n_continue int        ,  
@n_starttcnt int        , -- Holds the current transaction count
@c_preprocess NVARCHAR(250) , -- preprocess
@c_pstprocess NVARCHAR(250) , -- post process
@n_err2 int               -- For Additional Error Detection
DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
DECLARE @c_dbnamestring NVARCHAR(255)
DECLARE @n_vqty int, @n_returnrecs int
DECLARE @d_nx_mth datetime, @d_lottable04 datetime 
DECLARE @c_lotbatch NVARCHAR(18)
SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
SELECT @c_retrec = "01"
SELECT @n_returnrecs=1

     /* #INCLUDE <SPRFRC01_1.SQL> */     

DECLARE @c_packkey     	 NVARCHAR(10), @c_uom1 NVARCHAR(10), 
	@n_expectedqty		int,
	@c_receiptlinenumber NVARCHAR(5),	
    	@c_newLineNumber NVARCHAR(5),
	@c_bcsku	 NVARCHAR(30),
	@c_LotxIdDetailKey  NVARCHAR(10),
	@c_year 	 NVARCHAR(1),
	@n_JD			int,
	@c_lottable02 	 NVARCHAR(18),
	@c_lottable03 	 NVARCHAR(18),
	@dt_lottable04 		datetime, 
	@dt_lottable03 		datetime,
	@dt_lottable05 		datetime, 
	@c_ioflag 	 NVARCHAR(1)

SELECT @c_bcsku = @c_sku


-- To Check non-mixing of batch within the Pallet ID
IF @n_continue=1 OR @n_continue=2
BEGIN   
	Declare @n_mixbatchidcnt int, @c_mixbatchidcnt NVARCHAR(8)
	Select @n_mixbatchidcnt = Count(distinct substring(other3,1,8)) From Lotxiddetail (nolock) 
	 Where ID = @c_muid 
	
	IF @n_mixbatchidcnt = 1 
	BEGIN 
		Select @c_mixbatchidcnt = Substring(other3,1,8) From Lotxiddetail (nolock) 
		 Where ID = @c_muid 
		IF @c_mixbatchidcnt <> Substring(@c_lot2,1,8) 
		BEGIN     
		  SELECT @n_continue = 3
		  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=97011   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Mix Batch Found. (nspRFRC08)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
		END
	END
	ELSE 
	IF @n_mixbatchidcnt > 1
	BEGIN 
		  SELECT @n_continue = 3
		  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=97021   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Mix Batch Found. (nspRFRC08)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "		
	END
END

-- To Check Pallet already full
IF @n_continue=1 OR @n_continue=2
BEGIN   
	IF EXISTS(Select 1 From Id (nolock), PACK (Nolock) 
				 Where ID.Packkey = Pack.Packkey 
			      And ID = @c_muid 
				   And ID.Qty >= Pack.pallet)

	BEGIN     
	  SELECT @n_continue = 3
	  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=97031   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Max Qty Found in Pallet. (nspRFRC08)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
	END
END


/* get sku */
IF @n_continue=1 OR @n_continue=2
BEGIN
  execute   nspg_GETSKU2
                @c_Storer   
 ,              @c_sku                   OUTPUT
 ,              @b_success               OUTPUT
 ,              @n_err                   
 ,              @c_errmsg                
 ,              @c_uom1                   
 ,              @c_packkey               

  IF @b_success <> 1 
  BEGIN     
     SELECT @n_continue = 3
     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=97001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid SKU. (nspRFRC08)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
  END
  ELSE 
  BEGIN 
	  IF @c_packkey is null 
	  BEGIN 
	  	  Select @c_packkey = Packkey From Sku (nolock) 
		   Where Storerkey = @c_storer 
		     And Sku = @c_sku 
	  END 
	  IF @c_uom1 is null 
	  BEGIN 
	  	  Select @c_uom1 = PackUOM3 From Pack (nolock) 
		   Where Packkey = @c_packkey 
	  END
  END
END

-- Check Valid UOM
IF @n_continue=1 OR @n_continue=2
BEGIN
	IF NOT EXISTS(Select 1 FROM SKU(nolock), PACK(nolock)
	     WHERE SKU = @c_sku and STORERKEY = @c_storer
	     AND SKU.PACKKEY = PACK.PACKKEY 
		  AND @c_uom IN (PACK.PackUOM1, PACK.PackUOM2,PACK.PackUOM3,PACK.PackUOM4,PACK.PackUOM4,PACK.PackUOM6,
			PACK.PackUOM7,PACK.PackUOM8,PACK.PackUOM9))
	BEGIN
		SELECT @n_continue = 3
		SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=97021   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid UOM (nspRFRC08)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
	END
END

-- select @c_sku

IF @n_continue=1 OR @n_continue=2
BEGIN
  IF NOT EXISTS(SELECT 1 FROM RECEIPTDETAIL(nolock)
		WHERE RECEIPTDETAIL.RECEIPTKEY = @c_asn AND 
		RECEIPTDETAIL.SKU = @c_sku AND
		RECEIPTDETAIL.STORERKEY = @c_storer AND		
		RECEIPTDETAIL.TOID = @c_muid AND 
		RECEIPTDETAIL.QTYRECEIVED = 0)
  BEGIN
    SELECT @n_continue = 3
    SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=97002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No receipt details to be received (nspRFRC08)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
  END
END

IF @n_continue=1 OR @n_continue=2
BEGIN

-- To skip the last char of Lottable02 (Shift) for PMTL 
-- Calculate the lottable here ********************************

SELECT @c_lotbatch = @c_lot2 

SELECT @c_lot2 = Substring(@c_lot2, 1, len(@c_lot2) - 1)
SELECT @c_year = substring(@c_lot2, 5,1)
SELECT @n_JD = convert(int,substring(@c_lot2, 6,3)) - 1
SELECT @dt_lottable03 = dateadd(day,@n_JD,convert(datetime,(substring(convert(char(4),datepart(yyyy,getdate())),1,3) + @c_year + "0101")))
-- SELECT @c_lottable03 = convert(char(18),dateadd(day,@n_JD,convert(datetime,(substring(convert(char(4),datepart(yyyy,getdate())),1,3) + @c_year + "0101"))),103)

select @c_lottable02 = convert(char(4), datepart(year, @dt_lottable03)) 
+ (replicate('0', 2-len(convert(char(2), datepart(wk, @dt_lottable03)))) +
convert(char(2), datepart(wk, @dt_lottable03)))

SELECT @dt_lottable04 = dateadd(yyyy,1,@dt_lottable03)

select @c_lottable03 = convert(char(4), datepart(year, @dt_lottable04)) 
+ (replicate('0', 2-len(convert(char(2), datepart(wk, @dt_lottable04)))) +
convert(char(2), datepart(wk, @dt_lottable04)))


SELECT @dt_lottable05 = convert(char(11), getdate(),106)

SELECT @n_qty = CASE 
                    WHEN @c_uom = PACK.PackUOM1
                    THEN (@n_qty * PACK.CaseCnt)
                    WHEN @c_uom = PACK.PackUOM2
                    THEN (@n_qty * PACK.InnerPack)
                    WHEN @c_uom = PACK.PackUOM3
                    THEN (@n_qty)
                    WHEN @c_uom = PACK.PackUOM4
                    THEN ( @n_qty * PACK.Pallet)
                    WHEN @c_uom = PACK.PackUOM5
                    THEN ( @n_qty * PACK.Cube)
                    WHEN @c_uom = PACK.PackUOM6
                    THEN (@n_qty * PACK.GrossWgt)
                    WHEN @c_uom = PACK.PackUOM7
                    THEN ( @n_qty * PACK.NetWgt)
                    WHEN @c_uom = PACK.PackUOM8
                    THEN (@n_qty * PACK.OtherUnit1)
                    WHEN @c_uom = PACK.PackUOM9
                    THEN ( @n_qty * PACK.OtherUnit2)
                    ELSE (@n_qty)
                    END,
	@c_ioflag = SKU.IOFLAG
     FROM SKU(nolock), PACK(nolock)
     WHERE SKU = @c_sku and STORERKEY = @c_storer
     AND SKU.PACKKEY = PACK.PACKKEY 

END

--select 'storer =', @c_storer
--select 'sku = ', @c_sku
--select 'uom=', @c_uom
--select 'qty=', @n_qty

IF @n_continue=1 OR @n_continue=2
BEGIN
  IF EXISTS(SELECT 1 FROM RECEIPTDETAIL(nolock)
     WHERE RECEIPTDETAIL.STORERKEY = @c_storer AND
	   RECEIPTDETAIL.RECEIPTKEY = @c_asn AND 	   	   
	   RECEIPTDETAIL.SKU = @c_sku AND 
	   RECEIPTDETAIL.QTYRECEIVED = 0 AND	 
		RECEIPTDETAIL.TOID = @c_muid  AND 
	   RECEIPTDETAIL.QTYEXPECTED >= @n_qty)	   
  BEGIN
    SELECT @n_expectedqty = RECEIPTDETAIL.QTYEXPECTED,
           @c_receiptlinenumber = RECEIPTDETAIL.RECEIPTLINENUMBER

     FROM RECEIPTDETAIL(nolock), SKU(nolock), PACK(nolock)
     WHERE RECEIPTDETAIL.STORERKEY = @c_storer AND
	   RECEIPTDETAIL.RECEIPTKEY = @c_asn AND 	   	   
	   RECEIPTDETAIL.SKU = @c_sku AND
	   RECEIPTDETAIL.QTYRECEIVED = 0 AND
	   RECEIPTDETAIL.SKU = SKU.SKU AND
	   RECEIPTDETAIL.STORERKEY = SKU.STORERKEY AND
	   SKU.PACKKEY = PACK.PACKKEY AND
	   RECEIPTDETAIL.QTYEXPECTED >= @n_qty AND 
		RECEIPTDETAIl.TOID = @c_muid 
	   ORDER BY RECEIPTDETAIL.QTYEXPECTED DESC

    IF @n_expectedqty > @n_qty
    BEGIN   
      SELECT @c_newLineNumber = SUBSTRING(dbo.fnc_LTrim(STR(CONVERT(int, ISNULL(MAX(ReceiptLineNumber), "0")) + 1 + 100000)),2,5)
      FROM RECEIPTDETAIL(NOLOCK) WHERE RECEIPTKEY = @c_asn
	
      INSERT RECEIPTDETAIL       
		(
		ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, StorerKey, POKey, Sku, AltSku,
		Id, Status, DateReceived, QtyExpected, QtyReceived, UOM, PackKey, VesselKey,
		VoyageKey, XdockKey, ContainerKey, ToLoc, ToLot, ToID, ConditionCode, Lottable01, Lottable02,
		Lottable03, Lottable04, Lottable05, CaseCnt, InnerPack, Pallet, Cube, GrossWgt, NetWgt,
		OtherUnit1, OtherUnit2, UnitPrice, ExtendedPrice, EffectiveDate,	
		TariffKey, FreeGoodQtyExpected, FreeGoodQtyReceived, SubReasonCode, FinalizeFlag, DuplicateFrom,
		BeforeReceivedQty, PutawayLoc, ExportStatus, SplitPalletFlag, POLineNumber, LoadKey
		)
		SELECT
		@c_asn,                       
		@c_newLineNumber, 	         
		ExternReceiptKey, ExternLineNo, StorerKey, POKey, Sku, AltSku,
		Id, Status, DateReceived, (@n_expectedqty - @n_qty), 0, UOM, PackKey, VesselKey,
		VoyageKey, XdockKey, ContainerKey, ToLoc, ToLot, TOID, ConditionCode, Lottable01, Lottable02,
		Lottable03, Lottable04, Lottable05, CaseCnt, InnerPack, Pallet, Cube, GrossWgt, NetWgt,
		OtherUnit1, OtherUnit2, UnitPrice, ExtendedPrice, EffectiveDate,
		TariffKey, FreeGoodQtyExpected, FreeGoodQtyReceived, SubReasonCode, FinalizeFlag, DuplicateFrom,
		BeforeReceivedQty, PutawayLoc, ExportStatus, SplitPalletFlag, POLineNumber, LoadKey	
		FROM RECEIPTDETAIL(NOLOCK) WHERE RECEIPTKEY = @c_asn AND RECEIPTLINENUMBER = @c_receiptlinenumber 

		UPDATE RECEIPTDETAIL
		SET QTYEXPECTED = @n_qty, QTYRECEIVED = @n_qty, TOID = RIGHT(@c_muid, 18),
		EXTERNPOKEY = @c_epo, LOTTABLE02 = @c_lottable02,
		LOTTABLE05 = @dt_lottable05,
		-- BCCASEID = dbo.fnc_RTrim(@c_epo) + dbo.fnc_RTrim(@c_bcsku) + dbo.fnc_RTrim(@c_lot2) + dbo.fnc_RTrim(@c_cnt),
		LOTTABLE03 = @c_lottable03, LOTTABLE04 = NULL, FINALIZEFLAG = "Y"
		WHERE RECEIPTKEY = @c_asn AND RECEIPTLINENUMBER = @c_receiptlinenumber 
		SELECT @n_err = @@ERROR
		IF @n_err <> 0
		BEGIN
		 SELECT @n_continue = 3
		 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=97003   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Receiptdetail. (nspRFRC08)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
		END   	     
   END -- qtyexpected > @n_qty
   ELSE
--   IF @n_expectedqty = @n_qty
   BEGIN
     UPDATE RECEIPTDETAIL
     SET QTYRECEIVED = @n_qty, TOID = RIGHT(@c_muid, 18), 
         EXTERNPOKEY = @c_epo, LOTTABLE02 = @c_lottable02,
         LOTTABLE05 = @dt_lottable05,
	 -- BCCASEID = dbo.fnc_RTrim(@c_epo) + dbo.fnc_RTrim(@c_bcsku) + dbo.fnc_RTrim(@c_lot2) + dbo.fnc_RTrim(@c_cnt),
	 LOTTABLE03 = @c_lottable03, LOTTABLE04 = NULL, FINALIZEFLAG = "Y"
     WHERE RECEIPTKEY = @c_asn AND RECEIPTLINENUMBER = @c_receiptlinenumber 

     SELECT @n_err = @@ERROR
     IF @n_err <> 0
     BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=97004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Receiptdetail. (nspRFRC08)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
     END        
   END -- equal 
END -- IF EXISTS qtyexpected >= qty
ELSE
  IF EXISTS(SELECT 1 FROM RECEIPTDETAIL(nolock)
     WHERE RECEIPTDETAIL.STORERKEY = @c_storer AND
	   RECEIPTDETAIL.RECEIPTKEY = @c_asn AND 	   	   
	   RECEIPTDETAIL.SKU = @c_sku AND
	   RECEIPTDETAIL.QTYRECEIVED = 0 AND	
	   RECEIPTDETAIL.QTYEXPECTED < @n_qty)
  BEGIN
    SELECT @n_expectedqty = RECEIPTDETAIL.QTYEXPECTED,
           @c_receiptlinenumber = RECEIPTDETAIL.RECEIPTLINENUMBER

     FROM RECEIPTDETAIL(nolock), SKU(nolock), PACK(nolock)
     WHERE RECEIPTDETAIL.STORERKEY = @c_storer AND
	   RECEIPTDETAIL.RECEIPTKEY = @c_asn AND 	   	   
	   RECEIPTDETAIL.SKU = @c_sku AND
	   RECEIPTDETAIL.QTYRECEIVED = 0 AND
	   RECEIPTDETAIL.SKU = SKU.SKU AND
	   RECEIPTDETAIL.STORERKEY = SKU.STORERKEY AND 
		RECEIPTDETAIL.TOID = @c_muid  AND 
	   SKU.PACKKEY = PACK.PACKKEY AND
	   RECEIPTDETAIL.QTYEXPECTED < @n_qty
	   ORDER BY RECEIPTDETAIL.QTYEXPECTED

     UPDATE RECEIPTDETAIL
     SET QTYRECEIVED = @n_qty, TOID = RIGHT(@c_muid, 18), 
         EXTERNPOKEY = @c_epo, LOTTABLE02 = @c_lottable02,
         LOTTABLE05 = @dt_lottable05,
	 -- BCCASEID = dbo.fnc_RTrim(@c_epo) + dbo.fnc_RTrim(@c_bcsku) + dbo.fnc_RTrim(@c_lot2) + dbo.fnc_RTrim(@c_cnt),
	 LOTTABLE03 = @c_lottable03, LOTTABLE04 = NULL, FINALIZEFLAG = "Y"
	 WHERE RECEIPTKEY = @c_asn AND RECEIPTLINENUMBER = @c_receiptlinenumber 

     SELECT @n_err = @@ERROR
     IF @n_err <> 0
     BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=97005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Receiptdetail. (nspRFRC08)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
     END        
  END
  -- insert lotxiddetail
  IF @n_continue=1 OR @n_continue=2
  BEGIN
    IF @c_ioflag = 'I' OR @c_ioflag = 'B'
    BEGIN
	EXECUTE   nspg_getkey
	   "LotxIdDetailKey"
	   , 10
	   , @c_LotxIdDetailKey OUTPUT
	   , @b_success OUTPUT
	   , @n_err OUTPUT
	   , @c_errmsg OUTPUT
	IF @b_success = 1
	BEGIN 
		

	  INSERT LOTXIDDETAIL (LOTXIDDETAILKEY,RECEIPTKEY,RECEIPTLINENUMBER,IOFLAG,ID,Other2, Other3, WGT)
		 VALUES       (@c_LotxIdDetailKey, @c_asn, @c_receiptlinenumber, 'I', @c_muid, dbo.fnc_RTrim(@c_cnt), dbo.fnc_RTrim(@c_lotbatch), 0)
	  SELECT @n_err = @@ERROR
          IF @n_err <> 0
          BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=97006   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Lotxiddetail. (nspRFRC08)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
          END   
	END
    END
  END	
	   

END -- continue

IF @n_continue=3
BEGIN
  IF @c_retrec="01"
  BEGIN
    SELECT @c_retrec="09"
  END
END
ELSE
BEGIN
-- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_id)) IS NOT NULL
-- BEGIN
--      SELECT @c_errmsg = "Receipt Ok.  Please press ENTER and fill out the additional information about this receipt."
--      SELECT @c_retrec = "02"
-- END
  IF @c_retrec = "" or @c_retrec = "09"
  BEGIN
    SELECT @c_retrec="01"
  END
END
     /* #INCLUDE <SPRFRC01_2.SQL> */
SELECT @c_outstring =   @c_ptcid        + @c_senddelimiter
+ dbo.fnc_RTrim(@c_userid)           + @c_senddelimiter
+ dbo.fnc_RTrim(@c_taskid)           + @c_senddelimiter
+ dbo.fnc_RTrim(@c_databasename)     + @c_senddelimiter
+ dbo.fnc_RTrim(@c_appflag)          + @c_senddelimiter
+ dbo.fnc_RTrim(@c_retrec)           + @c_senddelimiter
+ dbo.fnc_RTrim(@c_server)           + @c_senddelimiter
+ dbo.fnc_RTrim(@c_errmsg)
SELECT dbo.fnc_RTrim(@c_outstring) 
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
  execute nsp_logerror @n_err, @c_errmsg, "nspRFRC08"
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
END






GO