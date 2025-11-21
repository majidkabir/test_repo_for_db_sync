SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure isp_Patch_ReceiptToITRN : 
--

CREATE PROC [dbo].[isp_Patch_ReceiptToITRN]
AS
BEGIN
	DECLARE @n_continue 		  int
	      , @n_starttcnt		  int		-- Holds the current transaction count  
			, @b_debug		     int
			, @n_counter		  int
			, @c_ExecStatements nvarchar(4000)
         , @c_receiptkey     NVARCHAR(10)
         , @c_receiptlineno  NVARCHAR(5)
         , @c_storerkey      NVARCHAR(15)
         , @c_sku            NVARCHAR(20)
         , @b_Success	     int 
         , @n_err		        int 
         , @c_errmsg	        NVARCHAR(250)

	SET NOCOUNT ON

        SELECT @n_starttcnt = @@TRANCOUNT 
        
        SELECT @b_debug = 0
	     SELECT @b_success = 0
	     SELECT @n_continue = 1

     
        -- Start Looping Sku table 
 	     SELECT @c_sku = ''	
        SELECT @n_counter = 0


   WHILE @@TRANCOUNT > 0 
        COMMIT TRAN 
   
   IF @b_debug = 1
   BEGIN
	   select 'Check for records not in ITRN but FinalizeFlag = Y and insert to temp table'
   END
	
   SELECT r.Receiptkey, r.Receiptlinenumber, r.Storerkey, r.Sku, r.Qtyreceived, r.Beforereceivedqty
   INTO #TEMPASN
	FROM RECEIPTDETAIL r (nolock)
	LEFT OUTER JOIN ITRN i (nolock) on (i.Sourcekey = r.Receiptkey + r.Receiptlinenumber 
	AND  i.Trantype = 'DP' and i.Sourcetype like 'ntrReceiptDetail%')
	WHERE r.Finalizeflag = 'Y' and QtyReceived > 0 
	AND   i.Sourcekey is null
	AND   datediff(day, r.Editdate, getdate() ) < 90
	AND   datediff(minute, r.Editdate, getdate() ) > 5   
 
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT Receiptkey, Receiptlinenumber, Sku 
   FROM   #TEMPASN (NOLOCK)
   Order By Receiptkey, Receiptlinenumber

   OPEN CUR1

   FETCH NEXT FROM CUR1 INTO @c_receiptkey, @c_receiptlineno, @c_sku 
   
	WHILE (@n_continue=1)	
	BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT 'Receiptkey', @c_receiptkey 
         SELECT 'Receiptlineno', @c_receiptlineno 
         SELECT 'Sku', @c_sku 
      END

      IF @b_debug = 1 SELECT 'Started Get Receiptkey...'

      IF @b_debug = 1
      BEGIN
         SELECT 'Reversing finalize flag and qtyreceived for receipt...'
      END

      BEGIN TRAN

       UPDATE RECEIPTDETAIL
       SET Finalizeflag = 'N', 
           Qtyreceived = 0, 
           Trafficcop = NULL 
       FROM RECEIPTDETAIL (NOLOCK) 
       WHERE Receiptkey = @c_receiptkey
       AND   Receiptlinenumber = @c_receiptlineno
       AND   Sku = @c_sku

      IF @b_debug = 1
      BEGIN
         SELECT 'Reverse is Done!'
      END

      IF @b_debug = 1
      BEGIN
         SELECT 'Update finalize flag and qtyreceived for receipt...'
      END
         
      UPDATE RECEIPTDETAIL 
      SET Finalizeflag = 'Y', 
          Qtyreceived = Beforereceivedqty 
      FROM RECEIPTDETAIL (NOLOCK) 
      WHERE Receiptkey = @c_receiptkey
      AND   Receiptlinenumber = @c_receiptlineno
      AND   Sku = @c_sku

      IF @@ERROR = 0
      BEGIN 
        COMMIT TRAN
      END
      ELSE
      BEGIN
         ROLLBACK TRAN
         SELECT @n_continue = 3
         SELECT @n_err = 65002
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert records failed (isp_Patch_ReceiptToITRN)'  
      END
         FETCH NEXT FROM CUR1 INTO @c_receiptkey, @c_receiptlineno, @c_sku 
  END -- While 1=1 
  CLOSE CUR1
  DEALLOCATE CUR1 

	-- Drop Temp Table
--	DROP TABLE TMPTBLSKU2 


/* #INCLUDE <SPTPA01_2.SQL> */  
IF @n_continue=3  -- Error Occured - Process And Return  
BEGIN  
   SELECT @b_success = 0  
   IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt  
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

   EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_Patch_ReceiptToITRN'  
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