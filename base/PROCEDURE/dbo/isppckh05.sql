SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPCKH05                                          */
/* Creation Date: 08-Aug-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SG Pack confirm validation Qty Tally for THGSG              */   
/*                                                                      */
/* Called By: isp_PackHeaderTrigger_Wrapper from PackHeader Trigger     */
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

CREATE PROC [dbo].[ispPCKH05]   
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_Pickslipno      NVARCHAR(10),
           @c_Orderkey        NVARCHAR(10),
           @c_Sku             NVARCHAR(20)
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
               
	 IF @c_Action IN('UPDATE') 
	 BEGIN	 		 	
	    SELECT TOP 1 @c_Pickslipno = I.Pickslipno
	    FROM #INSERTED I
	    JOIN #DELETED D ON I.Pickslipno = D.Pickslipno
	    WHERE I.Status <> D.Status 
	    AND I.Status ='9'
	    AND I.Storerkey = @c_Storerkey
	    ORDER BY I.Pickslipno

      SELECT @c_Orderkey = O.Orderkey 
      FROM PICKHEADER PH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      WHERE PH.Pickheaderkey = @c_Pickslipno
      
      IF ISNULL(@c_Orderkey,'') <> ''
      BEGIN            	
      	 SELECT TOP 1 @c_Sku = PD.Sku
      	 FROM ORDERS O(NOLOCK)
      	 JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
      	 CROSS APPLY (SELECT SUM(PKD.Qty) AS Qty 
      	              FROM PACKHEADER PKH
      	              JOIN PACKDETAIL PKD (NOLOCK) ON PKH.Pickslipno = PKD.Pickslipno     
      	              WHERE PKH.Pickslipno = @c_Pickslipno AND PKH.Orderkey = O.Orderkey AND PKD.Storerkey = PD.Storerkey AND PKD.Sku = PD.Sku) AS PACK 	 
      	 WHERE O.Orderkey = @c_Orderkey
      	 GROUP BY PD.Storerkey, PD.Sku, ISNULL(PACK.Qty,0)
      	 HAVING SUM(PD.Qty) <> ISNULL(PACK.Qty,0)      	      	
   
         IF ISNULL(@c_Sku,'') <> ''
         BEGIN
            SELECT @n_continue = 3                                                                                       
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83000   -- Should Be Set To The SQL Errmessage but
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pack Confirm Failed: Sku ''' + RTRIM(@c_Sku)  +  ''' Not Fully Packed Yet. (ispPCKH05)' 
            GOTO QUIT_SP      	
         END      	
      END                
	 END	 
   
   --OMT packing status
   EXEC ispPCKH01   
        @c_Action    = @c_Action,
        @c_Storerkey = @c_Storerkey,  
        @b_Success   = @b_Success OUTPUT,
        @n_Err       = @n_Err OUTPUT, 
        @c_ErrMsg    = @c_ErrMsg OUTPUT
   
   IF @b_Success <> 1
   BEGIN
   	  SET @n_continue = 3
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPCKH05'		
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