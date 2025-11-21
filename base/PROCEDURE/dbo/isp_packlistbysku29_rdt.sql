SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: isp_PackListBySku29_rdt                                 */
/* Creation Date: 08-AUG-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-20430 - [CN] Yonex_B2B_PackingList                      */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_sku29_rdt                            */
/*          :                                                           */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver   Purposes                                 */
/* 08-AUG-2022  CHONGCS   1.0   Created - DevOps Script Combine         */
/* 05-OCT-2022  CSCHONG   1.1   WMS-20430 Fix jan code cannot show (CS01)*/
/* 11-NOV-2022  MINGLE    1.2   WMS-21143 Modify logic (ML01)           */
/************************************************************************/
CREATE PROC [dbo].[isp_PackListBySku29_rdt]
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
         , @n_ttlctn            INT


   DECLARE @c_Company   NVARCHAR(45)  = ''
         , @c_City      NVARCHAR(45)  = ''
         , @c_Addresses NVARCHAR(255) = ''
         , @c_Contact1  NVARCHAR(45)  = ''
         , @c_state     NVARCHAR(45)  = ''
         , @c_OrdDate   NVARCHAR(10) = ''
         , @c_RptHeader01  NVARCHAR(250) = N'"利丰物流装箱单"'
         , @c_RptHeader02  NVARCHAR(250) = N'（配送用)'
         , @c_RptHeader03  NVARCHAR(100) = 'YONEX'
         , @c_unit         NVARCHAR(50) = 'PCS'
			, @c_Lottable02		 NVARCHAR(20)	--ML01
			, @c_GetOrdkey        NVARCHAR(20) = ''	--ML01
   

	SELECT @c_GetOrdkey = PH.Orderkey
   FROM PACKHEADER PH (NOLOCK)
   WHERE  PH.Pickslipno = @c_Pickslipno	--ML01

   SELECT @n_ttlctn = MAX(PD.CartonNo)
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.PickSlipNo
   WHERE PH.Pickslipno = @c_Pickslipno

	SELECT TOP 1 @c_Lottable02 = ISNULL(LOTATTRIBUTE.Lottable02,'')
   FROM LOTATTRIBUTE(NOLOCK) 
	JOIN PICKDETAIL(NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
	WHERE PICKDETAIL.OrderKey = @c_GetOrdkey	--ML01

   SELECT
          LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +
          LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) AS C_Addresses
        , LTRIM(RTRIM(ISNULL(OH.C_Contact1,'')))  AS C_Contact1
        , LTRIM(RTRIM(ISNULL(OH.c_phone1,'')))     AS c_phone1
        , OH.ExternOrderKey  AS ExternOrderKey         
        , OH.OrderKey AS orderkey
        , @n_ttlctn AS ttlctn
        , PD.SKU AS sku
        , ISNULL(S.DESCR,'') AS DESCR
        , s.color AS color
        , S.size AS ssize
        , SUM(PD.Qty) AS Qty
        --, CASE WHEN ISNULL(UCC.UCCno,'') <>'' OR ISNULL(PD.UPC,'') <>'' THEN
        --   CASE WHEN ISNULL(UCC.UCCno,'') <> '' THEN ISNULL(UCC.UCCno,'')  ELSE ISNULL(PD.UPC,'') END 
        --  ELSE upc.upc END AS upc               --CS01
		  , CASE WHEN @c_Lottable02 <> '' THEN @c_Lottable02  ELSE ISNULL(UPC.UPC,'') END AS UPC	--ML01  
        , Pickslipno = @c_Pickslipno 
        , @c_RptHeader01 AS RptHeader01
        , @c_RptHeader02 AS RptHeader02
        , @c_RptHeader03 AS RptHeader03
         , @c_unit AS Unit
   INTO #TMP_SKU29rdt
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.PickSlipNo
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   JOIN SKU S (NOLOCK) ON S.Sku = PD.SKU AND S.StorerKey = PD.StorerKey  
   LEFT JOIN UCC UCC (NOLOCK) ON UCC.uccno = PD.UPC
   CROSS APPLY (SELECT TOP 1 UPC.UPC AS UPC FROM UPC WITH (NOLOCK) 
               WHERE  UPC.StorerKey=PD.StorerKey AND UPC.Sku=pd.sku AND upc.uom='EA') AS UPC   --CS01
	--LEFT JOIN PICKDETAIL PID (NOLOCK) ON  PID.CaseID = PD.LabelNo AND PID.Sku = PD.SKU --ML01  
	--LEFT JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.lot = PID.Lot --ML01  
   WHERE PH.Pickslipno = @c_Pickslipno
   GROUP BY OH.ExternOrderKey   
          , OH.orderkey
          , PD.SKU
          , ISNULL(S.DESCR,'')
          , s.color
          , s.size
          --, CASE WHEN ISNULL(UCC.UCCno,'') <>'' OR ISNULL(PD.UPC,'') <>'' THEN
          -- CASE WHEN ISNULL(UCC.UCCno,'') <> '' THEN ISNULL(UCC.UCCno,'')  ELSE ISNULL(PD.UPC,'') END 
          --ELSE upc.upc END     --CS01
			 , CASE WHEN @c_Lottable02 <> '' THEN @c_Lottable02  ELSE ISNULL(UPC.UPC,'') END	--ML01 
          , LTRIM(RTRIM(ISNULL(OH.C_City,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +
             LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_Contact1,''))) 
          , LTRIM(RTRIM(ISNULL(OH.c_phone1,'')))


      SELECT  *
      FROM #TMP_SKU29rdt
      ORDER BY orderkey   --CS01

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_SKU29rdt') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_SKU29rdt
   END

   IF @n_continue=3  -- Error Occured - Process And Return
    BEGIN
       SELECT @b_success = 0
       IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
       EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_PackListBySku29_rdt"
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