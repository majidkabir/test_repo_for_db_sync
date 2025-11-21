SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GLBL34                                          */
/* Creation Date: 21-Sep-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20834 - [CN] Dr.Jart+ Customization for LabelNo         */
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    Storerconfig: GenLabelNo_SP='isp_GLBL34'          */
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
/* Date         Author   Ver  Purposes                                  */
/* 21-Sep-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_GLBL34] (
         @c_PickSlipNo   NVARCHAR(10)
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20)   OUTPUT )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_Continue       INT
           ,@b_Success        INT
           ,@n_Err            INT
           ,@c_ErrMsg         NVARCHAR(255)
           ,@n_StartTCnt      INT
           ,@c_Storerkey      NVARCHAR(15)
           ,@c_Prefix     NVARCHAR(3)
           ,@c_UDF02          NVARCHAR(10)
           ,@n_CheckDigit     INT
           ,@c_PackNo_Long    NVARCHAR(250)
           ,@c_Keyname        NVARCHAR(30)
           ,@c_nCounter       NVARCHAR(25)
           ,@n_TotalCnt       INT
           ,@n_TotalOddCnt    INT
           ,@n_TotalEvenCnt   INT
           ,@n_Add            INT
           ,@n_Divide         INT
           ,@n_Remain         INT
           ,@n_OddCnt         INT
           ,@n_EvenCnt        INT
           ,@n_Odd            INT
           ,@n_Even           INT
           ,@c_Facility       NVARCHAR(5)
           ,@c_Authority      NVARCHAR(30)
           ,@c_Option1        NVARCHAR(50)
           ,@c_Option2        NVARCHAR(50)
           ,@c_Option3        NVARCHAR(50)
           ,@c_Option4        NVARCHAR(50)
           ,@c_Option5        NVARCHAR(4000)
           ,@n_Min            INT
           ,@n_Max            INT
           ,@n_Len            INT
           ,@c_RunningNo      NVARCHAR(20)

   SELECT @n_StartTCnt=@@TRANCOUNT, @n_Continue=1, @b_Success=1, @c_ErrMsg='', @n_Err=0

   SELECT @c_Storerkey = ORDERS.StorerKey
        , @c_Facility  = ORDERS.Facility
   FROM PICKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PICKHEADER.OrderKey = ORDERS.OrderKey
   WHERE PICKHEADER.PickHeaderKey = @c_PickSlipNo

   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Storerkey = ORDERS.StorerKey
                 , @c_Facility  = ORDERS.Facility
      FROM PICKHEADER (NOLOCK)
      JOIN ORDERS (NOLOCK) ON PICKHEADER.ExternOrderKey = ORDERS.LoadKey
      WHERE PICKHEADER.PickHeaderKey = @c_PickSlipNo
      AND ISNULL(PICKHEADER.ExternOrderKey,'') <> ''
   END

   SET @c_UDF02 = ''
   SET @c_Prefix = ''
   SET @c_LabelNo = ''

   EXECUTE nspGetRight 
      @c_Facility,  
      @c_StorerKey,              
      '', -- @c_SKU,                    
      'GenLabelNo_SP', -- Configkey
      @b_Success    OUTPUT,
      @c_Authority  OUTPUT,
      @n_Err        OUTPUT,
      @c_Errmsg     OUTPUT,
      @c_Option1    OUTPUT,  --prefix
      @c_Option2    OUTPUT,  --keyname
      @c_Option3    OUTPUT,  --mix
      @c_Option4    OUTPUT,  --max
      @c_Option5    OUTPUT
  
   IF @c_authority = 'isp_GLBL34'
   BEGIN
      IF ISNULL(@c_option1,'') <> ''
         SET @c_Prefix = @c_Option1
       
      IF ISNULL(@c_option2,'') <> ''
         SET @c_keyname = @c_Option2
       
      IF ISNUMERIC(@c_option3) = 1 AND ISNUMERIC(@c_option4) = 1
      BEGIN
         SET @n_Min = CAST(@c_option3 AS INT)
         SET @n_Max = CAST(@c_option4 AS INT)
         IF LEN(@c_option4) > 1
            SET @n_Len = LEN(@c_option4)
      END   	        	           
   END

   SELECT TOP 1 @c_UDF02 = ISNULL(CL.UDF02,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'HBFAC'
   AND CL.Storerkey = @c_Storerkey
   AND CL.Long = @c_Facility

   EXECUTE dbo.nspg_GetKeyMinMax   
      @c_keyname,   
      @n_Len,   
      @n_Min,
      @n_Max,
      @c_RunningNo  OUTPUT,   
      @b_Success    OUTPUT,   
      @n_Err        OUTPUT,   
      @c_Errmsg     OUTPUT 

   SET @c_LabelNo = TRIM(ISNULL(@c_Prefix,'')) + TRIM(ISNULL(@c_UDF02,'')) + TRIM(ISNULL(@c_RunningNo,''))

   SET @n_Odd = 1
   SET @n_OddCnt = 0
   SET @n_TotalOddCnt = 0
   SET @n_TotalCnt = 0

   WHILE @n_Odd <= 20
   BEGIN
      SET @n_OddCnt = CAST(SUBSTRING(@c_LabelNo, @n_Odd, 1) AS INT)
      SET @n_TotalOddCnt = @n_TotalOddCnt + @n_OddCnt
      SET @n_Odd = @n_Odd + 2
   END

   SET @n_TotalCnt = (@n_TotalOddCnt * 3)

   SET @n_Even = 2
   SET @n_EvenCnt = 0
   SET @n_TotalEvenCnt = 0

   WHILE @n_Even <= 20
   BEGIN
      SET @n_EvenCnt = CAST(SUBSTRING(@c_LabelNo, @n_Even, 1) AS INT)
      SET @n_TotalEvenCnt = @n_TotalEvenCnt + @n_EvenCnt
      SET @n_Even = @n_Even + 2
   END

   SET @n_Add = 0
   SET @n_Remain = 0
   SET @n_CheckDigit = 0

   SET @n_Add = @n_TotalCnt + @n_TotalEvenCnt
   SET @n_Remain = @n_Add % 10
   SET @n_CheckDigit = 10 - @n_Remain

   IF @n_CheckDigit = 10
      SET @n_CheckDigit = 0

   SET @c_LabelNo = ISNULL(TRIM(@c_LabelNo), '') + CAST(@n_CheckDigit AS NVARCHAR(1))

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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_GLBL34'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012
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