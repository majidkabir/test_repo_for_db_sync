SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: isp_XDockFinalizeAutoAllocate                  	            */
/* Creation Date: 15-Oct-2012                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#258653-TBL-SG-Auto Allocate Xdock & Picked              */
/*                                                                      */
/* Called By: isp_XDockFinalizeAutoAllocate                             */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2019-04-11   TLTING01  1.1 missing nolock                            */
/************************************************************************/

CREATE PROC    [dbo].[isp_XDockFinalizeAutoAllocate]
               @c_ReceiptKey   NVARCHAR(10)
,              @b_Success      int       = 1  OUTPUT
,              @n_err          int       = 0  OUTPUT
,              @c_ErrMsg       NVARCHAR(250) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue      int,  
           @n_StartTCnt     int        -- Holds the current transaction count

   DECLARE @c_Orderkey NVARCHAR(10)

   SELECT @n_StartTCnt=@@TRANCOUNT, @n_continue=1, @b_Success=0,@n_err=0,@c_ErrMsg=''
  
   SELECT  RD.ExternPOkey, 
           RD.Userdefine01, 
           O.Orderkey,
           SUM(RD.BeforeReceivedQty) AS ReceivedQty,
           SUM(OD.OriginalQty) AS OrderQty 
          /*(SELECT SUM(BeforeReceivedQty) 
           FROM RECEIPTDETAIL (NOLOCK)
           WHERE Receiptkey = R.Receiptkey
           AND Userdefine01 = RD.Userdefine01) AS ReceivedQty,
          (SELECT SUM(OriginalQty) 
           FROM ORDERDETAIL (NOLOCK)
           WHERE Orderkey = O.Orderkey
           AND RTRIM(Userdefine01) + LTRIM(Userdefine02) = RD.Userdefine01) AS OrderQty*/           
   INTO #TMP_XDOCK
   FROM RECEIPT R (NOLOCK)
   JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
   JOIN ORDERDETAIL OD (NOLOCK) ON RD.ExternPokey = OD.ExternPokey 
                                AND RD.Userdefine01 = RTRIM(ISNULL(OD.Userdefine01,'')) + LTRIM(ISNULL(OD.Userdefine02,''))
                                AND OD.Sku = RD.Sku
   JOIN ORDERS O (NOLOCK) ON OD.Orderkey = O.Orderkey
   WHERE R.Receiptkey = @c_Receiptkey 
   AND O.Status <> '9'
   AND ISNULL(RD.Userdefine01,'') <> ''
   GROUP BY R.Receiptkey, 
            RD.ExternPOkey, 
            RD.Userdefine01, 
            O.Orderkey
            
   IF NOT EXISTS (SELECT 1 FROM #TMP_XDOCK WHERE ReceivedQty > 0)
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62101   
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': CrossDock Allocation Orders Not Found. (isp_XDockFinalizeAutoAllocate)' 
   END            

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN               
      /*UPDATE ORDERDETAIL WITH (ROWLOCK)
      SET OpenQty = 0,
          Trafficcop = NULL
      FROM ORDERDETAIL OD 
      JOIN #TMP_XDOCK T ON (OD.Orderkey = T.Orderkey AND RTRIM(ISNULL(OD.Userdefine01,'')) + LTRIM(ISNULL(OD.Userdefine02,'')) = T.Userdefine01)
      WHERE T.ReceivedQty = 0*/
      
      UPDATE ORDERDETAIL WITH (ROWLOCK)
      SET ORDERDETAIL.Openqty = RD.BeforeReceivedQty,
          ORDERDETAIL.TrafficCop = NULL
      FROM ORDERDETAIL  
      -- tlting01
      JOIN RECEIPTDETAIL RD (NOLOCK) ON (ORDERDETAIL.ExternPOkey = RD.ExternPokey AND ORDERDETAIL.Sku = RD.Sku 
                                AND RTRIM(ISNULL(ORDERDETAIL.Userdefine01,'')) + LTRIM(ISNULL(ORDERDETAIL.Userdefine02,'')) = RD.Userdefine01)
      WHERE RD.Receiptkey = @c_Receiptkey
      AND RD.BeforeReceivedQty < ORDERDETAIL.Openqty
      AND ISNULL(RD.Userdefine01,'') <> ''     
            
      DECLARE Cur_XDOCK CURSOR FAST_FORWARD READ_ONLY FOR
        SELECT Orderkey
        FROM #TMP_XDOCK T
        WHERE ReceivedQty > 0
        GROUP BY Orderkey
        ORDER BY Orderkey
      
	    OPEN Cur_XDOCK
	    
	    FETCH NEXT FROM Cur_XDOCK INTO @c_Orderkey
	    
	    WHILE @@FETCH_STATUS <> -1
	    BEGIN
	    	 
         EXEC nsporderprocessing 
            @c_Orderkey,  
            '', --@c_oskey
            'N', -- @c_docarton,  
            'N', -- @c_doroute,  
            '', --@c_tblprefix  
            @b_success OUTPUT,  
            @n_err OUTPUT,  
            @c_errmsg OUTPUT  
            
            IF @b_success <> 1 AND @n_err <> 0
						BEGIN
               SELECT @n_continue = 3
			   			 GOTO EXIT_SP
						END
						ELSE 
	             EXEC isp_InsertAllocShortageLog @cOrderKey = @c_orderkey
           
		    	 /*EXEC nsp_orderprocessing_wrapper
			     	@c_orderkey = @c_Orderkey,
			   	  @c_oskey    = '' ,	
			   	  @c_docarton = 'Y',
			   	  @c_doroute  = 'N',
			   	  @c_tblprefix = ''*/
		   	 
		   	 BEGIN TRY   		   	 
		   	   UPDATE PICKDETAIL WITH (ROWLOCK)
		   	   SET Status = '5'
		   	   WHERE Orderkey = @c_Orderkey		
		   	   AND Status < '4'   
		   	 END TRY	
		   	 BEGIN CATCH
		   	    SELECT @n_continue = 3
		   	    SELECT @n_err = ERROR_NUMBER()
		   	    SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+':' + RTRIM(ERROR_MESSAGE()) + ' (isp_XDockFinalizeAutoAllocate)' 
		   	    GOTO EXIT_SP
		   	 END CATCH
		   	   
		     FETCH NEXT FROM Cur_XDOCK INTO @c_Orderkey
      END
      CLOSE Cur_XDOCK
	    DEALLOCATE Cur_XDOCK
	 END

EXIT_SP:

   /* #INCLUDE <SPIAM2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_XDockFinalizeAutoAllocate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END


GO