SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GLBL31                                          */
/* Creation Date: 04-Aug-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17605 LOGIEU SSCC Carton Label Print from ToteID packing*/ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                                                                      */
/* Output Parameters: @c_SSCC_Barcode - SSCC barcode number             */
/*                                                                      */
/* Usage: Call from isp_GenSSCCLabel_Wrapper                            */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 04-Aug-2021  WLChooi 1.0   DevOps Combine Script                     */
/* 29-Mar-2022  WLChooi 1.1   WMS-19339 - Unique Keyname for different  */
/*                            Storerkey (WL01)                          */
/* 20-Jun-2022  WLChooi 1.2   WMS-19339 - Only generate SSCC label for  */
/*                            Amazon orders (WL02)                      */
/************************************************************************/
CREATE PROC [dbo].[isp_GLBL31] ( 
         @c_PickSlipNo   NVARCHAR(10)
      ,  @n_CartonNo     INT
      ,  @c_SSCC_LabelNo NVARCHAR(20)   OUTPUT )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @b_debug              INT       
         , @n_StartTCnt          INT
         , @n_Continue           INT
         , @b_Success            INT 
         , @n_Err                INT  
         , @c_ErrMsg             NVARCHAR(255)

   DECLARE @c_Label_PreFix       NVARCHAR(2)    = ''
         , @c_Label_Company      NVARCHAR(10)   = ''
         , @c_Label_SeqNo        NVARCHAR(9)    = ''
         , @c_Label_CheckDigit   NVARCHAR(1)    = ''
         , @c_Userdefine05       NVARCHAR(10)
         , @c_Option1            NVARCHAR(50)   = ''
         , @c_Option2            NVARCHAR(50)   = ''
         , @c_Option3            NVARCHAR(50)   = ''
         , @c_Option4            NVARCHAR(50)   = ''
         , @c_Option5            NVARCHAR(4000) = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_Authority          NVARCHAR(10)   = ''
         , @c_KeyName            NVARCHAR(30)   = ''   --WL01
         , @c_Consigneekey       NVARCHAR(30)   = ''   --WL02

   DECLARE @n_SumOdd             INT
         , @n_SumEven            INT
         , @n_SumAll             INT
         , @n_Pos                INT
         , @n_Num                INT
         , @n_Try                INT
         , @n_NoOfLeadingZero    INT = 0

   SET @b_debug            = 0
   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   SET @c_SSCC_LabelNo     = ''

   SET @n_SumOdd  = 0
   SET @n_SumEven = 0
   SET @n_SumAll  = 0
   SET @n_Pos     = 1
   SET @n_Num     = 0
   SET @n_Try     = 0

   --WL02 S
   --SELECT @c_Storerkey = Storerkey
   --FROM PACKHEADER (NOLOCK)
   --WHERE PickSlipNo = @c_PickSlipNo

   SELECT @c_Storerkey    = OH.Storerkey
        , @c_Consigneekey = OH.ConsigneeKey
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   WHERE PH.PickSlipNo = @c_PickSlipNo

   IF ISNULL(@c_Consigneekey,'') = ''
   BEGIN
      SELECT @c_Storerkey    = OH.Storerkey
           , @c_Consigneekey = OH.ConsigneeKey
      FROM PACKHEADER PH (NOLOCK)
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LoadKey = LPD.LoadKey
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
      WHERE PH.PickSlipNo = @c_PickSlipNo
   END

   IF EXISTS (SELECT 1 
              FROM CODELKUP CL (NOLOCK) 
              WHERE CL.LISTNAME = 'LGAMZNLBL' 
              AND CL.Code = @c_Consigneekey 
              AND CL.Storerkey = @c_Storerkey)
   BEGIN   --WL02 E
      --WL01 S
      SET @c_KeyName = LEFT('SSCCLabelNo_' + TRIM(@c_Storerkey), 30)
      
      IF ISNULL(@c_KeyName,'') = ''
         SET @c_KeyName = 'SSCCLabelNo_LOGIEU'
      --WL01 E
      
      EXECUTE nspGetRight   
         '',   --Facility    
         @c_StorerKey,                
         '', -- SKU,                      
         'GenSSCCLabel_SP ', -- Configkey  
         @b_Success    OUTPUT,  
         @c_Authority  OUTPUT,  
         @n_Err        OUTPUT,  
         @c_Errmsg     OUTPUT,  
         @c_Option1    OUTPUT,
         @c_Option2    OUTPUT,
         @c_Option3    OUTPUT,    
         @c_Option4    OUTPUT,    
         @c_Option5    OUTPUT  
      
      SET @c_Label_PreFix  = CASE WHEN ISNULL(@c_Option1,'') = '' THEN '' ELSE LEFT(TRIM(@c_Option1), 2)  END
      SET @c_Label_Company = CASE WHEN ISNULL(@c_Option2,'') = '' THEN '' ELSE LEFT(TRIM(@c_Option2), 10) END
      
      /*******************************************************************************************************/
      /* Calculation of Check Digit                                                                          */
      /* ==========================                                                                          */
      /* Eg. SSCCLabelNo = 00093139381000000041                                                              */
      /* The last digit is a check digit and is calculated using the following formula:                      */
      /* The check digit is only based on pos 3 - 19. eg. 09313938100000004                                  */
      /* Step 1 : (Sum all odd pos.) x 3 eg. 14 x 3 = 42                                                     */
      /* Step 2 : Sum all even pos. eg. 27                                                                   */
      /* Step 3 : Step 1 + Step 2 eg. 42 + 27 = 69                                                           */
      /* Step 4 : Find the smallest number that added to the result of Step 3 will make it a multiple of 10. */
      /*******************************************************************************************************/
      
      -- Form SSCC Label
      -- Get running number
      EXECUTE dbo.nspg_GetKey
         @c_KeyName,   --'SSCCLabelNo_LOGIEU',   --WL01
         9,
         @c_Label_SeqNo OUTPUT,
         @b_Success     OUTPUT,
         @n_err         OUTPUT,
         @c_errmsg      OUTPUT
         
      SET @c_Label_SeqNo = RIGHT(REPLICATE('0',9) + @c_Label_SeqNo, 9)
      
      IF @b_debug = 1
      BEGIN
         SELECT @c_Label_SeqNo '@c_Label_SeqNo'
      END 
      
      -- Step 1
      SET @n_NoOfLeadingZero = 20 - LEN(TRIM(@c_Label_Prefix) + TRIM(@c_Label_Company) + TRIM(@c_Label_SeqNo) + TRIM(@c_Label_CheckDigit)) - 1
      SET @c_SSCC_LabelNo  = @c_Label_Prefix + @c_Label_Company + REPLICATE('0', @n_NoOfLeadingZero) + @c_Label_SeqNo + @c_Label_CheckDigit
      
      -- Step 2
      WHILE @n_Pos <= LEN(@c_SSCC_LabelNo)
      BEGIN
         SET @n_Num = SUBSTRING(@c_SSCC_LabelNo, @n_Pos, 1)
      
         IF @n_Pos % 2 = 0
         BEGIN
            SET @n_SumEven = @n_SumEven + @n_Num
         END
         ELSE
         BEGIN
            SET @n_SumOdd = @n_SumOdd + @n_Num
         END
         SET @n_Pos = @n_Pos + 1
      END
      
      -- Step 3
      SET @n_SumAll = (@n_SumOdd * 3) + @n_SumEven
      
      IF @b_debug = 1
      BEGIN
         SELECT @n_SumEven '@n_SumEven', @n_SumOdd '@n_SumOdd', @n_SumAll '@n_SumAll'
      END
      
      -- Step 4
      SET @c_Label_CheckDigit = CONVERT(NVARCHAR(1),(1000 - @n_SumAll) % 10)
      
      SET @c_SSCC_LabelNo  = RTRIM(@c_SSCC_LabelNo) + @c_Label_CheckDigit
      
      IF @b_debug = 1   
      BEGIN
         SELECT @c_Label_CheckDigit '@c_Label_CheckDigit', @c_SSCC_LabelNo '@c_SSCC_Label' 
      END
   END   --WL02 S
   ELSE   --Not in codelkup, generate 10 digits labelno   
   BEGIN
      EXEC isp_GenUCCLabelNo_Std  
            @cPickslipNo   = @c_PickSlipNo
         ,  @nCartonNo     = @n_CartonNo
         ,  @cLabelNo      = @c_SSCC_LabelNo   OUTPUT
         ,  @b_success     = @b_success        OUTPUT
         ,  @n_err         = @n_err            OUTPUT
         ,  @c_errmsg      = @c_errmsg         OUTPUT
      
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60060 
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_GenUCCLabelNo_Std. (isp_GLBL31)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      END
   END   --WL02 E

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GLBL31'
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