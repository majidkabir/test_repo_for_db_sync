SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispLPFZ01                                             */
/* Creation Date: 08-JUN-2018                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-5318 - HK UA Finalize load plan trigger interface          */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispLPFZ01]  
(     @c_Loadkey     NVARCHAR(10)   
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue       INT,
           @n_StartTranCount INT,
           @c_Storerkey      NVARCHAR(15),
           @c_Facility       NVARCHAR(5),
           @c_Orderkey       NVARCHAR(10)
                                     
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT              

   IF @@TRANCOUNT = 0
      BEGIN TRAN
   
   IF @n_continue IN (1,2)
   BEGIN   	   	  
      DECLARE cur_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Storerkey, Facility, Orderkey
         FROM ORDERS (NOLOCK)
         WHERE Loadkey = @c_Loadkey
         ORDER BY Orderkey
      
      OPEN cur_ORDERS  
             
      FETCH NEXT FROM cur_ORDERS INTO @c_Storerkey, @c_Facility, @c_Orderkey
             
      WHILE @@FETCH_STATUS = 0 
      BEGIN   
         EXEC dbo.ispGenTransmitLog3 'LOADORDLOG', @c_Orderkey, @c_Facility, @c_StorerKey, ''  
              , @b_success OUTPUT  
              , @n_err OUTPUT  
              , @c_errmsg OUTPUT  
              
         IF @b_success = 0
             SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'ispLPFZ01: ' + rtrim(@c_errmsg)
      	  
         FETCH NEXT FROM cur_ORDERS INTO @c_Storerkey, @c_Facility, @c_Orderkey
      END         
      CLOSE cur_ORDERS
      DEALLOCATE cur_ORDERS
   END   	     	  
   	   	   	   	   
   QUIT_SP:
   
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispLPFZ01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO