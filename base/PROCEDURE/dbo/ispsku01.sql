SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispSKU01                                           */
/* Creation Date: 11-Nov-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15671 - auto update Sku Active based on SKUStatus       */   
/*                                                                      */
/* Called By: isp_SKUTrigger_Wrapper from SKU Trigger                   */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */ 
/************************************************************************/
CREATE PROC [dbo].[ispSKU01]   
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
           @c_SKU             NVARCHAR(20),
           @c_SKUStatus       NVARCHAR(10),
           @c_Active          NVARCHAR(10)
                                                       
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
    
   IF @c_Action IN ('INSERT','UPDATE')
   BEGIN
      DECLARE CUR_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  --WL02
         SELECT DISTINCT I.SKU, I.SKUStatus, I.Active
         FROM #INSERTED I
         WHERE I.Storerkey = @c_Storerkey         
       
      OPEN CUR_SKU
      
      FETCH NEXT FROM CUR_SKU INTO @c_SKU, @c_SKUStatus, @c_Active
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	IF @c_SKUStatus NOT IN ('ACTIVE','1')-- AND @c_Active NOT IN ('0')
      	BEGIN
      		UPDATE SKU WITH (ROWLOCK)
      		SET [ACTIVE] = '0', TrafficCop = NULL
      		WHERE SKU.StorerKey = @c_Storerkey AND SKU.SKU = @c_SKU
      		
      		IF @@ERROR <> 0
      		BEGIN
      		   SELECT @n_continue = 3
      		   SELECT @n_err = 60090
      		   SELECT @c_errmsg = 'Update Failed on SKU Table. (ispSKU01)' 
      		   GOTO QUIT_SP
      		END
      	END
      	
      	IF @c_SKUStatus IN ('ACTIVE','1')-- AND @c_Active IN ('0')
      	BEGIN
      		UPDATE SKU WITH (ROWLOCK)
      		SET [ACTIVE] = '1', TrafficCop = NULL
      		WHERE SKU.StorerKey = @c_Storerkey AND SKU.SKU = @c_SKU
      		
      		IF @@ERROR <> 0
      		BEGIN
      		   SELECT @n_continue = 3
      		   SELECT @n_err = 60095
      		   SELECT @c_errmsg = 'Update Failed on SKU Table. (ispSKU01)' 
      		   GOTO QUIT_SP
      		END
      	END

         FETCH NEXT FROM CUR_SKU INTO @c_SKU, @c_SKUStatus, @c_Active
      END
   END
      
   QUIT_SP:
   IF CURSOR_STATUS('LOCAL' , 'CUR_SKU') in (0 , 1)
   BEGIN
      CLOSE CUR_SKU
      DEALLOCATE CUR_SKU
   END    
   
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispSKU01'		
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