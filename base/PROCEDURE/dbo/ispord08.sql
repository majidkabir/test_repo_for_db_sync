SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispORD08                                           */
/* Creation Date: 28-May-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-9131 - [TW] StorerConfig for Order Add                  */   
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
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

CREATE PROC [dbo].[ispORD08]   
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
           @c_Option1         NVARCHAR(50) = '',
           @c_Option2         NVARCHAR(50) = '',
           @c_Option3         NVARCHAR(50) = '',
           @c_Option4         NVARCHAR(50) = '',
           @c_Option5         NVARCHAR(4000) = '',
           @c_Options         NVARCHAR(4000) = ''
           
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   IF(@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT  @c_Option1 = ISNULL(Option1,'')
             ,@c_Option2 = ISNULL(Option2,'')
             ,@c_Option3 = ISNULL(Option3,'')
             ,@c_Option4 = ISNULL(Option4,'')
             ,@c_Option5 = ISNULL(Option5,'')
      FROM STORERCONFIG (NOLOCK)
      WHERE STORERKEY = @c_Storerkey AND CONFIGKEY = 'OrdersTrigger_SP'
      AND SValue = 'ispORD08' 

      SELECT @c_Options = LTRIM(RTRIM(@c_Option1)) + ',' + LTRIM(RTRIM(@c_Option2)) + ',' + LTRIM(RTRIM(@c_Option3)) + ',' + 
                          LTRIM(RTRIM(@c_Option4)) + ',' + LTRIM(RTRIM(@c_Option5))  
   END   

   IF @c_Action IN('INSERT')
   BEGIN
      IF NOT EXISTS(SELECT 1 
   	              FROM #INSERTED I
   	              JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey
   	              WHERE O.[Type] IN (SELECT ColValue from dbo.fnc_delimsplit (',',@c_Options) WHERE ColValue <> '' ) )
      BEGIN
         GOTO QUIT_SP
      END

      UPDATE ORDERS
      SET Shipperkey = SSD.Door
         ,TrafficCop = NULL
         ,ArchiveCop = NULL
      FROM #INSERTED I 
      JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = I.ORDERKEY
      JOIN StorerSODefault SSD (NOLOCK) ON SSD.STORERKEY = ORD.Consigneekey
      
      IF @@ERROR <> 0 
      BEGIN 
         SELECT @n_Continue = 3
         SELECT @n_Err = 38000
         SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Error Update ORDERS Fail. (ispORD08)' 
         GOTO QUIT_SP 
      END 

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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD08'		
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