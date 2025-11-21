SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PackListBySku20_rdt                                 */
/* Creation Date: 24-Sep-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-17993 - CN D1M POMELLATO Packing list                   */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_sku20_rdt                            */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 24-Sep-2021 CSCHONG  1.0   Devops scripts Migrate                    */
/************************************************************************/
CREATE PROC [dbo].[isp_PackListBySku20_rdt]
            @c_Storerkey      NVARCHAR(15),      --Could be Storerkey/Orderkey
            @c_Pickslipno     NVARCHAR(15) = '', --Could be Pickslipno/Orderkey
            @c_CartonNoStart  NVARCHAR(20) = '', --Could be CartonNoStart
            @c_CartonNoEnd    NVARCHAR(20) = ''  --Could be CartonNoEnd
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
         , @c_FromCartonNo      NVARCHAR(10) = ''
         , @c_ToCartonNo        NVARCHAR(10) = ''
   
   CREATE TABLE #TMP_Orders (
   	Pickslipno   NVARCHAR(10)
   )
   
   --(Storerkey + Pickslipno + CartonNoStart + LabelNoTo)
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno AND @c_Pickslipno <> '')
   BEGIN
      INSERT INTO #TMP_Orders (Pickslipno)
      SELECT @c_Pickslipno
   END   
   ELSE IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Storerkey AND @c_Storerkey <> '')   --Pickslipno
   BEGIN
      INSERT INTO #TMP_Orders (Pickslipno)
      SELECT @c_Storerkey

      SET @c_CartonNoStart = '1'
      SET @c_CartonNoEnd   = '99999'
   END 
   ELSE IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE Orderkey = @c_Storerkey AND @c_Storerkey <> '')   --(Orderkey)
   BEGIN
      INSERT INTO #TMP_Orders (Pickslipno)
      SELECT TOP 1 Pickslipno
      FROM PACKHEADER (NOLOCK)
      WHERE Orderkey = @c_Storerkey

      SET @c_CartonNoStart = '1'
      SET @c_CartonNoEnd   = '99999'
   END
   ELSE   --(Storerkey + Orderkey)
   BEGIN
   	INSERT INTO #TMP_Orders (Pickslipno)
      SELECT TOP 1 Pickslipno
      FROM PACKHEADER (NOLOCK)
      WHERE Orderkey = @c_Pickslipno

      SET @c_CartonNoStart = '1'
      SET @c_CartonNoEnd   = '99999'
   END


   SELECT ISNULL(OH.C_contact1,'') c_Contact1
        , ISNULL(OH.C_Phone1,'') AS c_phone1
        , ISNULL(OH.c_address1,'') + SPACE(1) + ISNULL(OH.c_address2,'') + SPACE(1) + ISNULL(OH.c_address3,'')
               +SPACE(1) + ISNULL(OH.c_address4,'')   AS ORDCAdd
        , ISNULL(OH.C_State,'') +SPACE(1) + ISNULL(OH.C_City,'')  AS ORDCstate
        , OH.M_Company
        , s.BUSR1 AS SBUSR2 --30
        , CONVERT(NVARCHAR(20), OH.OrderDate, 101) + SPACE(2) +CONVERT(NVARCHAR(5), OH.OrderDate, 114)  AS ORDDate
        , S.SKU
        , S.Size
        ,s.Price * SUM(PID.Qty)  AS TTLAMT--FORMAT(s.Price * SUM(PID.Qty), 'C', 'zh-cn') AS TTLAMT
        , PID.id AS PIDETID
        , SUM(PID.qty) AS Qty
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
   JOIN SKU S (NOLOCK) ON PD.StorerKey = S.StorerKey AND PD.SKU = S.SKU
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = OH.OrderKey AND OD.sku = PD.SKU AND OD.StorerKey = PD.StorerKey 
   JOIN dbo.PICKDETAIL PID WITH (NOLOCK) ON PID.OrderKey = OD.OrderKey AND PID.Storerkey=OD.StorerKey AND PID.Sku=OD.Sku AND PID.OrderLineNumber = OD.OrderLineNumber
   JOIN #TMP_Orders TOS ON TOS.Pickslipno = PH.Pickslipno
   --WHERE PD.CartonNo BETWEEN @c_CartonNoStart AND @c_CartonNoEnd
   --WHERE PH.Pickslipno = @c_Pickslipno
   WHERE OH.userdefine03='POMELLATO'
   AND S.busr1 not in  (N'POMELLATO包材')
   GROUP BY ISNULL(OH.C_contact1,'')
          , ISNULL(OH.C_Phone1,'')
          , ISNULL(OH.c_address1,'') + SPACE(1) + ISNULL(OH.c_address2,'') + SPACE(1) + ISNULL(OH.c_address3,'')
               +SPACE(1) + ISNULL(OH.c_address4,'')
          , ISNULL(OH.C_State,'') +SPACE(1) + ISNULL(OH.C_City,'')
          , s.BUSR1
          , OH.M_Company
          , CONVERT(NVARCHAR(20), OH.OrderDate, 101) + SPACE(2) +CONVERT(NVARCHAR(5), OH.OrderDate, 114) 
          , s.Price
          , S.SKU
          , S.Size 
          ,PID.id
   ORDER BY  OH.M_Company, S.SKU

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_Header') IS NOT NULL
      DROP TABLE #TMP_Header

   IF OBJECT_ID('tempdb..#TMP_Orders') IS NOT NULL
      DROP TABLE #TMP_Orders
   
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
       execute nsp_logerror @n_err, @c_errmsg, "isp_PackListBySku20_rdt"  
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