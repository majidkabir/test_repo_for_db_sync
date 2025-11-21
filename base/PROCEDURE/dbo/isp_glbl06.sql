SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL06                                          */
/* Creation Date: 23-Jan-2014                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#331204 - LULUHK- Carton Label Numbering                 */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
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
/* Date         Author  Ver.  Purposes                                  */
/* 02-JUL-2021  NJOW01  1.0   WMS-17424 get order info thru packheader  */
/*                            pickheader failed                         */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL06] ( 
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
          ,@c_Lottable02  NVARCHAR(18)
          ,@c_PackNo_Long NVARCHAR(250)
          ,@c_Storerkey   NVARCHAR(15)
          ,@c_Prefix      NVARCHAR(10)
          ,@c_Keyname     NVARCHAR(30)

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   SET @c_PackNo_Long      = ''
   SET @c_Prefix           = ''
   
   SELECT TOP 1 @c_Lottable02 = ISNULL(OD.Lottable02,'')
               ,@c_Storerkey = ISNULL(O.Storerkey,'')
   FROM PICKHEADER PH (NOLOCK)                                           
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   WHERE PH.Pickheaderkey = @c_PickslipNo
   ORDER BY OD.OrderLineNumber
   
   --NJOW01
   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Lottable02 = ISNULL(OD.Lottable02,'')
                  ,@c_Storerkey = ISNULL(O.Storerkey,'')
      FROM PACKHEADER PH (NOLOCK)                                           
      JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      WHERE PH.PickSlipNo = @c_PickslipNo
      ORDER BY OD.OrderLineNumber
   END

   SELECT @c_PackNo_Long = Long,
          @c_Prefix = Short
   FROM  CODELKUP (NOLOCK)
   WHERE ListName = 'PACKNO'
   AND Code = RTRIM(@c_Storerkey) + '_' + LTRIM(@c_Lottable02)

   IF @@ROWCOUNT = 0
   BEGIN
      SELECT @c_PackNo_Long = Long,
             @c_Prefix = Short
      FROM  CODELKUP (NOLOCK)
      WHERE ListName = 'PACKNO'
      AND Code = @c_Storerkey
   END
   
   SELECT @c_Keyname = 'PACKNO' + LTRIM(ISNULL(@c_PackNo_Long,''))
                                       
   EXECUTE dbo.nspg_GetKey
    @c_Keyname,
    8,
    @c_Label_SeqNo OUTPUT,
    @b_Success     OUTPUT,
    @n_err         OUTPUT,
    @c_errmsg      OUTPUT
    
   IF @b_Success <> 1
      SELECT @n_Continue = 3
   
   SET @c_LabelNo = LTRIM(RTRIM(ISNULL(@c_Prefix,''))) + LTRIM(ISNULL(@c_Label_SeqNo,''))     
 
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL06"
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