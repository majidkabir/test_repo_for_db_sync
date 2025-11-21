SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/
/* Store Procedure: isp_Pallet_Outboundlist03_rdt                       */
/* Creation Date: 29-Mar-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19339 - [CN] LOGIUS SSCC Pallet Label                   */
/*          Copy AND modify from isp_UCC_Carton_Label_113               */
/*                                                                      */
/* Input Parameters: @c_Palletkey - Palletkey                           */
/*                                                                      */
/* Usage: Call by dw = r_dw_pallet_outboundlist03_rdt                   */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 29-Mar-2021  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_Pallet_Outboundlist03_rdt] ( 
   @c_Palletkey    NVARCHAR(30)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug           INT
         , @n_Continue        INT
         , @c_ResultRowCtn    NVARCHAR(20)   
         , @c_MixedSKU        NVARCHAR(1) = 'N'
         , @c_SSCC_LabelNo    NVARCHAR(20) = ''
         , @c_StorerKey       NVARCHAR(15)
         , @b_Success         INT
         , @c_Authority       NVARCHAR(30)
         , @n_Err             INT
         , @c_Errmsg          NVARCHAR(250)
         , @c_SQL             NVARCHAR(4000)   
         , @c_ExecArguments   NVARCHAR(4000)

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
         , @c_KeyName            NVARCHAR(18)   = ''   --WL01

   DECLARE @n_SumOdd             INT
         , @n_SumEven            INT
         , @n_SumAll             INT
         , @n_Pos                INT
         , @n_Num                INT
         , @n_Try                INT
         , @n_NoOfLeadingZero    INT = 0
         , @n_RecCnt             INT = 0

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

   SET @b_debug = 0             
   SET @c_ResultRowCtn = '0'
   SET @n_Continue = 1

   IF OBJECT_ID('tempdb..#TMP_PLTOB03') IS NOT NULL
      DROP TABLE #TMP_PLTOB03

   SELECT @c_StorerKey = StorerKey
   FROM PALLETDETAIL (NOLOCK) 
   WHERE Palletkey = @c_Palletkey

   --SET @c_KeyName = LEFT('SSCCLabelNo_' + TRIM(@c_Storerkey), 30)

   --IF (@n_Continue = 1 OR @n_Continue = 2)
   --BEGIN 
   --   EXECUTE nspGetRight   
   --      '',   --Facility    
   --      @c_StorerKey,                
   --      '', -- SKU,                      
   --      'GenSSCCLabel_SP ', -- Configkey  
   --      @b_Success    OUTPUT,  
   --      @c_Authority  OUTPUT,  
   --      @n_Err        OUTPUT,  
   --      @c_Errmsg     OUTPUT,
   --      @c_Option1    OUTPUT,
   --      @c_Option2    OUTPUT,
   --      @c_Option3    OUTPUT,    
   --      @c_Option4    OUTPUT,    
   --      @c_Option5    OUTPUT  

   --   SET @c_Label_PreFix  = CASE WHEN ISNULL(@c_Option1,'') = '' THEN '' ELSE LEFT(TRIM(@c_Option1), 2)  END
   --   SET @c_Label_Company = CASE WHEN ISNULL(@c_Option2,'') = '' THEN '' ELSE LEFT(TRIM(@c_Option2), 10) END

   --   SELECT @c_Label_Company = dbo.fnc_GetParamValueFromString('@c_PalletPrefix', @c_Option5, @c_Label_Company)  
   --END
   
   --Generate SSCC Barcode
   --IF (@n_Continue = 1 OR @n_Continue = 2)
   --BEGIN 
   --   SELECT @c_SSCC_LabelNo = ISNULL(PLTD.UserDefine03,'')
   --        , @n_RecCnt = 1
   --   FROM PALLETDETAIL PLTD (NOLOCK)
   --   WHERE PLTD.PalletKey = @c_Palletkey

   --   IF ISNULL(@c_SSCC_LabelNo, '') = '' AND @n_RecCnt = 1
   --   BEGIN
   --      /*******************************************************************************************************/
   --      /* Calculation of Check Digit                                                                          */
   --      /* ==========================                                                                          */
   --      /* Eg. SSCCLabelNo = 00093139381000000041                                                              */
   --      /* The last digit is a check digit and is calculated using the following formula:                      */
   --      /* The check digit is only based on pos 3 - 19. eg. 09313938100000004                                  */
   --      /* Step 1 : (Sum all odd pos.) x 3 eg. 14 x 3 = 42                                                     */
   --      /* Step 2 : Sum all even pos. eg. 27                                                                   */
   --      /* Step 3 : Step 1 + Step 2 eg. 42 + 27 = 69                                                           */
   --      /* Step 4 : Find the smallest number that added to the result of Step 3 will make it a multiple of 10. */
   --      /*******************************************************************************************************/
         
   --      -- Form SSCC Label
   --      -- Get running number
   --      EXECUTE dbo.nspg_GetKey
   --         @c_KeyName,
   --         9,
   --         @c_Label_SeqNo OUTPUT,
   --         @b_Success     OUTPUT,
   --         @n_err         OUTPUT,
   --         @c_errmsg      OUTPUT
            
   --      SET @c_Label_SeqNo = RIGHT(REPLICATE('0',9) + @c_Label_SeqNo, 9)

   --      -- Step 1
   --      SET @n_NoOfLeadingZero = 20 - LEN(TRIM(@c_Label_Prefix) + TRIM(@c_Label_Company) + TRIM(@c_Label_SeqNo) + TRIM(@c_Label_CheckDigit)) - 1
   --      SET @c_SSCC_LabelNo  = @c_Label_Prefix + @c_Label_Company + REPLICATE('0', @n_NoOfLeadingZero) + @c_Label_SeqNo + @c_Label_CheckDigit
         
   --      -- Step 2
   --      WHILE @n_Pos <= LEN(@c_SSCC_LabelNo)
   --      BEGIN
   --         SET @n_Num = SUBSTRING(@c_SSCC_LabelNo, @n_Pos, 1)
         
   --         IF @n_Pos % 2 = 0
   --         BEGIN
   --            SET @n_SumEven = @n_SumEven + @n_Num
   --         END
   --         ELSE
   --         BEGIN
   --            SET @n_SumOdd = @n_SumOdd + @n_Num
   --         END
   --         SET @n_Pos = @n_Pos + 1
   --      END
         
   --      -- Step 3
   --      SET @n_SumAll = (@n_SumOdd * 3) + @n_SumEven
         
   --      -- Step 4
   --      SET @c_Label_CheckDigit = CONVERT(NVARCHAR(1),(1000 - @n_SumAll) % 10)
         
   --      SET @c_SSCC_LabelNo  = RTRIM(@c_SSCC_LabelNo) + @c_Label_CheckDigit  
         
   --      --If generated successfully, update to PalletDetail.UserDefine03
   --      IF ISNULL(@c_SSCC_LabelNo, '') <> ''
   --      BEGIN
   --         UPDATE PALLETDETAIL WITH (ROWLOCK)
   --         SET UserDefine03 = @c_SSCC_LabelNo
   --         WHERE PalletKey = @c_Palletkey
   --      END
   --   END
   --END

   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN 
      SELECT F.Descr
           , ISNULL(TRIM(F.Address1),'') + CHAR(13) + ISNULL(TRIM(F.Address2),'') + CHAR(13) + 
             ISNULL(TRIM(F.Address3),'') + CHAR(13) + ISNULL(TRIM(F.Address4),'') AS FAddresses
           , ISNULL(OH.C_Company,'')  AS C_Company
           , ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'') + 
             ISNULL(OH.C_Address3,'') + ISNULL(OH.C_Address4,'') + CHAR(13) +
             ISNULL(OH.C_City,'') + ' ' + ISNULL(OH.C_State,'') + ' ' + 
             ISNULL(OH.C_Zip,'') + ' ' + ISNULL(OH.C_Country,'') AS C_Addresses
           , OH.ExternPOKey
           , ISNULL(OD.UserDefine05,'') AS ExtendedField08
           , ISNULL(S.MANUFACTURERSKU,'') AS MANUFACTURERSKU
           , PD.Qty
           , PDT.TotalCarton
           , PLTD.PalletKey AS LabelNo
           , PD.SKU
           , 'China' AS COO
           , OH.ExternOrderKey
      INTO #TMP_PLTOB03
      FROM PALLETDETAIL PLTD (NOLOCK)
      JOIN PACKDETAIL PD (NOLOCK) ON PLTD.StorerKey = PD.StorerKey AND PLTD.CaseId = PD.LabelNo
      JOIN PACKHEADER PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      JOIN ORDERS OH (NOLOCK) ON PH.OrderKey = OH.Orderkey-- AND PLTD.UserDefine02 = OH.OrderKey
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey AND OD.SKU = PD.SKU 
                                  AND OD.StorerKey = PD.StorerKey
      JOIN FACILITY F (NOLOCK) ON F.Facility = OH.Facility
      JOIN SKU S (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU
      --CROSS APPLY (SELECT COUNT(DISTINCT PACKDETAIL.CartonNo) AS TotalCarton
      --             FROM PACKDETAIL (NOLOCK)
      --             WHERE PACKDETAIL.PickSlipNo = PD.PickSlipNo) AS PDT
      CROSS APPLY (SELECT COUNT(1) AS TotalCarton
                   FROM PALLETDETAIL (NOLOCK)
                   WHERE PALLETDETAIL.PalletKey = PLTD.PalletKey) AS PDT
      WHERE PLTD.PalletKey = @c_Palletkey
      ORDER BY PD.LabelNo, PD.SKU
 
      SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10))  

      SELECT @c_MixedSKU = CASE WHEN COUNT(DISTINCT TP.SKU) > 1 THEN 'Y' ELSE 'N' END
      FROM #TMP_PLTOB03 TP

      SELECT DISTINCT
             TP.Descr
           , TP.FAddresses
           , TP.C_Company
           , TP.C_Addresses
           , TP.ExternPOKey
           , CASE WHEN @c_MixedSKU = 'Y' 
                  THEN 'MULTIPLE' 
                  ELSE TP.ExtendedField08 END AS ExtendedField08
           , CASE WHEN @c_MixedSKU = 'Y' 
                  THEN 'MULTIPLE' 
                  ELSE TP.MANUFACTURERSKU END AS MANUFACTURERSKU
           , NULL
           , TP.TotalCarton
           , TP.LabelNo
           , CASE WHEN @c_MixedSKU = 'Y' 
                  THEN 'MULTIPLE' 
                  ELSE TP.SKU END AS SKU
           , TP.COO
           , TP.ExternOrderKey
      FROM #TMP_PLTOB03 TP
   END

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_PLTOB03') IS NOT NULL
      DROP TABLE #TMP_PLTOB03
END

GO