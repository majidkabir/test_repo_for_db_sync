SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL26                                          */
/* Creation Date: 30-SEP-2020                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-14747 - KR LEVIS generate label no                      */  
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
/* Date        Author   Ver.  Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GLBL26] ( 
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
         
   DECLARE @c_Orderkey           NVARCHAR(10)   = ''
         , @c_Consigneekey       NVARCHAR(15)   = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_Loadkey            NVARCHAR(10)   = ''     
         , @c_OrderType          NVARCHAR(10)   = ''
            
   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
      
   SELECT @c_Orderkey = P.Orderkey  
         ,@c_Loadkey  = P.ExternOrderkey  
   FROM PICKHEADER P WITH (NOLOCK)
   WHERE P.Pickheaderkey = @c_PickSlipNo
   
   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Orderkey = Orderkey
      FROM LOADPLANDETAIL (NOLOCK)
      WHERE Loadkey = @c_Loadkey
   END

   SELECT @c_OrderType = Type,
          @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_Orderkey
      
   IF @c_OrderType = 'IC'
   BEGIN
      EXEC isp_GetUCCKey
         @c_storerkey = @c_Storerkey                       
        ,@c_fieldlength = 8
        ,@c_keystring = @c_LabelNo OUTPUT
        ,@b_Success = @b_Success OUTPUT
        ,@n_err = @n_err OUTPUT
        ,@c_errmsg =  @c_errmsg OUTPUT
        ,@b_resultset  = 0
        ,@n_batch = 1
        ,@n_joinstorer = 1        	  	
   END
   ELSE
   BEGIN
      EXEC isp_GetUCCKey
         @c_storerkey = @c_Storerkey                       
        ,@c_fieldlength = 10
        ,@c_keystring = @c_LabelNo OUTPUT
        ,@b_Success = @b_Success OUTPUT
        ,@n_err = @n_err OUTPUT
        ,@c_errmsg =  @c_errmsg OUTPUT
        ,@b_resultset  = 0
        ,@n_batch = 1
        ,@n_joinstorer = 0         	  	
   END   
  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL26"
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