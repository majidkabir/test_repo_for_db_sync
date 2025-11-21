SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispORD11                                           */
/* Creation Date: 20-Oct-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15388 - NIKE - PH WMS-OTM OTMLOG ORDERS DELIVERYDATE    */   
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
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

CREATE PROC [dbo].[ispORD11]
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
           @c_Orderkey        NVARCHAR(10)
                                                       
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   

   SELECT @c_Orderkey = I.OrderKey
   FROM #INSERTED I
   WHERE I.Storerkey = @c_Storerkey
   
   BEGIN TRAN
   
   IF @c_Action IN ('UPDATE') 
   BEGIN
      IF EXISTS (SELECT  1
                 FROM #INSERTED I
                 JOIN #DELETED D ON I.Orderkey = D.Orderkey
                 AND I.Storerkey = @c_Storerkey
                 AND I.[Status] = D.[Status]
                 AND I.[Status] >= '5'
                 AND I.DeliveryDate <> D.DeliveryDate)
      BEGIN
      	INSERT INTO OTMLOG
      	(
      		-- OTMLOGKey -- this column value is auto-generated
      		Tablename,
      		Key1,
      		Key2,
      		Key3,
      		TransmitFlag
      	)
      	VALUES
      	(
      		'SOCRDOTM',
      		@c_Orderkey,
      		'0',
      		@c_Storerkey,
      		'0'
      	)
      	
      	SELECT @n_err = @@ERROR
      	
      	IF @n_err <> 0
      	BEGIN
            SET @n_continue = 3    
            SET @n_err = 62900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Failed to insert into OTMLog table. (ispORD11)'   
         END
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD11'		
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