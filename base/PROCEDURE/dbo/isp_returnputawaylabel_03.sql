SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReturnPutawayLabel_03                          */
/* Creation Date: 18-JAN-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-7687-KR_HM_Return Label_Data Window_CR                  */
/*                                                                      */
/* Called By:                                                           */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_ReturnPutawayLabel_03]
   @c_ReceiptkeyFrom NVARCHAR(10),
   @c_ReceiptkeyTo NVARCHAR(10) = 'ZZZZZZZZZZ',
   @c_UserId NVARCHAR(20) = ''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_starttcnt INT,
           @b_success  int,
           @n_err      int,
           @c_errmsg   NVARCHAR(225) 
           
   DECLARE @c_storerkey NVARCHAR(15),
           @c_Sku NVARCHAR(20),
           @c_doctype NCHAR(1),
           @c_ReceiptLineNumber NVARCHAR(5),
           @n_Qty INT,
           @c_Lot NVARCHAR(10),
           @c_PutawayLoc NVARCHAR(10),
           @n_PABookingKey INT,
           @c_Status NVARCHAR(10),
           @c_FromLoc NVARCHAR(10),
           @c_FromID NVARCHAR(18),
           @c_Receiptkey NVARCHAR(10)
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   SELECT @c_doctype = Doctype, 
          @c_Status = Status
   FROM RECEIPT (NOLOCK)
   WHERE Receiptkey BETWEEN @c_ReceiptkeyFrom AND @c_ReceiptkeyTo    
   
   IF @c_DocType <> 'R' OR @c_Status <> '9'
   BEGIN
   	  SELECT @n_Continue = 4
      GOTO ENDPROC
   END
     
   BEGIN TRAN
   	
   CREATE TABLE #TMP_PABOOKING (PABookingKey INT NULL)
 
   DECLARE cur_RECEIPT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT R.Receiptkey, RD.Storerkey, RD.Sku, RD.ReceiptLineNumber, SUM(RD.QtyReceived) AS QtyReceived, ITRN.Lot, RD.ToLoc, RD.ToID
      FROM RECEIPT R (NOLOCK)
      JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey 
      JOIN ITRN (NOLOCK) ON ITRN.Storerkey = R.Storerkey AND ITRN.TranType = 'DP' AND ITRN.SourceType = 'ntrReceiptDetailUpdate'  
                         AND ITRN.Sourcekey = RD.Receiptkey + RD.ReceiptLineNumber
      WHERE R.Receiptkey BETWEEN @c_ReceiptkeyFrom AND @c_ReceiptkeyTo
      AND RD.Finalizeflag = 'Y'
      AND R.Doctype = 'R'
      --AND ISNULL(RD.PutawayLoc,'') = ''            
      GROUP BY R.Receiptkey, RD.Storerkey, RD.Sku, RD.ReceiptLineNumber, ITRN.Lot, RD.ToLoc, RD.ToID
      ORDER BY R.Receiptkey, RD.ReceiptLineNumber
            
   OPEN cur_RECEIPT  
   FETCH NEXT FROM cur_RECEIPT INTO @c_Receiptkey, @c_Storerkey, @c_Sku, @c_ReceiptLineNumber, @n_Qty, @c_Lot, @c_FromLoc, @c_FromID

   WHILE @@FETCH_STATUS = 0  
   BEGIN           	  
   	  SET @c_PutawayLoc = ''
   	  EXEC nspRDTPASTD @c_userid='', 
   	                   @c_storerkey=@c_Storerkey, 
   	                   @c_lot=@c_Lot ,
   	                   @c_sku=@c_Sku ,
   	                   @c_id=@c_FromID, 
   	                   @c_fromloc=@c_FromLoc , 
   	                   @n_qty=@n_Qty, 
   	                   @n_PutawayCapacity = 0,
   	                   @c_final_toloc = @c_PutawayLoc OUTPUT
   	                      	  
   	  IF ISNULL(@c_PutawayLoc,'') <> ''
   	  BEGIN
         SET @n_PABookingKey = 0  
         EXEC rdt.rdt_Putaway_PendingMoveIn  
             @cUserName     = 'WMS'  
            ,@cType         = 'LOCK'  
            ,@cFromLoc      = @c_FromLoc
            ,@cFromID       = @c_FromID
            ,@cSuggestedLOC = @c_PutawayLoc  
            ,@cStorerKey    = @c_StorerKey  
            ,@nErrNo        = @n_Err   OUTPUT  
            ,@cErrMsg       = @c_ErrMsg  OUTPUT  
            ,@cSKU          = @c_SKU  
            ,@nPutawayQTY   = @n_QTY  
            ,@nFunc         = 0 --523 
            ,@nPABookingKey = @n_PABookingKey OUTPUT  

         IF ISNULL(@n_PABookingKey,0) <> 0
         BEGIN
            INSERT INTO #TMP_PABOOKING (PABookingKey) 
            VALUES (@n_PABookingKey)
         END                           
      END            	
      
      IF ISNULL(@c_PutawayLoc,'') = ''
         SET @c_PutawayLoc = 'NONE'
         
      UPDATE RECEIPTDETAIL
      SET PutawayLoc = @c_PutawayLoc,
          Trafficcop = NULL
      WHERE Receiptkey = @c_Receiptkey
      AND ReceiptLineNumber = @c_ReceiptLineNumber
                               
      FETCH NEXT FROM cur_RECEIPT INTO @c_Receiptkey, @c_Storerkey, @c_Sku, @c_ReceiptLineNumber, @n_Qty, @c_Lot, @c_FromLoc, @c_FromID
   END
   CLOSE cur_RECEIPT  
   DEALLOCATE cur_RECEIPT                                   

   DECLARE cur_Book CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PABookingKey
      FROM #TMP_PABOOKING
   
   OPEN cur_Book  
   FETCH NEXT FROM cur_Book INTO @n_PABookingKey

   WHILE @@FETCH_STATUS = 0  
   BEGIN           	  
       IF @n_PABookingKey <> 0  
       BEGIN  
          EXEC rdt.rdt_Putaway_PendingMoveIn 
              @cUserName     = 'WMS'  
             ,@cType         = 'UNLOCK'  
             ,@cFromLoc      = ''
             ,@cFromID       = ''  
             ,@cSuggestedLOC = ''
             ,@cStorerKey    = ''
             ,@nErrNo        = @n_Err   OUTPUT  
             ,@cErrMsg       = @c_ErrMsg  OUTPUT  
             ,@cSKU          = ''
             ,@nPutawayQTY   = 0
             ,@nFunc         = 0--523 
             ,@nPABookingKey = @n_PABookingKey OUTPUT  
       END  
       FETCH NEXT FROM cur_Book INTO @n_PABookingKey
    END
    CLOSE cur_Book  
    DEALLOCATE cur_Book                                  
                 
