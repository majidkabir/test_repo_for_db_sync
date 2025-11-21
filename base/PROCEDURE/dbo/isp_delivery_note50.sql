SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_Delivery_Note50                                */  
/* Creation Date: 05-Oct-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15419 - ID - Request new format Delivery Note Report    */
/*          for So Good Food (SGF01)                                    */  
/*                                                                      */  
/* Called By: r_dw_delivery_note50                                      */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2021-02-02   WLChooi  1.1  WMS-16205 Add Salesman Description (WL01) */
/************************************************************************/   

CREATE PROCEDURE [dbo].[isp_Delivery_Note50]
   @c_MBOLKey      NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue      INT = 1,
           @n_StartTCnt     INT,
           @b_success       INT,
           @n_err           INT,
           @c_errmsg        NVARCHAR(255),
           @c_Storerkey     NVARCHAR(15)

   SELECT @n_StartTCnt = @@TRANCOUNT
   
   CREATE TABLE #TMP_MBOL (
   	MBOLKey   NVARCHAR(10),
   	Orderkey  NVARCHAR(10)
   )
   
   IF EXISTS (SELECT 1 FROM MBOL (NOLOCK) WHERE MBOLKey = @c_MBOLKey)
   BEGIN
   	INSERT INTO #TMP_MBOL
   	(
   		MBOLKey,
   		Orderkey
   	)
   	SELECT DISTINCT MBOLKey, OrderKey
   	FROM ORDERS (NOLOCK)
   	WHERE MBOLKey = @c_MBOLKey AND [Status] = '9'
   END
   ELSE
   BEGIN
   	INSERT INTO #TMP_MBOL
   	(
   		MBOLKey,
   		Orderkey
   	)
   	SELECT DISTINCT MBOLKey, OrderKey
   	FROM ORDERS (NOLOCK)
   	WHERE Orderkey = @c_MBOLKey
   END
   
   SELECT TOP 1 @c_Storerkey = OH.Storerkey
   FROM ORDERS OH (NOLOCK)
   JOIN #TMP_MBOL TM (NOLOCK) ON TM.Orderkey = OH.OrderKey
   
   CREATE TABLE #TMP_DNSIGN (
      Code      NVARCHAR(50) NULL,
      UDF01     NVARCHAR(60) NULL,
      UDF02     NVARCHAR(60) NULL,
      UDF03     NVARCHAR(60) NULL,
      UDF04     NVARCHAR(60) NULL,
      UDF05     NVARCHAR(60) NULL )
      
   INSERT INTO #TMP_DNSIGN
   SELECT DISTINCT ISNULL(CL.Code,'')
                 , ISNULL(CL.UDF01,'')
                 , ISNULL(CL.UDF02,'')
                 , ISNULL(CL.UDF03,'')
                 , ISNULL(CL.UDF04,'')
                 , ISNULL(CL.UDF05,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'DNSIGN'
   AND CL.Code IN ('DNSIGN1','DNSIGN2','DNSIGN3')
   AND CL.Storerkey = @c_Storerkey
   
   SELECT OH.ExternOrderKey
        , OH.ExternPOKey
        , OH.UserDefine01
        , OH.OrderDate
        , OH.DeliveryDate
        , OH.ConsigneeKey
        , OH.C_Company
        , ISNULL(OH.C_Address1,'') AS C_Address1
        , ISNULL(OH.C_Address2,'') AS C_Address2
        , ISNULL(OH.C_City,'') AS C_City
        , ISNULL(OH.C_Zip,'') AS C_Zip
        , ISNULL(CL.UDF01,'') AS PmtTerm
        , OH.Salesman
        , OH.Facility + '/' + ISNULL(F.DESCR,'') AS Facility
        , MB.DriverName
        , MB.Vessel
        , MB.Equipment
        , MB.SealNo
        , ISNULL(CL1.Long,'') AS Notes
        , PD.SKU
        , S.Descr
        , FLOOR(SUM(PD.Qty)/MAX(P.CaseCnt)) AS QTYCTN
        , SUM(PD.Qty) % CONVERT(INT,MAX(P.CaseCnt)) AS QTYPCS
        , OH.[Type]
        , LEFT(OH.StorerKey,3) + ' - ' + LEFT(OH.Facility,3) AS Company
        , MB.MbolKey
        , OH.StorerKey
        , ISNULL(ST.Logo,'') AS StorerLogo
        , OH.OrderGroup
        , LTRIM(RTRIM(ISNULL(CL1.[Description],''))) + SPACE(1) + 
          CASE WHEN OH.[Type] = 'ZB55' THEN '' ELSE LTRIM(RTRIM(ISNULL(CL.Short,''))) END AS Title
        , LTRIM(RTRIM(ISNULL(CL1.UDF01,''))) AS CustomLabel
        , CASE WHEN LTRIM(RTRIM(ISNULL(CL1.UDF02,''))) = '1' THEN LTRIM(RTRIM(ISNULL(CL1.Short,''))) ELSE '' END AS CustomLabelCol
        , ISNULL((SELECT TOP 1 UDF01 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN1'),'') AS A1
        , ISNULL((SELECT TOP 1 UDF02 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN1'),'') AS A2
        , ISNULL((SELECT TOP 1 UDF03 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN1'),'') AS A3
        , ISNULL((SELECT TOP 1 UDF04 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN1'),'') AS A4
        , ISNULL((SELECT TOP 1 UDF05 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN1'),'') AS A5
        , ISNULL((SELECT TOP 1 UDF01 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN2'),'') AS B1
        , ISNULL((SELECT TOP 1 UDF02 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN2'),'') AS B2
        , ISNULL((SELECT TOP 1 UDF03 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN2'),'') AS B3
        , ISNULL((SELECT TOP 1 UDF04 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN2'),'') AS B4
        , ISNULL((SELECT TOP 1 UDF05 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN2'),'') AS B5
        , ISNULL((SELECT TOP 1 UDF01 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN3'),'') AS C1
        , ISNULL((SELECT TOP 1 UDF02 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN3'),'') AS C2
        , ISNULL((SELECT TOP 1 UDF03 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN3'),'') AS C3
        , ISNULL((SELECT TOP 1 UDF04 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN3'),'') AS C4
        , ISNULL((SELECT TOP 1 UDF05 FROM #TMP_DNSIGN WHERE Code = 'DNSIGN3'),'') AS C5  
        , ISNULL(CL2.[Description],'') AS Salescode   --WL01
   FROM MBOL MB (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.MbolKey = MB.MbolKey
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Storerkey = OH.Storerkey and CL.Code = OH.PmtTerm and CL.LISTNAME = 'PMTTERM'
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.Storerkey = OH.Storerkey and CL1.Code = OH.[Type] and CL1.LISTNAME = 'ORDERTYPE'
   OUTER APPLY (SELECT TOP 1 CODELKUP.[Description]
                FROM CODELKUP (NOLOCK)
                WHERE CODELKUP.LISTNAME = 'SalesCode'
                AND CODELKUP.Code = OH.Salesman
                ORDER BY CASE WHEN CL.Storerkey = OH.StorerKey THEN 1 ELSE 2 END) AS CL2
   JOIN PICKDETAIL PD (NOLOCK) ON OH.OrderKey = PD.OrderKey
   JOIN SKU S (NOLOCK) ON PD.Storerkey = S.StorerKey and PD.SKU = S.SKU
   JOIN PACK P (NOLOCK) ON PD.PackKey = P.PackKey
   JOIN FACILITY F (NOLOCK) ON F.Facility = OH.Facility
   JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey
   JOIN #TMP_MBOL T ON T.MBOLKey = MB.MbolKey AND T.Orderkey = OH.OrderKey
   --WHERE MB.MbolKey = @c_MBOLKey
   GROUP BY OH.ExternOrderKey 
          , OH.ExternPOKey 
          , OH.UserDefine01 
          , OH.OrderDate 
          , OH.DeliveryDate 
          , OH.ConsigneeKey 
          , OH.C_Company 
          , ISNULL(OH.C_Address1,'')
          , ISNULL(OH.C_Address2,'')
          , ISNULL(OH.C_City,'')
          , ISNULL(OH.C_Zip,'')
          , ISNULL(CL.UDF01,'')
          , OH.Salesman 
          , OH.Facility + '/' + ISNULL(F.DESCR,'')
          , MB.DriverName 
          , MB.Vessel 
          , MB.Equipment 
          , MB.SealNo 
          , ISNULL(CL1.Long,'')
          , PD.SKU
          , S.Descr
          , OH.[Type]
          , LEFT(OH.StorerKey,3) + ' - ' + LEFT(OH.Facility,3)
          , MB.MbolKey
          , OH.StorerKey
          , ISNULL(ST.Logo,'')
          , OH.OrderGroup
          , LTRIM(RTRIM(ISNULL(CL1.[Description],''))) + SPACE(1) + 
            CASE WHEN OH.[Type] = 'ZB55' THEN '' ELSE LTRIM(RTRIM(ISNULL(CL.Short,''))) END
          , LTRIM(RTRIM(ISNULL(CL1.UDF01,'')))
          , CASE WHEN LTRIM(RTRIM(ISNULL(CL1.UDF02,''))) = '1' THEN LTRIM(RTRIM(ISNULL(CL1.Short,''))) ELSE '' END
          , ISNULL(CL2.[Description],'')   --WL01
   ORDER BY OH.ExternOrderKey
   
QUIT_SP:
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_Delivery_Note50'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END 
   
END -- End Procedure

GO