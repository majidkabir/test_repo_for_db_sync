SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GLBL29                                          */
/* Creation Date: 14-Jan-2021                                           */
/* Copyright: LF                                                        */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16033 - [TW] Levis Exceed Retrieve CartonID (CR)        */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    storerconfig: GenLabelNo_SP                       */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GLBL29] ( 
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
          ,@c_OrderType          NVARCHAR(50)
          ,@c_Storerkey          NVARCHAR(15)
          ,@c_Keyname            NVARCHAR(18)
          ,@n_Cntno              INT
          ,@n_GetCntNo           INT
          
          ,@c_UDF01              NVARCHAR(50)
          ,@c_UDF02              NVARCHAR(50)
          ,@c_UDF03              NVARCHAR(50)
          ,@n_Len                INT

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   
   SET @c_LabelNo = ''
   SET @n_Cntno = 0
   SET @n_GetCntNo = 1
  
   SELECT @c_OrderType = OH.[Type]
        , @c_Storerkey = OH.StorerKey
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = PH.OrderKey
   WHERE PH.Pickslipno = @c_PickSlipNo
   
   IF @c_OrderType = 'IC'
   BEGIN
      SELECT @c_UDF01 = UDF01, --Min number
             @c_UDF02 = UDF02, --Max number
             @c_UDF03 = UDF03, --Current number
             @n_Len = LEN(RTRIM(@c_UDF01))
      FROM CODELKUP (NOLOCK) 
      WHERE Listname ='ORDERTYPE'
      AND Code = @c_OrderType
      AND Storerkey = @c_Storerkey 

      IF ISNUMERIC(@c_UDF01) <>  1 OR ISNUMERIC(@c_UDF02) <>  1 OR @c_UDF01 > @c_UDF02
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60100
         SET @c_errmsg = 'Pickslipno# ' + RTRIM(@c_PickSlipNo) + '. Invalid LabelNo range setup for OrderType = ' + RTRIM(@c_OrderType) + '. (isp_GLBL29)' 
         GOTO QUIT_SP
      END	 
      
      IF ISNUMERIC(@c_UDF03) <> 1	    	    
         SET @c_UDF03 = @c_UDF01
         
      SET @c_UDF03 = RIGHT(REPLICATE('0',@n_Len) + RTRIM(LTRIM(CONVERT(NVARCHAR, CAST(@c_UDF03 AS BIGINT) + 1))), @n_Len)
	    
      IF CAST(@c_UDF03 AS BIGINT) > CAST(@c_UDF02 AS BIGINT) 
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60105
         SET @c_errmsg = 'Pickslipno# ' + RTRIM(@c_PickSlipNo) + '. New Tracking Number ' + RTRIM(@c_UDF03) + ' exceeded limit for OrderType =' + RTRIM(@c_OrderType) + '. (isp_GLBL29)' 
         GOTO QUIT_SP
      END	 
      
      SELECT @c_LabelNo = CONVERT(NVARCHAR(20), @c_UDF03)
      
      UPDATE CODELKUP WITH (ROWLOCK)
      SET UDF03 = @c_UDF03
      WHERE Listname ='ORDERTYPE'
      AND Code = @c_OrderType
      AND Storerkey = @c_Storerkey 
      
   END
   ELSE
   BEGIN
      SELECT @c_LabelNo = @c_PickSlipNo + CONVERT(NVARCHAR(10), @n_CartonNo)
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL29"
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