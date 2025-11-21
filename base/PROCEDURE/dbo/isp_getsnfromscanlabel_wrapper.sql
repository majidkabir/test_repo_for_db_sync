SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetSNFromScanLabel_Wrapper                          */
/* Creation Date: 25-JAN-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-7669 - [CN] Doterra - Doterra ECOM Packing_CR           */
/*        :                                                             */
/* Called By: isp_Ecom_GetPackSku                                       */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetSNFromScanLabel_Wrapper]
           @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_ScanLabel       NVARCHAR(60)
         , @c_SerialNo        NVARCHAR(30)   OUTPUT
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

         , @c_SQL             NVARCHAR(MAX)
         , @c_SQLParms        NVARCHAR(MAX)
         , @c_SPCode          NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @c_SPCode = ''
   SELECT @c_SPCode = ISNULL(RTRIM(SValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_StorerKey
   AND   Configkey = 'GetSNFromScanLabel'

   IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_SPCode AND TYPE = 'P')
   BEGIN
      SET @c_SQL = N'EXECUTE ' + @c_SPCode  
                  + '  @c_Storerkey  = @c_Storerkey' 
                  + ', @c_Sku        = @c_Sku'                   
                  + ', @c_ScanLabel  = @c_ScanLabel' 
                  + ', @c_SerialNo   = @c_SerialNo    OUTPUT'                        
                  + ', @b_Success    = @b_Success     OUTPUT' 
                  + ', @n_Err        = @n_Err         OUTPUT'  
                  + ', @c_ErrMsg     = @c_ErrMsg      OUTPUT'  

      SET @c_SQLParms= N' @c_Storerkey NVARCHAR(15)'  
                     +  ',@c_Sku       NVARCHAR(20)'  
                     +  ',@c_ScanLabel NVARCHAR(60)'  
                     +  ',@c_SerialNo  NVARCHAR(30)   OUTPUT' 
                     +  ',@b_Success   INT OUTPUT'
                     +  ',@n_Err       INT OUTPUT'
                     +  ',@c_ErrMsg    NVARCHAR(250)  OUTPUT'
                                 
      EXEC sp_ExecuteSQL @c_SQL
                     ,   @c_SQLParms
                     ,   @c_Storerkey
                     ,   @c_Sku  
                     ,   @c_ScanLabel
                     ,   @c_SerialNo   OUTPUT
                     ,   @b_Success    OUTPUT
                     ,   @n_Err        OUTPUT
                     ,   @c_ErrMsg     OUTPUT 
  
      IF @b_Success <> 1  
      BEGIN  
         SET @n_Continue= 3    
         GOTO QUIT_SP                          
      END 
   END

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetSNFromScanLabel_Wrapper'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO