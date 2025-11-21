SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPRCBO01                                         */
/* Creation Date: 26-Feb-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 333313 - Pre combine order checking                         */   
/*                                                                      */
/* Called By: isp_PreCombineOrder_Wrapper from Order RCM                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispPRCBO01]   
   @c_ToOrderKey NVARCHAR(10),  
   @c_OrderList  NVARCHAR(MAX),
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @c_TxtResult     NVARCHAR(MAX),
           @n_Continue     INT,
           @n_StartTCnt    INT
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 	 
   SELECT DISTINCT ColValue AS OrderKey
   INTO #TMP_ORDERLIST
   FROM dbo.fnc_DelimSplit('|',@c_OrderList) 
   WHERE ISNULL(ColValue,'') <> ''

   SET @c_TxtResult = '' 
   SELECT @c_TxtResult = @c_TxtResult + OD.Lottable02 +', '
   FROM #TMP_ORDERLIST T
   JOIN ORDERS O (NOLOCK) ON T.Orderkey = O.Orderkey
   JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   GROUP BY OD.Lottable02   
   ORDER BY OD.Lottable02
   
   IF @@ROWCOUNT > 1
   BEGIN
      SELECT @c_TxtResult =  LEFT(@c_TxtResult,LEN(@c_TxtResult)-1)               
      SELECT @n_continue = 3  
      SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err), @n_Err = 81001 
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
             ': The selected Orders are Having Multiple Lottable02 Value. ' + @c_TxtResult +
             ' (isp_PreCombineOrder_Wrapper) ( SQLSvr MESSAGE=' + @c_ErrMsg +  ' ) '      
      GOTO QUIT_SP
   END
   
   QUIT_SP:
   
	 IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @b_Success = 0
	    IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPRCBO01'		
	    --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
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