ENDPROC: 
   IF @n_continue IN(1,2)
   BEGIN
     SELECT RECEIPTDETAIL.ReceiptLineNumber as ReceiptLineNumber, RECEIPTDETAIL.Sku AS Sku, 
	        RECEIPTDETAIL.Putawayloc as Putawayloc,ISNULL(S.Notes1,'') AS SNotes1
     FROM RECEIPTDETAIL WITH (NOLOCK)
	 JOIN SKU S WITH (NOLOCK) ON S.Storerkey = RECEIPTDETAIL.Storerkey AND S.SKU = RECEIPTDETAIL.SKU
     WHERE RECEIPTDETAIL.Receiptkey BETWEEN @c_ReceiptkeyFrom AND @c_ReceiptkeyTo
   END
   ELSE
   BEGIN
     SELECT  RECEIPTDETAIL.ReceiptLineNumber as ReceiptLineNumber, RECEIPTDETAIL.Sku AS Sku, 
	         RECEIPTDETAIL.Putawayloc as Putawayloc,ISNULL(S.Notes1,'') AS SNotes1
     FROM RECEIPTDETAIL (NOLOCK)
	 JOIN SKU S WITH (NOLOCK) ON S.Storerkey = RECEIPTDETAIL.Storerkey AND S.SKU = RECEIPTDETAIL.SKU
     WHERE 1=2
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_ReturnPutawayLabel_03'
	    --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END -- End PROC

GO