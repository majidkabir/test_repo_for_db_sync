SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispSXL01                                           */
/* Creation Date: 30-Mar-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-16618 - CN Converse auto update Loc.locationRoom for    */   
/*          pickface                                                    */
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
/************************************************************************/
CREATE PROC [dbo].[ispSXL01]   
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
           @c_Active          NVARCHAR(10),
           @c_Loc             NVARCHAR(10),
           @c_Busr8           NVARCHAR(30)
                                                       
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
   
   IF NOT EXISTS(SELECT 1 FROM #INSERTED WHERE LocationType IN ('PICK','CASE') 
                 AND Storerkey = @c_Storerkey)
      GOTO QUIT_SP
   
   IF @c_Action  = 'INSERT'
   BEGIN
   	  DECLARE CUR_LOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	    SELECT I.Loc, SKU.Busr8
   	    FROM #INSERTED I
   	    JOIN SKU (NOLOCK) ON I.Storerkey = SKU.Storerkey AND I.Sku = SKU.Sku  
   	    WHERE I.LocationType IN('PICK','CASE')
   	    AND I.Storerkey = @c_Storerkey
   	    
      OPEN CUR_LOC
      
      FETCH NEXT FROM CUR_LOC INTO @c_Loc, @c_Busr8
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE LOC WITH (ROWLOCK)
         SET LocationRoom = @c_Busr8,
             TrafficCop = NULL
         WHERE Loc = @c_Loc 
               
         FETCH NEXT FROM CUR_LOC INTO @c_Loc, @c_Busr8
   	  END   
   	  CLOSE CUR_LOC
   	  DEALLOCATE CUR_LOC   	            
   END

   IF @c_Action  = 'UPDATE'
   BEGIN
   	  DECLARE CUR_LOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	    SELECT I.Loc, SKU.Busr8
   	    FROM #INSERTED I
   	    JOIN #DELETED D ON I.Storerkey = D.Storerkey AND I.Sku = D.Sku AND I.Loc = D.Loc 
   	    JOIN SKU (NOLOCK) ON I.Storerkey = SKU.Storerkey AND I.Sku = SKU.Sku  
   	    WHERE I.LocationType IN('PICK','CASE')
   	    AND D.LocationType NOT IN('PICK','CASE')
   	    AND I.Storerkey = @c_Storerkey
   	    
      OPEN CUR_LOC
      
      FETCH NEXT FROM CUR_LOC INTO @c_Loc, @c_Busr8
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE LOC WITH (ROWLOCK)
         SET LocationRoom = @c_Busr8,
             TrafficCop = NULL
         WHERE Loc = @c_Loc 
               
         FETCH NEXT FROM CUR_LOC INTO @c_Loc, @c_Busr8
   	  END   
   	  CLOSE CUR_LOC
   	  DEALLOCATE CUR_LOC   	            

   	  /*
   	  DECLARE CUR_LOC_D CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	    SELECT I.Loc
   	    FROM #INSERTED I
   	    JOIN #DELETED D ON I.Storerkey = D.Storerkey AND I.Sku = D.Sku AND I.Loc = D.Loc 
   	    WHERE I.LocationType NOT IN('PICK','CASE')
   	    AND D.LocationType IN('PICK','CASE')
   	    AND I.Storerkey = @c_Storerkey
   	    
      OPEN CUR_LOC_D
      
      FETCH NEXT FROM CUR_LOC_D INTO @c_Loc
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE LOC WITH (ROWLOCK)
         SET LocationRoom = '',
             TrafficCop = NULL
         WHERE Loc = @c_Loc 
               
         FETCH NEXT FROM CUR_LOC_D INTO @c_Loc
   	  END   
   	  CLOSE CUR_LOC_D
   	  DEALLOCATE CUR_LOC_D
   	  */   	            
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispSXL01'		
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