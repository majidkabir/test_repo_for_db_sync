SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PackListBySku21_rdt                                 */
/* Creation Date: 06-Oct-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Mingle                                                   */
/*                                                                      */
/* Purpose: WMS-18070 - [CN] WENS_B2B_PackingList_CR                    */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_sku21_rdt                            */
/*          :                                                           */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 06-Oct-2021 Mingle   1.0   Created - DevOps Script Combine           */
/************************************************************************/
CREATE PROC [dbo].[isp_PackListBySku21_rdt]
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
   
   --IF ISNULL(@c_Type,'') = '' SET @c_Type = 'H'
   
   --IF @c_Type = 'H'
   --BEGIN
   --	--WL02 S
   --	SELECT @c_Consigneekey = MAX(OH.Consigneekey)
   --	     , @c_Storerkey    = MAX(OH.StorerKey)
   --   FROM PACKHEADER PH (NOLOCK)
   --   JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
   --   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   --   WHERE PH.Pickslipno = @c_Pickslipno   
      
   --   IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
   --              WHERE CL.LISTNAME = 'PrintJIT'
   --              AND CL.Code = @c_Consigneekey
   --              AND CL.Storerkey = @c_Storerkey)
   --   BEGIN
   --      SELECT @c_Pickslipno, '2'
   --      GOTO QUIT_SP
   --   END
   --   ELSE
   --   BEGIN
   --      SELECT @c_Pickslipno, '1'
   --      UNION ALL
   --      SELECT @c_Pickslipno, '2'
   --      GOTO QUIT_SP
   --   END        
   --   --WL02 E
   --END
   
   
   DECLARE @c_Company   NVARCHAR(45)  = '' 
   	   , @c_City      NVARCHAR(45)  = ''
   	   , @c_Addresses NVARCHAR(255) = ''         
   	   , @c_Contact1  NVARCHAR(45)  = ''
   	   , @c_Phone1    NVARCHAR(45)  = ''

   SELECT @c_Company   = LTRIM(RTRIM(ISNULL(OH.C_Company,'')))
        , @c_City      = LTRIM(RTRIM(ISNULL(OH.C_City,'')))
        , @c_Addresses = LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +
                         LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,'')))
        , @c_Contact1  = LTRIM(RTRIM(ISNULL(OH.C_Contact1,'')))
        , @c_Phone1    = LTRIM(RTRIM(ISNULL(OH.C_Phone1,'')))
   FROM PACKHEADER PH (NOLOCK)
   JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   WHERE PH.Pickslipno = @c_Pickslipno   
 

   SELECT
          @c_Company   AS C_Company   
        , @c_City      AS C_City      
        , @c_Addresses AS C_Addresses 
        , @c_Contact1  AS C_Contact1  
        , @c_Phone1    AS C_Phone1    
        , CAST(OH.ExternOrderKey AS NVARCHAR(4000)) AS ExternOrderKey   
        , OH.LoadKey
        , PD.CartonNo
        , PD.SKU
        , ISNULL(S.DESCR,'') AS DESCR
        , ISNULL(S.Style,'') AS Style
        , ISNULL(S.Size,'')  AS Size
        , ISNULL(S.Color,'') AS Color
        , ISNULL(S.BUSR9,'') AS BUSR9
        , SUM(PD.Qty) AS Qty
        , P.PackUOM3
        , @c_Pickslipno AS Pickslipno 
   INTO #TMP_SKU21
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.PickSlipNo
   JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   JOIN SKU S (NOLOCK) ON S.Sku = PD.SKU AND S.StorerKey = PD.StorerKey
   JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey AND PD.SKU = OD.SKU   
   WHERE PH.Pickslipno = @c_Pickslipno
   AND OH.DocType = 'N'
   GROUP BY LTRIM(RTRIM(ISNULL(OH.C_Company,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_City,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +
            LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_Contact1,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_Phone1,'')))
          , OH.ExternOrderKey
          , OH.LoadKey
          , PD.CartonNo
          , PD.SKU
          , ISNULL(S.DESCR,'')
          , ISNULL(S.Style,'')
          , ISNULL(S.Size,'') 
          , ISNULL(S.Color,'')
          , ISNULL(S.BUSR9,'')
          , P.PackUOM3

   
   
   SELECT @c_Externorderkeys = STUFF((SELECT DISTINCT ', ' + RTRIM(ExternOrderKey) FROM #TMP_SKU21 ORDER BY ', ' + RTRIM(ExternOrderKey) FOR XML PATH('')),1,1,'' )
   
   UPDATE #TMP_SKU21
   SET ExternOrderkey = LTRIM(RTRIM(@c_Externorderkeys))
    
   
   --IF @c_Type = 'H1'
   --BEGIN
   --	SELECT DISTINCT *   
   --	FROM #TMP_SKU21
   --	ORDER BY Externorderkey, Style, CartonNo   
   --          , SKU, Size
   --          , Color, BUSR9
   --END
   --ELSE
   --BEGIN
   	SELECT DISTINCT *   
   	FROM #TMP_SKU21
   	ORDER BY Externorderkey, CartonNo, SKU   
             , Style, Size
             , Color, BUSR9
   --END
   
QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_SKU21') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_SKU21
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
       execute nsp_logerror @n_err, @c_errmsg, "isp_PackListBySku21_rdt"  
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