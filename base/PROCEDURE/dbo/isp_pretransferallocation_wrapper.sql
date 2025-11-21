SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PreTransferAllocation_Wrapper                       */
/* Creation Date: 21-AUG-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-HK CPI - Lululemon - Transfer Allocation                */
/*                                                                      */
/* Called By:  isp_TransferProcessing                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_PreTransferAllocation_Wrapper]
           @c_TransferKey     NVARCHAR(10)
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_SQL             NVARCHAR(4000) 
         , @c_SQLArgument     NVARCHAR(4000) 

         , @c_Facility        NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)

         , @c_SPCode          NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SET @c_Storerkey= ''
   SELECT @c_Facility = TF.Facility
         ,@c_Storerkey= TF.FromStorerkey
   FROM TRANSFER TF WITH (NOLOCK)
   WHERE TF.TransferKey = @c_TransferKey

   SET @b_Success = 1
   SET @c_SPCode = ''
   EXEC nspGetRight      
         @c_Facility  = @c_Facility     
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = 'PreTransferAllocation_SP'      
      ,  @b_Success   = @b_Success  OUTPUT      
      ,  @c_authority = @c_SPCode   OUTPUT      
      ,  @n_err       = @n_err      OUTPUT      
      ,  @c_errmsg    = @c_errmsg   OUTPUT
 
   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61000
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Error Executing nspGetRight. (isp_PreTransferAllocation_Wrapper)'  
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN 
      GOTO QUIT_SP
   END    

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
      GOTO QUIT_SP
   END

   BEGIN TRAN
   SET @c_SQL = N'EXEC ' + @c_SPCode 
              + ' @c_TransferKey   = @c_TransferKey'
              + ',@b_Success       = @b_Success OUTPUT'
              + ',@n_Err           = @n_Err     OUTPUT'
              + ',@c_ErrMsg        = @c_ErrMsg  OUTPUT'

   SET @c_SQLArgument= N'@c_TransferKey   NVARCHAR(10)'
                     + ',@b_Success       INT            OUTPUT'
                     + ',@n_Err           INT            OUTPUT'
                     + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT'

   EXEC sp_ExecuteSql @c_SQL 
         , @c_SQLArgument
         , @c_TransferKey      
         , @b_Success   OUTPUT
         , @n_Err       OUTPUT
         , @c_ErrMsg    OUTPUT      
        
   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Error Executing ' + RTRIM(@c_SPCode)+ '. (isp_PreTransferAllocation_Wrapper)'  
      GOTO QUIT_SP
   END

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT > 0 
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PreTransferAllocation_Wrapper'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = @n_Continue
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO