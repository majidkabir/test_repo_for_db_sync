SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispPOTRF03                                                  */
/* Creation Date: 01-Oct-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-6509 PH Alcon tranfer interface                         */
/*          Storerconfig: PostFinalizeTranferSP                         */
/*                                                                      */
/* Called By: ispPostFinalizeTransferWrapper                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPOTRF03]  
(     @c_Transferkey          NVARCHAR(10)   
  ,   @b_Success              INT           OUTPUT
  ,   @n_Err                  INT           OUTPUT
  ,   @c_ErrMsg               NVARCHAR(255) OUTPUT 
  ,   @c_TransferLineNumber   NVARCHAR(5)   = '' 
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_Debug              INT
         , @n_Cnt                INT
         , @n_Continue           INT 
         , @n_StartTCount        INT 
         , @c_UDF01              NVARCHAR(30)
         , @c_UDF02              NVARCHAR(30)
         , @c_Storerkey          NVARCHAR(15)

   SET @b_Success = 1 
   SET @n_Err     = 0  
   SET @c_ErrMsg  = ''
   SET @b_Debug   = '0' 
   SET @n_Continue= 1  
   SET @n_StartTCount = @@TRANCOUNT  

   IF @n_continue IN(1,2)
   BEGIN   	
   	   SELECT TOP 1 @c_UDF01 = C.UDF01, 
   	                @c_UDF02 = C.UDF02,
   	                @c_Storerkey = T.ToStorerkey
   	   FROM TRANSFER T (NOLOCK)
   	   JOIN CODELKUP C (NOLOCK) ON T.Type = C.Code AND T.ToStorerkey = C.Storerkey AND C.Listname = 'TRANTYPE'
   	   AND T.Transferkey = @c_Transferkey

       IF ISNULL(@c_UDF01,'') <> ''
       BEGIN
          EXEC dbo.ispGenTransmitLog3 'TRFLOG2', @c_Transferkey, @c_UDF01, @c_StorerKey, ''  
               , @b_success OUTPUT  
               , @n_err OUTPUT  
               , @c_errmsg OUTPUT  
               
          IF @b_success = 0
              SELECT @n_continue = 3, @n_err = 60100, @c_errmsg = 'ispPOTRF03: ' + rtrim(@c_errmsg)   	   
       END    

       IF ISNULL(@c_UDF02,'') <> '' AND @n_continue IN(1,2)
       BEGIN
          EXEC dbo.ispGenTransmitLog3 'TRFLOG3', @c_Transferkey, @c_UDF02, @c_StorerKey, ''  
               , @b_success OUTPUT  
               , @n_err OUTPUT  
               , @c_errmsg OUTPUT  
               
          IF @b_success = 0
              SELECT @n_continue = 3, @n_err = 60110, @c_errmsg = 'ispPOTRF03: ' + rtrim(@c_errmsg)   	   
       END    
   END

   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCount
         BEGIN
            COMMIT TRAN
         END
      END
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPOTRF03'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCount
      BEGIN
         COMMIT TRAN
      END 

      RETURN
   END 
END

GO