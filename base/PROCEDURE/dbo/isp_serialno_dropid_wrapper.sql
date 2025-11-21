SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_SerialNo_dropid_Wrapper                             */
/* Creation Date: 22-MAY-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
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
CREATE PROC [dbo].[isp_SerialNo_dropid_Wrapper]
           @c_PickSlipNo      NVARCHAR(10) 
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_DropId          NVARCHAR(30)
         , @c_SerialNo        NVARCHAR(30)
         , @n_Qty             INT            OUTPUT
         , @b_DisableQty      INT            OUTPUT
         , @c_PackMode        NVARCHAR(50)
         , @c_Source          NVARCHAR(50)
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

         , @c_SQL                      NVARCHAR(MAX)
         , @c_SQLParms                 NVARCHAR(MAX)
         , @c_SerialNo_DropID_SP NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @c_SerialNo_DropID_SP = ''
   SELECT @c_SerialNo_DropID_SP = ISNULL(RTRIM(SValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_StorerKey
   AND   Configkey = 'SerialNo_dropid_Wrapper'

   IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_SerialNo_DropID_SP AND TYPE = 'P')
   BEGIN
      SET @c_SQL = N'EXECUTE ' + @c_SerialNo_DropID_SP  
                  + '  @c_PickSlipNo = @c_PickSlipNo' 
                  + ', @c_DropId     = @c_DropId'
                  + ', @c_Storerkey  = @c_Storerkey'  
                  + ', @c_Sku        = @c_Sku' 
                  + ', @c_SerialNo   = @c_SerialNo'                        
                  + ', @n_Qty        = @n_Qty           OUTPUT' 
                  + ', @b_DisableQty  = @b_DisableQty   OUTPUT' 
                  + ', @c_PackMode   = @c_PackMode' 
                  + ', @c_Source     = @c_Source' 
                  + ', @b_Success    = @b_Success     OUTPUT' 
                  + ', @n_Err        = @n_Err         OUTPUT'  
                  + ', @c_ErrMsg     = @c_ErrMsg      OUTPUT'  

      SET @c_SQLParms= N' @c_PickSlipNo         NVARCHAR(10)'  
                     +  ',@c_DropId             NVARCHAR(20)'
                     +  ',@c_Storerkey          NVARCHAR(15)'  
                     +  ',@c_Sku                NVARCHAR(20)'  
                     +  ',@c_SerialNo           NVARCHAR(30)' 
                     +  ',@n_Qty                INT OUTPUT'
                     +  ',@b_DisableQty         INT OUTPUT'
                     +  ',@c_PackMode           NVARCHAR(50)'                                                                         
                     +  ',@c_Source             NVARCHAR(50)'
                     +  ',@b_Success            INT OUTPUT'
                     +  ',@n_Err                INT OUTPUT'
                     +  ',@c_ErrMsg             NVARCHAR(250) OUTPUT'
                                 
      EXEC sp_ExecuteSQL @c_SQL
                     ,   @c_SQLParms
                     ,   @c_PickSlipNo
                     ,   @c_DropID
                     ,   @c_Storerkey
                     ,   @c_Sku
                     ,   @c_SerialNo
                     ,   @n_Qty        OUTPUT
                     ,   @b_DisableQty OUTPUT
                     ,   @c_PackMode
                     ,   @c_Source
                     ,   @b_Success    OUTPUT
                     ,   @n_Err        OUTPUT
                     ,   @c_ErrMsg     OUTPUT 
  
      IF @@ERROR <> 0 OR @b_Success <> 1  
      BEGIN  
         SET @n_Continue= 3    
         SET @n_Err     = 60010    
         SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_SerialNo_DropID_SP 
                        + '.(isp_SerialNo_dropid_Wrapper)'
                        + CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END 
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_SerialNo_dropid_Wrapper'
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