SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****** Object:  Stored Procedure dbo.nspRFRC07    Script Date: 18/10/2000 11:56:51 ******/
CREATE PROC    [dbo].[nspRFRC07]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,	       @c_storer	   NVARCHAR(15)
,	       @c_epo		   NVARCHAR(20)
,              @c_sku       	   NVARCHAR(30)
,              @c_lot2       	   NVARCHAR(18)
,              @c_cnt      	   NVARCHAR(20)
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
/*IF @b_debug = 1
BEGIN
SELECT @c_asn "@c_asn"
END */
DECLARE  @n_continue int        ,  
@n_starttcnt int        , -- Holds the current transaction count
@c_preprocess NVARCHAR(250) , -- preprocess
@c_pstprocess NVARCHAR(250) , -- post process
@n_err2 int               -- For Additional Error Detection
DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
DECLARE @c_dbnamestring NVARCHAR(255)
DECLARE @n_cqty int, @n_returnrecs int
SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
SELECT @c_retrec = "01"
SELECT @n_returnrecs=1
DECLARE @c_itrnkey NVARCHAR(10), @n_toqty int, @c_NoDuplicateIdsAllowed NVARCHAR(10), @c_lotbatch NVARCHAR(18), 
@c_tariffkey NVARCHAR(10), @c_ReceiptLineNumber NVARCHAR(5),
@c_prevlinenumber NVARCHAR(5), @c_multiline NVARCHAR(1)
SELECT  @c_prevlinenumber = master.dbo.fnc_GetCharASCII(14), @c_multiline = '0'
     /* #INCLUDE <SPRFRC01_1.SQL> */     

DECLARE @c_uom NVARCHAR(10), @c_packkey NVARCHAR(10), @c_receiptkey NVARCHAR(10)

IF @b_debug = 1
BEGIN
SELECT @c_sku 'SKU'
END 
  
IF @n_continue=1 OR @n_continue=2
BEGIN
  execute   nspg_GETSKU2
                @c_Storer   
 ,              @c_sku                   OUTPUT
 ,              @b_success               OUTPUT
 ,              @n_err                   
 ,              @c_errmsg                
 ,              @c_uom                   OUTPUT
 ,              @c_packkey               OUTPUT

	IF @b_debug = 1
	BEGIN
	SELECT @c_sku 'SKU'
	END 

  IF @b_success <> 1 
  BEGIN     
     SELECT @n_continue = 3
     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=95001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid SKU. (nspRFRC07)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
  END
  ELSE 
  BEGIN 
	  IF @c_packkey is null 
	  BEGIN 
	  	  Select @c_packkey = Packkey From Sku (nolock) 
		   Where Storerkey = @c_storer 
		     And Sku = @c_sku 
	  END 
	  IF @c_uom is null 
	  BEGIN 
	  	  Select @c_uom = PackUOM3 From Pack (nolock) 
		   Where Packkey = @c_packkey 
	  END
  END
END

-- check non-duplicate caseid (barcode)    
IF @n_continue=1 OR @n_continue=2
BEGIN  
	-- To skip the last char of Lottable02 (Shift) for PMTL 
	SELECT @c_lotbatch = @c_lot2 
	SELECT @c_lot2 = Substring(@c_lot2, 1, len(@c_lot2) - 1) 

	IF @b_debug = 1
	BEGIN
		SELECT @c_storer 'Storer', @c_sku 'Sku', @c_epo 'PO', @c_cnt 'caseid', @c_lotbatch 'batch'
	END 

	IF EXISTS(SELECT 1      
					FROM RECEIPTDETAIL RD (nolock), LotxIddetail LI (Nolock)  
					WHERE RD.Receiptkey = LI.Receiptkey 
					AND RD.Receiptlinenumber = LI.Receiptlinenumber 
					AND RD.STORERKEY = @c_storer AND RD.SKU = @c_sku AND RD.externpokey = @c_epo 
					AND LI.Other2 = dbo.fnc_RTrim(@c_cnt) and LI.Other3 = dbo.fnc_RTrim(@c_lotbatch)) 
	BEGIN 
  	     SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=95002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Case ID already exists in ASN. (nspRFRC07)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
	END

/*
 	 DECLARE caseid_cur CURSOR FOR      
      SELECT receiptkey, receiptlinenumber     
      FROM RECEIPTDETAIL (nolock) WHERE STORERKEY = @c_storer AND SKU = @c_sku AND LOTTABLE02 = @c_lot2 AND externpokey = @c_epo
    
      OPEN caseid_cur

      FETCH NEXT FROM caseid_cur INTO  @c_receiptkey, @c_receiptlinenumber
 
      WHILE (@@FETCH_STATUS <> -1)

      BEGIN	             
		  IF EXISTS(SELECT 1 FROM LOTXIDDETAIL(NOLOCK) WHERE RECEIPTKEY = @c_receiptkey 
												AND RECEIPTLINENUMBER = @c_receiptlinenumber AND Other2 = dbo.fnc_RTrim(@c_cnt) AND Other3 = dbo.fnc_RTrim(@c_lotbatch))
        BEGIN
	  	     SELECT @n_continue = 3
    	     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=95002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
    	     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Case ID already exists in ASN:" + @c_receiptkey+""+@c_receiptlinenumber + ". (nspRFRC07)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 	        BREAK
	     END

        FETCH NEXT FROM caseid_cur INTO @c_receiptkey, @c_receiptlinenumber
     END -- while
     CLOSE caseid_cur	
     DEALLOCATE caseid_cur   
*/
END  



IF @n_continue=3
BEGIN
  IF @c_retrec="01"
  BEGIN
    SELECT @c_retrec="09"
  END
END
ELSE
BEGIN
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
+ dbo.fnc_RTrim(@c_uom)              + @c_senddelimiter
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
  execute nsp_logerror @n_err, @c_errmsg, "nspRFRC07"
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