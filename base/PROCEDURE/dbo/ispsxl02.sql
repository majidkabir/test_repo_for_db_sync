SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispSXL02                                           */
/* Creation Date: 23-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20598 - ID-PUMA-Auto Un Assign Pickface                 */   
/*                                                                      */
/* Called By: isp_SkuXLocTrigger_Wrapper from SKUXLOC Trigger           */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */ 
/* 23-Aug-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[ispSXL02]   
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
           @c_Loc             NVARCHAR(10),
           @c_SKU             NVARCHAR(20)

   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
   
   IF NOT EXISTS(SELECT 1 FROM #INSERTED WHERE LocationType IN ('PICK') 
                 AND Storerkey = @c_Storerkey)
      GOTO QUIT_SP

   IF @c_Action  = 'UPDATE'
   BEGIN
      DECLARE CUR_LOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT I.Loc, I.SKU
         FROM #INSERTED I
         JOIN #DELETED D ON I.Storerkey = D.Storerkey AND I.Sku = D.Sku AND I.Loc = D.Loc 
         WHERE I.LocationType IN ('PICK')
         AND I.Storerkey = @c_Storerkey
         AND I.Qty = 0
         AND D.Qty > 0
   
      OPEN CUR_LOC
      
      FETCH NEXT FROM CUR_LOC INTO @c_Loc, @c_SKU
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE SKUxLOC WITH (ROWLOCK)
         SET LocationType  = ''
           , TrafficCop    = NULL
           , EditWho       = SUSER_SNAME()
           , EditDate      = GETDATE()
         WHERE Loc = @c_Loc 
         AND StorerKey = @c_Storerkey
         AND SKU = @c_SKU
               
         FETCH NEXT FROM CUR_LOC INTO @c_Loc, @c_SKU
      END   
      CLOSE CUR_LOC
      DEALLOCATE CUR_LOC   	               	            
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispSXL02'		
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