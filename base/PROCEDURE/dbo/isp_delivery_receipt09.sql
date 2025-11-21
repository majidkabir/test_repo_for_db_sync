SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/*****************************************************************************/  
/* Stored Proc: isp_Delivery_Receipt09                                       */  
/* Creation Date: 01-Feb-2021                                                */  
/* Copyright: LF Logistics                                                   */  
/* Written by: WLChooi                                                       */  
/*                                                                           */  
/* Purpose: WMS-16276 - LEGO Delivery Note                                   */  
/*        :                                                                  */  
/* Called By: r_dw_delivery_receipt09                                        */  
/*          :                                                                */  
/* GitLab Version: 1.5                                                       */  
/*                                                                           */  
/* Version: 7.0                                                              */  
/*                                                                           */  
/* Data Modifications:                                                       */  
/*                                                                           */  
/* Updates:                                                                  */  
/* Date         Author    Ver Purposes                                       */ 
/* 2021-03-16   WLChooi   1.1 WMS-16276 - Add new columns (WL01)             */
/* 2021-03-22   WLChooi   1.2 WMS-16276 - Change sorting and column          */
/*                            logic (WL02)                                   */
/* 2021-03-25   WLChooi   1.3 Change date column due to urgent request       */
/*                            from LIT (WL03)                                */
/* 2021-04-06   WLChooi   1.4 WMS-16276 - Change to 6 d.p for Total CBM      */
/*                            and Weight (WL04)                              */
/* 2021-04-15   WLChooi   1.5 Fix Sorting (WL05)                             */  
/* 2021-04-12   WLChooi   1.6 WMS-16789 - Logic Fix For LEGO and add new     */
/*                            columns to cater for LEGOP (WL06)              */
/* 2022-03-18   CalvinK   1.7 JSM-57929 Add UserDefine03 conditions (CLVN01) */
/* 2022-03-25   CalvinK   1.8 JSM-57929 Alter UserDefine04 (CLVN02)          */
/*****************************************************************************/  
CREATE PROC [dbo].[isp_Delivery_Receipt09]
            @c_MBOLKey    NVARCHAR(10)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)  
         , @c_Orderkey        NVARCHAR(10) = ''
         , @c_SKU             NVARCHAR(20)
         , @n_SumInCtn        INT
         , @n_SumInQty        INT
         , @c_Notes           NVARCHAR(4000)
         , @c_Notes2          NVARCHAR(4000)
         , @n_STDGROSSWGT     DECIMAL(30,6) = 0.000000   --WL04 
         , @n_GrossWgt        DECIMAL(30,6) = 0.000000   --WL04 
         , @c_PrevOrderkey    NVARCHAR(10)
         , @n_TTLWeight       DECIMAL(30,6) = 0.000000   --WL04
         , @n_TTLCBM          DECIMAL(30,6) = 0.000000   --WL04
         , @n_Cube            DECIMAL(30,6) = 0.000000   --WL04
         , @n_StdCube         DECIMAL(30,6) = 0.000000   --WL04
         , @c_Storerkey       NVARCHAR(15)
         , @c_Notes2A         NVARCHAR(4000) = ''
         , @c_Notes2B         NVARCHAR(4000) = ''
         , @n_Notes2AStart    INT
         , @n_Notes2AEnd      INT
         , @n_Notes2BStart    INT
         , @n_Notes2BEnd      INT
         , @c_Containerkey    NVARCHAR(10)
         , @n_SumQty          INT   --WL06
         , @c_GetContainerkey NVARCHAR(10)   --WL06
         , @n_GetShipmentNo   BIGINT   --WL06
         , @c_OrderkeyForLoop NVARCHAR(10) = 'C888888888'   --WL06

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = ''
   
   CREATE TABLE #TMP_DATA (
   	STCompany       NVARCHAR(45)
    , STAddress1      NVARCHAR(45)
    , STAddress2      NVARCHAR(45)
    , STAddress3      NVARCHAR(45)
    , STAddress4      NVARCHAR(45)
    , STZip           NVARCHAR(45)
    , STCountry       NVARCHAR(45)
    , C_Contact1      NVARCHAR(45)
    , C_Company       NVARCHAR(45)
    , Address1        NVARCHAR(45)
    , Address2        NVARCHAR(45)
    , Address3        NVARCHAR(45)
    , Address4        NVARCHAR(45)
    , Zip             NVARCHAR(45)
    , Country         NVARCHAR(45)
    , MbolKey         NVARCHAR(10)
    , OrderKey        NVARCHAR(10)
    , ExternOrderKey  NVARCHAR(50)
    , EffectiveDate   DATETIME
    , DeliveryDate    DATETIME
    , Notes           NVARCHAR(4000)
    , Notes2A         NVARCHAR(4000)
    , Notes2B         NVARCHAR(4000)
    , UserDefine02    NVARCHAR(50)
    , SKU             NVARCHAR(50)
    , UPC             NVARCHAR(50)
    , DESCR           NVARCHAR(255)
    , SUMInCtn        INT
    , SUMInQty        INT
    , UserDefine04    NVARCHAR(50)
    , StorerKey       NVARCHAR(15)
    , TTLWeight       DECIMAL(30,6)   --WL04 
    , TTLCBM          DECIMAL(30,6)   --WL04 
    , ContainerKey    NVARCHAR(10)
    , InvoiceNo       NVARCHAR(40)
    , C_State         NVARCHAR(45)
    , Notes2          NVARCHAR(30)
    , SumQty          INT   --WL01
    , TotalCarton     INT   --WL02
   )
   --IF EXISTS (SELECT 1 FROM CONTAINER (NOLOCK) WHERE MBOLKey = @c_MBOLKey)
   --BEGIN
   
   --WL06 S
   CREATE TABLE #TMP_Qty (
      ExternOrderskey   BIGINT
    , Orderkey          NVARCHAR(10)
    , SKU               NVARCHAR(20)
    , SumInCtn          INT
    , SumInQty          INT
    , Containerkey      NVARCHAR(10) NULL
    , TotalQty          INT
   )

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT EXO.ExternOrdersKey, EXO.[Source]
   FROM ExternOrders EXO (NOLOCK)
   WHERE EXO.ExternOrderKey = @c_MBOLKey
   AND EXO.OrderKey = @c_OrderkeyForLoop

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @n_GetShipmentNo, @c_GetContainerkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN 
      INSERT INTO #TMP_Qty   --With Containerkey  
      SELECT @n_GetShipmentNo
           , EXOD.OrderKey
           , EXOD.SKU
           , CASE WHEN P.CaseCnt > 0 THEN SUM((CAST(EXOD.Userdefine03 AS INT))/P.CaseCnt) ELSE 0 END
           , SUM(CAST(EXOD.Userdefine03 AS INT)) -  CASE WHEN P.CaseCnt > 0 THEN (((SUM(CAST(EXOD.Userdefine03 AS INT))/P.CaseCnt)) * P.CaseCnt) ELSE 0 END
           , @c_GetContainerkey
           , SUM(CAST(EXOD.Userdefine03 AS INT))
      FROM ExternOrders EXO1 (NOLOCK)
      JOIN ExternOrdersDetail EXOD (NOLOCK) ON EXOD.ExternOrderKey = EXO1.ExternOrderKey AND EXOD.OrderKey = EXO1.OrderKey
      JOIN SKU S (NOLOCK) ON S.SKU = EXOD.SKU AND S.StorerKey = EXOD.StorerKey  
      JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey  
      WHERE EXO1.ExternOrderKey = @n_GetShipmentNo
      AND EXO1.OrderKey <> 'C88888888'
      GROUP BY P.CaseCnt
             , EXOD.OrderKey
             , EXOD.SKU

      FETCH NEXT FROM CUR_LOOP INTO @n_GetShipmentNo, @c_GetContainerkey
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   --SELECT * FROM #TMP_Qty
   --WL06 E

   INSERT INTO #TMP_DATA   --With Containerkey
   SELECT ST.Company
        , ISNULL(ST.Address1,'')   AS STAddress1
        , ISNULL(ST.Address2,'')   AS STAddress2
        , ISNULL(ST.Address3,'')   AS STAddress3
        , ISNULL(ST.Address4,'')   AS STAddress4
        , ISNULL(ST.Zip,'')        AS STZip
        --, ISNULL(ST.Country,'')    AS STCountry  
        , CASE ISNULL(CK1.LONG, '') WHEN '' THEN ISNULL(ST.Country,'') ELSE CK1.LONG END AS STCountry  
        , ISNULL(OH.C_Contact1,'') AS C_Contact1
        , ISNULL(OH.C_Company,'')  AS C_Company
        , ISNULL(OH.C_Address1,'') AS Address1
        , ISNULL(OH.C_Address2,'') AS Address2
        , ISNULL(OH.C_Address3,'') AS Address3
        , ISNULL(OH.C_Address4,'') AS Address4
        , ISNULL(OH.C_Zip,'')      AS Zip
        --, ISNULL(OH.C_Country,'')  AS Country  
        , CASE ISNULL(CK.LONG, '') WHEN '' THEN ISNULL(OH.C_Country,'') ELSE CK.LONG END AS Country 
        , M.MbolKey
        , OH.OrderKey
        --, OH.ExternOrderKey  Get New DeliveryNo  
        , CASE ISNULL(EXO2.UserDefine09,'') WHEN '' THEN OH.ExternOrderKey ELSE EXO2.UserDefine09 END  
        , OH.DeliveryDate   --WL03
        , OH.OrderDate      --WL03
        , OH.Notes
        , Notes2A = OH.Notes2
        , Notes2B = ''
        , CASE WHEN OH.Storerkey = 'LEGOP' THEN OD.OrderLineNumber ELSE OD.UserDefine02 END   --WL06
        , CASE WHEN OD.ConsoOrderLineNo > 0 THEN '_' + LTRIM(RTRIM(S.SKU)) ELSE LTRIM(RTRIM(S.SKU)) END AS SKU
        , CASE WHEN OH.Storerkey = 'LEGOP'   --WL06  
                    THEN S.AltSKU            --WL06 
               WHEN ISNULL(OD.UserDefine03,'') IN ('Y', 'TRUE')		--CLVN01
                    THEN CASE WHEN ISNULL(OD.RetailSku,'') <> '' THEN OD.RetailSku ELSE S.AltSku END 
               ELSE 
                    CASE WHEN LEN(EOD.Notes) > 101 THEN SUBSTRING(EOD.Notes,101, 20) ELSE S.AltSku END 
          END AS UPC
        , S.DESCR
        , MAX(t.SumInCtn) AS SUMInCtn   --WL01   --WL06
        , MAX(t.SumInQty) AS SUMInQty   --WL01   --WL06
        , OD.UserDefine04
        , OH.StorerKey
        , TTLWeight = CAST(0.000000 AS DECIMAL(30,6))   --WL04
        , TTLCBM    = CAST(0.000000 AS DECIMAL(30,6))   --WL04
        , C.Containerkey
        --, OH.UserDefine04										--(CLVN02)
		, UserDefine04 = CASE LOWER(OH.UserDefine04) 			--(CLVN02)
							WHEN 'true' THEN 'Y'				--(CLVN02)
							WHEN 'false' THEN 'N'				--(CLVN02)
							ELSE OH.UserDefine04 END			--(CLVN02)
        , ISNULL(OH.C_State,'') AS C_State
        , OD.Notes2
        , MAX(t.TTLQty)   --WL01   --WL06
        , MAX(t1.TTLCtn) AS TotalCarton   --WL02   --WL06
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
   CROSS APPLY (SELECT TOP 1 ExternOrdersDetail.Orderkey, ExternOrdersDetail.OrderLineNumber, ExternOrdersDetail.Notes
                FROM ExternOrdersDetail (NOLOCK) 
                WHERE ExternOrdersDetail.OrderKey = OD.OrderKey AND ExternOrdersDetail.OrderLineNumber = OD.OrderLineNumber) AS EOD
   JOIN MBOL M (NOLOCK) ON OH.MBOLKey = M.MbolKey
   JOIN SKU S (NOLOCK) ON S.SKU = OD.SKU AND S.StorerKey = OD.StorerKey
   --JOIN PICKDETAIL PD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.SKU = PD.Sku
   JOIN CONTAINER C (NOLOCK) ON C.MbolKey = M.MbolKey
   JOIN CONTAINERDETAIL CD (NOLOCK) ON CD.ContainerKey = C.ContainerKey
   JOIN PALLETDETAIL PLTD (NOLOCK) ON PLTD.PalletKey = CD.PalletKey
   JOIN PACKDETAIL PD (NOLOCK) ON PD.LabelNo = PLTD.CaseId AND PD.StorerKey = PLTD.StorerKey
   JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey
   JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey
   JOIN ExternOrders EXO1 (NOLOCK) ON EXO1.EXTERNORDERKEY = M.MbolKey AND EXO1.ORDERKEY = 'C888888888' AND EXO1.[Source] = C.ContainerKey        
   JOIN ExternOrders EXO2 (NOLOCK) ON EXO2.EXTERNORDERKEY = EXO1.ExternOrdersKey AND EXO2.ORDERKEY =  OH.OrderKey  
   CROSS APPLY (SELECT SUM(Qty) AS Qty FROM PICKDETAIL (NOLOCK) WHERE OrderKey = OD.OrderKey AND SKU = OD.SKU AND OrderLineNumber = OD.OrderLineNumber) AS PIDET   --WL01
   LEFT JOIN CODELKUP CK (NOLOCK) ON CK.LISTNAME = 'ISOCOUNTRY' AND CK.CODE = OH.C_COUNTRY  
   LEFT JOIN CODELKUP CK1 (NOLOCK) ON CK1.LISTNAME = 'ISOCOUNTRY' AND CK1.CODE = ST.COUNTRY 
   JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey   --WL02 
   CROSS APPLY (SELECT COUNT(DISTINCT LabelNo) AS LabelNo FROM PACKDETAIL (NOLOCK) WHERE Pickslipno = PH.PickSlipNo) AS PAD   --WL02
   CROSS APPLY (SELECT Orderkey, SKU, SUM(SumInCtn) AS SumInCtn, SUM(SumInQty) AS SumInQty, SUM(TotalQty) AS TTLQty
                FROM #TMP_Qty 
                WHERE Orderkey = OH.OrderKey AND SKU = S.SKU AND Containerkey = C.Containerkey
                GROUP BY Orderkey, SKU) AS t   --WL06
   CROSS APPLY (SELECT Orderkey, SUM(SumInCtn) AS TTLCtn
                FROM #TMP_Qty 
                WHERE Orderkey = OH.OrderKey AND Containerkey = C.Containerkey
                GROUP BY Orderkey) AS t1   --WL06
   WHERE M.MbolKey = @c_MBOLKey
   GROUP BY ST.Company
          , ISNULL(ST.Address1,'')  
          , ISNULL(ST.Address2,'')  
          , ISNULL(ST.Address3,'')  
          , ISNULL(ST.Address4,'')  
          , ISNULL(ST.Zip,'')       
          , CASE ISNULL(CK1.LONG, '') WHEN '' THEN ISNULL(ST.Country,'') ELSE CK1.LONG END  
          , ISNULL(OH.C_Contact1,'')
          , ISNULL(OH.C_Company,'') 
          , ISNULL(OH.C_Address1,'')  
          , ISNULL(OH.C_Address2,'')  
          , ISNULL(OH.C_Address3,'')  
          , ISNULL(OH.C_Address4,'')  
          , ISNULL(OH.C_Zip,'')       
          , CASE ISNULL(CK.LONG, '') WHEN '' THEN ISNULL(OH.C_Country,'') ELSE CK.LONG END 
          , M.MbolKey
          , OH.OrderKey
          , CASE ISNULL(EXO2.UserDefine09,'') WHEN '' THEN OH.ExternOrderKey ELSE EXO2.UserDefine09 END  
          , OH.DeliveryDate   --WL03
          , OH.OrderDate      --WL03
          , OH.Notes
          , OH.Notes2
          , CASE WHEN OH.Storerkey = 'LEGOP' THEN OD.OrderLineNumber ELSE OD.UserDefine02 END   --WL06
          , CASE WHEN OD.ConsoOrderLineNo > 0 THEN '_' + LTRIM(RTRIM(S.SKU)) ELSE LTRIM(RTRIM(S.SKU)) END
          , CASE WHEN OH.Storerkey = 'LEGOP'   --WL06  
                      THEN S.AltSKU            --WL06 
                 WHEN ISNULL(OD.UserDefine03,'') IN ('Y', 'TRUE')		--CLVN01
                      THEN CASE WHEN ISNULL(OD.RetailSku,'') <> '' THEN OD.RetailSku ELSE S.AltSku END 
                 ELSE 
                      CASE WHEN LEN(EOD.Notes) > 101 THEN SUBSTRING(EOD.Notes,101, 20) ELSE S.AltSku END 
            END
          , S.DESCR
          , P.CaseCnt
          , OD.UserDefine04
          , OH.StorerKey
          , C.Containerkey
          --, OH.UserDefine04									--(CLVN02)
		  , CASE LOWER(OH.UserDefine04) 						--(CLVN02)
							WHEN 'true' THEN 'Y'				--(CLVN02)
							WHEN 'false' THEN 'N'				--(CLVN02)
							ELSE OH.UserDefine04 END			--(CLVN02)
          , ISNULL(OH.C_State,'')
          , OD.Notes2
   UNION ALL   --WithOUT Containerkey
   SELECT ST.Company
        , ISNULL(ST.Address1,'')   AS STAddress1
        , ISNULL(ST.Address2,'')   AS STAddress2
        , ISNULL(ST.Address3,'')   AS STAddress3
        , ISNULL(ST.Address4,'')   AS STAddress4
        , ISNULL(ST.Zip,'')        AS STZip
        --, ISNULL(ST.Country,'')    AS STCountry  
        , CASE ISNULL(CK1.LONG, '') WHEN '' THEN ISNULL(ST.Country,'') ELSE CK1.LONG END AS STCountry  
        , ISNULL(OH.C_Contact1,'') AS C_Contact1
        , ISNULL(OH.C_Company,'')  AS C_Company
        , ISNULL(OH.C_Address1,'') AS Address1
        , ISNULL(OH.C_Address2,'') AS Address2
        , ISNULL(OH.C_Address3,'') AS Address3
        , ISNULL(OH.C_Address4,'') AS Address4
        , ISNULL(OH.C_Zip,'')      AS Zip
        --, ISNULL(OH.C_Country,'')  AS Country  
        , CASE ISNULL(CK.LONG, '') WHEN '' THEN ISNULL(OH.C_Country,'') ELSE CK.LONG END AS Country  
        , M.MbolKey
        , OH.OrderKey
        , OH.ExternOrderKey
        , OH.DeliveryDate   --WL03
        , OH.OrderDate      --WL03
        , OH.Notes
        , Notes2A = OH.Notes2
        , Notes2B = ''
        , CASE WHEN OH.Storerkey = 'LEGOP' THEN OD.OrderLineNumber ELSE OD.UserDefine02 END   --WL06
        , CASE WHEN OD.ConsoOrderLineNo > 0 THEN '_' + LTRIM(RTRIM(S.SKU)) ELSE LTRIM(RTRIM(S.SKU)) END AS SKU
        , CASE WHEN ISNULL(OD.UserDefine03,'') IN ('Y', 'TRUE')		--CLVN01
               THEN CASE WHEN ISNULL(OD.RetailSku,'') <> '' THEN OD.RetailSku ELSE S.AltSku END 
               ELSE CASE WHEN LEN(EOD.Notes) > 101 THEN SUBSTRING(EOD.Notes,101, 20) ELSE S.AltSku END 
          END AS UPC
        , S.DESCR
        , CASE WHEN P.CaseCnt > 0 THEN FLOOR(MAX(PIDET.Qty)/P.CaseCnt) ELSE 0 END AS SUMInCtn   --WL01
        , MAX(PIDET.Qty) -  CASE WHEN P.CaseCnt > 0 THEN (FLOOR(MAX(PIDET.Qty)/P.CaseCnt) * P.CaseCnt) ELSE 0 END AS SUMInQty   --WL01
        , OD.UserDefine04
        , OH.StorerKey
        , TTLWeight = CAST(0.000000 AS DECIMAL(30,6))   --WL04
        , TTLCBM    = CAST(0.000000 AS DECIMAL(30,6))   --WL04
        , ''
        --, OH.UserDefine04										--(CLVN02)
		, UserDefine04 = CASE LOWER(OH.UserDefine04) 			--(CLVN02)
							WHEN 'true' THEN 'Y'				--(CLVN02)
							WHEN 'false' THEN 'N'				--(CLVN02)
							ELSE OH.UserDefine04 END			--(CLVN02)
        , ISNULL(OH.C_State,'') AS C_State
        , OD.Notes2
        , MAX(PIDET.Qty)   --WL01
        , MAX(PAD.LabelNo) AS TotalCarton   --WL02
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
   OUTER APPLY (SELECT TOP 1 ExternOrdersDetail.Orderkey, ExternOrdersDetail.OrderLineNumber, ExternOrdersDetail.Notes   --WL06
                FROM ExternOrdersDetail (NOLOCK) 
                WHERE ExternOrdersDetail.OrderKey = OD.OrderKey AND ExternOrdersDetail.OrderLineNumber = OD.OrderLineNumber) AS EOD
   JOIN MBOL M (NOLOCK) ON OH.MBOLKey = M.MbolKey
   JOIN SKU S (NOLOCK) ON S.SKU = OD.SKU AND S.StorerKey = OD.StorerKey
   JOIN PICKDETAIL PD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.SKU = PD.Sku
   JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey
   JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey
   CROSS APPLY (SELECT SUM(Qty) AS Qty FROM PICKDETAIL (NOLOCK) WHERE OrderKey = OD.OrderKey AND SKU = OD.SKU AND OrderLineNumber = OD.OrderLineNumber) AS PIDET   --WL01
   LEFT JOIN CODELKUP CK (NOLOCK) ON CK.LISTNAME = 'ISOCOUNTRY' AND CK.CODE = OH.C_COUNTRY  
   LEFT JOIN CODELKUP CK1 (NOLOCK) ON CK1.LISTNAME = 'ISOCOUNTRY' AND CK1.CODE = ST.COUNTRY  
   JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey   --WL02
   CROSS APPLY (SELECT COUNT(DISTINCT LabelNo) AS LabelNo FROM PACKDETAIL (NOLOCK) WHERE Pickslipno = PH.PickSlipNo) AS PAD   --WL02
   WHERE M.MbolKey = @c_MBOLKey  
   AND NOT EXISTS (SELECT 1 FROM CONTAINERDETAIL CTD1 (NOLOCK)
                   JOIN PALLETDETAIL PLTD1 (NOLOCK) ON CTD1.PalletKey = PLTD1.PalletKey
                   JOIN PACKDETAIL   PKD1  (NOLOCK) ON PLTD1.CaseId = PKD1.LabelNo  
                   JOIN PackHeader   PKDH1 (NOLOCK) ON PKD1.PickSlipNo = PKDH1.PickSlipNo AND PKDH1.OrderKey = OH.OrderKey)
   GROUP BY ST.Company
          , ISNULL(ST.Address1,'')  
          , ISNULL(ST.Address2,'')  
          , ISNULL(ST.Address3,'')  
          , ISNULL(ST.Address4,'')  
          , ISNULL(ST.Zip,'')       
          , CASE ISNULL(CK1.LONG, '') WHEN '' THEN ISNULL(ST.Country,'') ELSE CK1.LONG END  
          , ISNULL(OH.C_Contact1,'')
          , ISNULL(OH.C_Company,'') 
          , ISNULL(OH.C_Address1,'')  
          , ISNULL(OH.C_Address2,'')  
          , ISNULL(OH.C_Address3,'')  
          , ISNULL(OH.C_Address4,'')  
          , ISNULL(OH.C_Zip,'')       
          , CASE ISNULL(CK.LONG, '') WHEN '' THEN ISNULL(OH.C_Country,'') ELSE CK.LONG END  
          , M.MbolKey
          , OH.OrderKey
          , OH.ExternOrderKey
          , OH.DeliveryDate   --WL03
          , OH.OrderDate      --WL03
          , OH.Notes
          , OH.Notes2
          , CASE WHEN OH.Storerkey = 'LEGOP' THEN OD.OrderLineNumber ELSE OD.UserDefine02 END   --WL06
          , CASE WHEN OD.ConsoOrderLineNo > 0 THEN '_' + LTRIM(RTRIM(S.SKU)) ELSE LTRIM(RTRIM(S.SKU)) END
          , CASE WHEN ISNULL(OD.UserDefine03,'') IN ('Y', 'TRUE')		--CLVN01
                 THEN CASE WHEN ISNULL(OD.RetailSku,'') <> '' THEN OD.RetailSku ELSE S.AltSku END 
                 ELSE CASE WHEN LEN(EOD.Notes) > 101 THEN SUBSTRING(EOD.Notes,101, 20) ELSE S.AltSku END 
            END
          , S.DESCR
          , P.CaseCnt
          , OD.UserDefine04
          , OH.StorerKey
          --, OH.UserDefine04									--(CLVN02)
		  , CASE LOWER(OH.UserDefine04) 						--(CLVN02)
							WHEN 'true' THEN 'Y'				--(CLVN02)
							WHEN 'false' THEN 'N'				--(CLVN02)
							ELSE OH.UserDefine04 END			--(CLVN02)
          , ISNULL(OH.C_State,'')
          , OD.Notes2

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Orderkey, SKU, SUM(SUMInCtn), SUM(SUMInQty), Notes2A, Storerkey, Containerkey, SUM(SumQty)   --WL06
      FROM #TMP_DATA 
      GROUP BY Orderkey, SKU, Notes2A, Storerkey, Containerkey
      ORDER BY Orderkey, SKU
   
   OPEN CUR_LOOP
   	
   FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @c_SKU, @n_SumInCtn, @n_SumInQty, @c_Notes2, @c_Storerkey, @c_Containerkey, @n_SumQty   --WL06
                                                                               
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	IF @c_PrevOrderkey <> @c_Orderkey
   	BEGIN
         SET @c_Notes2B = ''  
         SET @c_Notes2A = ''  
         SET @n_Notes2AEnd = 0  
         SET @n_Notes2BEnd = 0  
         
         SELECT @n_Notes2AStart = PATINDEX('%SHIPPING%', @c_Notes2)  
         
         IF @n_Notes2AStart > 0  
         BEGIN  
            SELECT @n_Notes2AEnd = @n_Notes2AStart + LEN('SHIPPING')  
         END  

         SELECT @n_Notes2BStart = PATINDEX('%BOOKING%', @c_Notes2)  
         
         IF @n_Notes2BStart > 0  
         BEGIN  
            SELECT @n_Notes2BEnd = @n_Notes2BStart + LEN('BOOKING')  
            SELECT @c_Notes2B    = RIGHT(@c_Notes2, (LEN(@c_Notes2) - @n_Notes2BEnd))  
            SELECT @c_Notes2     = LEFT(@c_Notes2, @n_Notes2BStart - 2)  
         END  
           
         IF @n_Notes2AStart > 0  
         BEGIN  
            SELECT @c_Notes2A = SUBSTRING(@c_Notes2, @n_Notes2AEnd + 1, LEN(@c_Notes2) - @n_Notes2AEnd)  
         END  
         
         --SELECT @c_Notes2A = ColValue FROM dbo.fnc_delimsplit ('|',@c_Notes2) WHERE SeqNo = 3
         --SELECT @c_Notes2B = ColValue FROM dbo.fnc_delimsplit ('|',@c_Notes2) WHERE SeqNo = 5
   	END
   	
      SELECT @n_STDGROSSWGT = SKU.STDGROSSWGT
   	     , @n_GrossWgt    = SKU.GrossWgt   
   	     , @n_Cube        = SKU.[Cube]       
   	     , @n_StdCube     = SKU.StdCube    
   	FROM SKU (NOLOCK)
   	WHERE SKU.SKU = @c_SKU AND SKU.StorerKey = @c_Storerkey

      --WL06 S
      IF @c_Storerkey = 'LEGO'
      BEGIN
   	   SET @n_TTLWeight = (@n_SumInCtn * @n_GrossWgt)      --Full Case
   	   SET @n_TTLWeight = @n_TTLWeight + (@n_SumInQty * @n_STDGROSSWGT)   --Loose
   	   
         SET @n_TTLCBM = (@n_SumInCtn * @n_Cube)      --Full Case
   	   SET @n_TTLCBM = @n_TTLCBM + (@n_SumInQty * @n_StdCube)   --Loose
   	   
   	   UPDATE #TMP_DATA
   	   SET TTLWeight = TTLWeight + @n_TTLWeight
   	     , TTLCBM    = TTLCBM + @n_TTLCBM
   	     , Notes2A   = @c_Notes2A
   	     , Notes2B   = @c_Notes2B
   	   WHERE Orderkey = @c_Orderkey AND SKU = @c_SKU AND ContainerKey = @c_Containerkey
   	END
      ELSE IF @c_Storerkey = 'LEGOP'
      BEGIN
         SET @n_TTLWeight = (@n_SumQty * @n_GrossWgt)
         SET @n_TTLCBM    = (@n_SumQty * @n_Cube)
         
         UPDATE #TMP_DATA
         SET TTLWeight = TTLWeight + @n_TTLWeight
           , TTLCBM    = TTLCBM + @n_TTLCBM
           , Notes2A   = @c_Notes2A
           , Notes2B   = @c_Notes2B
         WHERE Orderkey = @c_Orderkey AND SKU = @c_SKU AND ContainerKey = @c_Containerkey
      END
      --WL06 E

   	SET @n_TTLWeight = 0.00
   	SET @n_TTLCBM    = 0.00
   	SET @c_Notes2A   = ''
   	SET @c_Notes2B   = ''
   	                            
      FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @c_SKU, @n_SumInCtn, @n_SumInQty, @c_Notes2, @c_Storerkey, @c_Containerkey, @n_SumQty   --WL06
   END
   
   SELECT * FROM #TMP_DATA ORDER BY Containerkey, OrderKey, CASE WHEN ISNUMERIC(UserDefine02) = 1 THEN CAST(UserDefine02 AS INT) ELSE UserDefine02 END   --WL05   --WL06 
   
QUIT_SP:  
   IF OBJECT_ID('tempdb..#TMP_DATA') IS NOT NULL
      DROP TABLE #TMP_DATA

   --WL06
   IF OBJECT_ID('tempdb..#TMP_Qty') IS NOT NULL
      DROP TABLE #TMP_Qty

END -- procedure

GO