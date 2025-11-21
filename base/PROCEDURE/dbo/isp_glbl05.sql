SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL05                                          */
/* Creation Date: 06-Aug-2014                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#316384 - CN-LBI MAST VSBA                               */ 
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
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL05] ( 
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
         
   DECLARE @c_Label_SeqNo  NVARCHAR(10)
          ,@c_Consigneekey NVARCHAR(15)
          ,@c_Storerkey    NVARCHAR(15)
          ,@c_Keyname      NVARCHAR(18)

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   
   SELECT @c_Consigneekey = O.Consigneekey
         ,@c_Storerkey = O.Storerkey                               
   FROM PICKHEADER PH (NOLOCK)                                           
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   WHERE PH.Pickheaderkey = @c_PickslipNo
   
   SELECT @c_Consigneekey = RIGHT('00000000' + LTRIM(RTRIM(ISNULL(@c_consigneekey,''))), 8)
   SELECT @c_Keyname = 'LBI-' + RTRIM(@c_Storerkey)
                                     
   EXECUTE dbo.nspg_GetKeyMinMax
    @c_keyname,
    6,  --field length
    1,  -- min
    999999, --max   
    @c_Label_SeqNo OUTPUT,
    @b_Success     OUTPUT,
    @n_err         OUTPUT,
    @c_errmsg      OUTPUT
    
   IF @b_Success <> 1
      SELECT @n_Continue = 3
   
   SELECT @c_LabelNo = RTRIM(@c_Consigneekey) + CONVERT(NVARCHAR(6),GETDATE(),12) + RTRIM(LTRIM(ISNULL(@c_Label_SeqNo,'')))     
 
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL05"
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