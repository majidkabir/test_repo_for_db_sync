SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: isp_PackListBySku27_rdt                                 */
/* Creation Date: 09-MAY-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-19553 - [CN] Lagardere_Ecom_Packlist                    */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_sku27_rdt                            */
/*          :                                                           */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver   Purposes                                 */
/* 09-MAY-2022  CHONGCS   1.0   Created - DevOps Script Combine         */
/* 14-JUL-2022  CHONGCS   1.1   WMS-20240 revised field logic (CS01)    */
/* 12-Apr-2023  CHONGCS   1.2   WMS-22216 fixed qty issue (CS02)        */
/************************************************************************/
CREATE   PROC [dbo].[isp_PackListBySku27_rdt]
            @c_Pickslipno NVARCHAR(10),
            @c_Type       NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt         INT
         , @n_Continue          INT
         , @n_Err               INT = 0
         , @c_ErrMsg            NVARCHAR(255) = ''
         , @b_success           INT = 1
         , @c_Externorderkeys   NVARCHAR(4000) = ''
         , @c_Consigneekey      NVARCHAR(15) = ''
         , @c_Storerkey         NVARCHAR(15) = ''


   DECLARE @c_Company   NVARCHAR(45)  = ''
         , @c_City      NVARCHAR(45)  = ''
         , @c_Addresses NVARCHAR(255) = ''
         , @c_Contact1  NVARCHAR(45)  = ''
         , @c_state     NVARCHAR(45)  = ''
         , @c_OrdDate   NVARCHAR(10) = ''
         , @c_footertxt01  NVARCHAR(4000) = N'"7 天无理由退货"'
         , @c_footertxt02  NVARCHAR(4000) = N'承诺当消费者购买店铺内带有“7 天无理由退货”服 务标识的商品后，自消费者签收商品之日起 7 天内（自签收次日零时起'
         , @c_footertxt03  NVARCHAR(4000) = N'满168小时为 7 天），若商品完好，在平台规定时效内，向消费者提供“7 天无理由退货”的售后保 障服务。'
         , @c_footertxt04  NVARCHAR(4000) = N''
         , @c_footertxt05  NVARCHAR(4000) = N'注：商品完好指商品能够保持原有的品质和功能。同时消费者需保证退回的商品及其 附属'
         , @c_footertxt06  NVARCHAR(4000) = N'配（附）件（包含商标吊牌、使用说明书等）的齐全，并能保持其原有的品质及功能。 消'
         , @c_footertxt07  NVARCHAR(4000) = N'费者基于查验需要而打开商品包装，或者为确认商品的品质、功能而进行合理、适当的试 用'
         , @c_footertxt08  NVARCHAR(4000) = N'和调试不影响商品的完好。'
         , @c_footertxt09  NVARCHAR(4000) = N'运费说明'
         , @c_footertxt10  NVARCHAR(4000) = N'"7 天无理由退货"商品由消费者自行承担商品返回商家的运费；若消费者与商家另行 约定'
         , @c_footertxt11  NVARCHAR(4000) = N'则以双方约定为准。'
         , @c_footerCusttxt    NVARCHAR(200) = N'客服电话：'
         , @c_footerCustphone  NVARCHAR(200) = ''
         , @c_Picker           NVARCHAR(200) = ''--N'拣货人员：'       --CS01
         , @c_pickerName       NVARCHAR(200) = ''

   --SELECT @c_Company   = LTRIM(RTRIM(ISNULL(OH.C_Company,'')))
   --     , @c_City      = LTRIM(RTRIM(ISNULL(OH.C_City,'')))
   --     , @c_Addresses = LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +
   --                      LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,'')))
   --     , @c_Contact1  = LTRIM(RTRIM(ISNULL(OH.C_Contact1,'')))
   --     , @c_state    = LTRIM(RTRIM(ISNULL(OH.C_State,'')))
   --     , @c_OrdDate    = CONVERT(NVARCHAR(10),OH.OrderDate,111)
   --FROM PACKHEADER PH (NOLOCK)
   --JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
   --JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   --WHERE PH.Pickslipno = @c_Pickslipno


   SELECT
         LTRIM(RTRIM(ISNULL(OH.C_Company,'')))  AS C_Company    --CS01 S
        , LTRIM(RTRIM(ISNULL(OH.C_City,'')))      AS C_City
        , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +
          LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) AS C_Addresses
        , LTRIM(RTRIM(ISNULL(OH.C_Contact1,'')))  AS C_Contact1
        , LTRIM(RTRIM(ISNULL(OH.C_State,'')))     AS C_state
       -- , OH.ExternOrderKey  AS ExternOrderKey     --CS01
        , OH.M_Company  AS ExternOrderKey            --CS01
        , OH.OrderKey AS orderkey
        , 0 AS cartono
        , PD.SKU AS sku
        , ISNULL(S.DESCR,'') AS DESCR
        , PICKD.loc AS loc
        , STORER.b_contact1 AS b_contact1
        , PICKD.qty AS qty--SUM(PD.Qty) AS Qty   --CS02
        , UPC.upc AS upc
        , @c_Pickslipno AS Pickslipno
        , @c_footertxt01 AS footertxt01
        , @c_footertxt02 AS footertxt02
        , @c_footertxt03 AS footertxt03
        , @c_footertxt04 AS footertxt04
        , @c_footertxt05 AS footertxt05
        , @c_footertxt06 AS footertxt06
        , @c_footertxt07 AS footertxt07
        , @c_footertxt08 AS footertxt08
        , @c_footertxt09 AS footertxt09
        , @c_footertxt10 AS footertxt10
        , @c_footertxt11 AS footertxtq1
        , @c_footerCusttxt AS footerCusttxt
        , @c_footerCustphone AS footerCustPhone
        , CONVERT(NVARCHAR(10),OH.OrderDate,111) AS OrdDate     --CS01
        , @c_Picker AS Picker
        , @c_pickerName AS PickerName
   INTO #TMP_SKU27rdt
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.PickSlipNo
  -- JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   JOIN SKU S (NOLOCK) ON S.Sku = PD.SKU AND S.StorerKey = PD.StorerKey
   JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey AND PD.SKU = OD.SKU
    CROSS APPLY (SELECT distinct PD.loc AS loc, SUM(pd.qty) AS qty                            --CS02 S
                   FROM PICKDETAIL PD (NOLOCK)
                  WHERE PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber 
                  AND PD.Storerkey = OD.StorerKey AND PD.OrderLineNumber = OD.OrderLineNumber
                   GROUP BY PD.loc ) AS PICKD                                                  --CS02 E
   JOIN STORER     WITH (NOLOCK) ON (OH.Storerkey = STORER.Storerkey)
   CROSS APPLY (SELECT TOP 1 upc AS upc
             FROM UPC WITH (NOLOCK)
             WHERE UPC.storerkey = S.storerkey AND UPC.sku = S.Sku   
              ORDER BY upc.adddate DESC) AS UPC
   WHERE PH.Pickslipno = @c_Pickslipno
   --AND OH.DocType = 'N'
   GROUP BY OH.M_Company--OH.ExternOrderKey    --CS01
          , OH.orderkey
          , PD.SKU
          , ISNULL(S.DESCR,'')
          , PICKD.loc
          , STORER.b_contact1
          , UPC.UPC
          , LTRIM(RTRIM(ISNULL(OH.C_Company,'')))    --CS01 S
          , LTRIM(RTRIM(ISNULL(OH.C_City,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +
             LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_Contact1,''))) 
          , LTRIM(RTRIM(ISNULL(OH.C_State,'')))
          , CONVERT(NVARCHAR(10),OH.OrderDate,111)         , PICKD.qty      --CS01 E    --CS02

      SELECT DISTINCT *
      FROM #TMP_SKU27rdt
      ORDER BY Pickslipno,OrderKey,loc

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_SKU27rdt') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_SKU27rdt
   END

   IF @n_continue=3  -- Error Occured - Process And Return
    BEGIN
       SELECT @b_success = 0
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
       BEGIN
          ROLLBACK TRAN
       END
       ELSE
       BEGIN
          WHILE @@TRANCOUNT > @n_starttcnt
          BEGIN
             COMMIT TRAN
          END
       END
       execute nsp_logerror @n_err, @c_errmsg, "isp_PackListBySku27_rdt"
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
    BEGIN
       SELECT @b_success = 1
       WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
          COMMIT TRAN
       END
       RETURN
    END
END -- procedure

GO