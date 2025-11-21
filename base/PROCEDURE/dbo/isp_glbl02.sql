SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL02                                          */
/* Creation Date: 23-Sep-2013                                           */
/* Copyright: LF                                                        */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#290117 - AEO - Packing label no                         */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 24-JUL-2017  Wan01    1.1  WMS-2306 - CN-Nike SDC WMS ECOM Packing CR*/  
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL02] ( 
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
         
   DECLARE @c_Label_SeqNo NVARCHAR(10)
          ,@c_vat         NVARCHAR(18)
         
         , @n_RecCnt       INT         --(Wan01)

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''

   SET @n_RecCnt  = 0
   
   SELECT @c_vat = S.Vat    
         ,@n_RecCnt = 1                 --(Wan01)                      
   FROM PICKHEADER PH (NOLOCK)                                           
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   JOIN STORER S (NOLOCK) ON O.Storerkey = S.Storerkey                    
   WHERE PH.Pickheaderkey = @c_PickslipNo
   
   --(Wan01) - START
   IF @n_RecCnt =  0
   BEGIN
      SELECT @c_vat = S.Vat 
      FROM PACKHEADER PH (NOLOCK)
      JOIN STORER S (NOLOCK) ON PH.Storerkey = S.Storerkey  
      WHERE PH.PickSlipNo = @c_PickSlipNo
   END
   --(Wan01) - END

   /*IF ISNULL(@c_vat,'') = ''
   BEGIN
   	  SELECT @n_Continue = 3
   	  SELECT @n_err = 200010
   	  SELECT @c_errmsg = 'Error: Empty Storer VAT for Generating Label#'
   END*/
                                     
   EXECUTE dbo.nspg_GetKey
    'AEOLabelNo',
    10,
    @c_Label_SeqNo OUTPUT,
    @b_Success     OUTPUT,
    @n_err         OUTPUT,
    @c_errmsg      OUTPUT
    
   IF @b_Success <> 1
      SELECT @n_Continue = 3
   
   SET @c_LabelNo = RTRIM(ISNULL(@c_vat,'')) + LTRIM(ISNULL(@c_Label_SeqNo,''))     
 
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL02"
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