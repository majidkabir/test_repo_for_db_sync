SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispORD13                                           */
/* Creation Date: 15-FEB-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-16331 - TW StorerConfig for Order Delete to update      */   
/*          carton track                                                */
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispORD13]   
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
           @c_CtnTrkOrdField  NVARCHAR(30),
           @c_SQL             NVARCHAR(2000),
           @c_Orderkey        NVARCHAR(10)
           
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_Action IN('DELETE')
   BEGIN
   	  SELECT TOP 1 @c_CtnTrkOrdField = Code
   	  FROM CODELKUP (NOLOCK)
   	  WHERE Listname = 'DELCTNTRK'
   	  AND Storerkey = @c_Storerkey
   	  
   	  IF ISNULL(@c_CtnTrkOrdField,'') = ''
   	     GOTO QUIT_SP

      IF CHARINDEX('.', @c_CtnTrkOrdField) > 0 
      BEGIN
         SET @c_CtnTrkOrdField   = SUBSTRING(@c_CtnTrkOrdField, CHARINDEX('.', @c_CtnTrkOrdField) + 1, LEN(@c_CtnTrkOrdField) - CHARINDEX('.', @c_CtnTrkOrdField))        	
      END

      IF NOT EXISTS(SELECT 1
                    FROM INFORMATION_SCHEMA.COLUMNS    
                    WHERE TABLE_NAME = 'CARTONTRACK'
                    AND COLUMN_NAME = @c_CtnTrkOrdField)
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 38000
         SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Invalid CartonTrack Field setup at ListName: DELCTNTRK . (ispORD13)'       	
  	     GOTO QUIT_SP
      END              
   	     	  
  	  DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  	     SELECT Orderkey
  	     FROM #DELETED
  	     WHERE Storerkey =@c_Storerkey
  	     
      OPEN CUR_ORD
      
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey      
      
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2) 
      BEGIN      	       	       	      	 
      	 SET @c_SQL = N'DELETE FROM CARTONTRACK WHERE ' + RTRIM(@c_CtnTrkOrdField) + ' = @c_Orderkey ' 
      	 
         EXEC sp_executesql @c_SQL,
         N'@c_Orderkey NVARCHAR(10)', 
         @c_Orderkey
         
         IF @@ERROR <> 0 
         BEGIN 
            SELECT @n_Continue = 3
            SELECT @n_Err = 38010
            SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Delete CartonTrack Failed. (ispORD13)' 
         END 
      	       	
         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
     END
     CLOSE CUR_ORD
     DEALLOCATE CUR_ORD  	     
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD13'		
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