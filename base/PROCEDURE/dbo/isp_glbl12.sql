SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL12                                          */
/* Creation Date: 25-SEP-2017                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-3009 - [TW] Customization û PackDetail.LabelNo          */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    storerconfig: GenLabelNo_SP                       */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL12] ( 
         @c_PickSlipNo   NVARCHAR(10) 
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20)   OUTPUT )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_StartTCnt          INT
         , @n_Continue           INT
         , @b_Success            INT 
         , @n_Err                INT  
         , @c_ErrMsg             NVARCHAR(255)
         
   DECLARE @c_Label_SeqNo        NVARCHAR(10)
          ,@c_Consigneekey       NVARCHAR(15)
          ,@c_Storerkey          NVARCHAR(15)
          ,@c_Keyname            NVARCHAR(18)
          ,@n_Cntno              INT
          ,@n_GetCntNo           INT

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   
   SET @c_LabelNo = ''
   SET @n_Cntno = 0
   SET @n_GetCntNo = 1
   
   SELECT @n_Cntno = ISNULL(MAX(cartonno),0)
   FROM PACKDETAIL (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   
   IF ISNULL(@n_Cntno,0) = 0
   BEGIN
   	 SET @n_GetCntNo = 1
   END
   ELSE
   BEGIN	
    SET @n_GetCntNo = @n_Cntno + 1
   END 
   
   
   SELECT @c_LabelNo = @c_PickSlipNo + CONVERT(NVARCHAR(10),@n_GetCntNo)
   --FROM PACKHEADER WITH (NOLOCK)
   --WHERE PickSlipNo = @c_PickSlipNo
   --AND   CartonNo = @n_CartonNo

   QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL11"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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