SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_102                                   */
/* Creation Date: 11-MAR-2021                                              */
/* Copyright: LF Logistics                                                 */
/* Written by: CSCHONG                                                     */
/*                                                                         */
/* Purpose: WMS-16377-[MY]-Carton Label Modification-[CR]                  */
/*                                                                         */
/*        :                                                                */
/* Called By: r_dw_ucc_carton_label_102                                    */
/*          :                                                              */
/* PVCS Version: 1.5                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 23-SEP-2021 CSCHONG  1.1   Fix TTLCTN nto show (CS01)                   */
/* 17-DEC-2021 MINGLE   1.2   Add buyerpo and reportcfg to control(ML01)   */
/* 17-DEC-2021 Mingle   1.2   DevOps Combine Script                        */
/* 10-JAN-2023 Nicholas 1.3   WMS-21540 ADD in TrackingNo (NL01)           */
/* 07-APR-2023 CSCHONG  1.4   WMS-22241 add new field  (CS02)              */
/* 15-JUN-2023 Nicholas 1.5   WMS-22859 add labelno logic (NL02)           */
/* 27-SEP-2023 Nicholas 1.6   WMS-23795 add platform, add new logic (NL03) */
/***************************************************************************/
CREATE   PROC [dbo].[isp_UCC_Carton_Label_102]
   @c_StorerKey     NVARCHAR(15)
 , @c_PickSlipNo    NVARCHAR(10)
 , @c_StartCartonNo NVARCHAR(10)
 , @c_EndCartonNo   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt     INT
         , @n_Continue      INT
         , @n_Maxline       INT
         , @n_TTLCTN        INT
         , @c_showttlctn    NVARCHAR(5)
         , @c_getpickslipno NVARCHAR(20)
         , @c_getCartonno   NVARCHAR(5)


   CREATE TABLE #TMP_OD
   (
      Storerkey NVARCHAR(15) NOT NULL DEFAULT ('')
    , Sku       NVARCHAR(20) NOT NULL DEFAULT ('')
    , AltSku    NVARCHAR(20) NOT NULL DEFAULT ('')
   )

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SET @n_Maxline = 9
   SET @n_TTLCTN = 1
   SET @c_getpickslipno = N''
   SET @c_getCartonno = N''

   IF EXISTS (  SELECT 1
                FROM PackDetail WITH (NOLOCK)
                WHERE PickSlipNo = @c_PickSlipNo)
   BEGIN
      SET @c_getpickslipno = @c_PickSlipNo
   END
   ELSE
   BEGIN
      SELECT @c_getpickslipno = PickSlipNo
           , @c_getCartonno = CartonNo
      FROM PackDetail WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey AND DropID = @c_PickSlipNo

      SET @c_StartCartonNo = @c_getCartonno
      SET @c_EndCartonNo = @c_getCartonno

   END

   SELECT @n_TTLCTN = MAX(CartonNo)
   FROM PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @c_getpickslipno --CS01    
   AND   StorerKey = @c_StorerKey


   CREATE TABLE #TMP_LCartonLBL102
   (
      rowid            INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , Storerkey        NVARCHAR(20)  NULL
    , OrdExtOrdKey     NVARCHAR(50)  NULL
    , Consigneekey     NVARCHAR(45)  NULL
    , cartonno         INT           NULL
    , TTLCtn           INT           NULL
    , SKUStyle         NVARCHAR(30)  NULL
    --SKUSize          NVARCHAR(10) NULL,    
    --PDQty            INT,    
    , Facility         NVARCHAR(10)  NULL
    , TTLQTY           INT
    , loadkey          NVARCHAR(20)  NULL
    , ExternPOKey      NVARCHAR(80)  NULL --NL03
    , OHRoute          NVARCHAR(20)  NULL
    , DropID           NVARCHAR(40)  NULL --NL02    
    , ST_Address1      NVARCHAR(45)  NULL
    , ST_Address2      NVARCHAR(45)  NULL
    , ST_Address3      NVARCHAR(45)  NULL
    , ST_City          NVARCHAR(45)  NULL
    , ST_State         NVARCHAR(45)  NULL
    , ST_Zip           NVARCHAR(45)  NULL
    , RecGrp           INT
    , Pickslipno       NVARCHAR(20)  NULL
    , ST_Company       NVARCHAR(45)  NULL
    , Labelno          NVARCHAR(40)  NULL --NL02  
    , HIDETTLCTN       NVARCHAR(5)   NULL
    , SKUSize          NVARCHAR(10)  NULL
    , OHNotes          NVARCHAR(250) NULL
    , HIDEFIELD        NVARCHAR(5)   NULL
    , BuyerPO          NVARCHAR(80)  NULL --NL03
    , showPOorPOKEY    NVARCHAR(5)   NULL
    , TrackingNo       NVARCHAR(80)  NULL --NL01     
    , sstyletitle      NVARCHAR(30)  NULL --CS02  
    , sstyle           NVARCHAR(30)  NULL --CS02        
    , Sdescr           NVARCHAR(60)  NULL --CS02  
    , Sbusr1           NVARCHAR(30)  NULL --CS02  
    , showskudescbusr1 NVARCHAR(5)   NULL
    , PlatformName     NVARCHAR(60)  NULL --NL03
    , b_company        NVARCHAR(200)  NULL --NL03
   ) --CS02   

   CREATE TABLE #TMP_LCartonLBL102Date
   (
      rowid        INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , Storerkey    NVARCHAR(20) NULL
    , OrdExtOrdKey NVARCHAR(50) NULL
    , ODD_Date     DATETIME
    , OAD_Date     DATETIME
    , ODD          NVARCHAR(11)
    , OAD          NVARCHAR(11)
    , SLA          INT
   )


   INSERT INTO #TMP_LCartonLBL102 (Storerkey, OrdExtOrdKey, loadkey, OHRoute, Consigneekey, Facility, TTLQTY
                                 , ExternPOKey, ST_Address1, ST_Address2, ST_Address3, ST_City, ST_State, ST_Zip
                                 , DropID, cartonno, SKUStyle, TTLCtn, RecGrp, Pickslipno, ST_Company, Labelno
                                 , HIDETTLCTN, SKUSize, OHNotes, HIDEFIELD, BuyerPO, showPOorPOKEY, TrackingNo
                                 , sstyletitle, sstyle, Sdescr, Sbusr1, showskudescbusr1   --CS02
                                 , PlatformName, b_company) --NL03
   SELECT DISTINCT OH.StorerKey
                 , OH.ExternOrderKey
                 , OH.LoadKey
                 , OH.Route
                 , OH.ConsigneeKey
                 , OH.Facility
                 , SUM(PD.Qty)
                 , OH.ExternPOKey
                 , CASE WHEN MAX(IsNull(CLR8.short,'')) = 'Y' THEN IsNull(OH.C_Address1,'') ELSE ST.Address1 END --NL03
                 , CASE WHEN MAX(IsNull(CLR8.short,'')) = 'Y' THEN IsNull(OH.C_Address2,'') ELSE ST.Address2 END --NL03
                 , CASE WHEN MAX(IsNull(CLR8.short,'')) = 'Y' THEN IsNull(OH.C_Address3,'') ELSE ST.Address3 END --NL03
                 , CASE WHEN MAX(IsNull(CLR8.short,'')) = 'Y' THEN IsNull(OH.C_city,'') ELSE ST.City END --NL03
                 , CASE WHEN MAX(IsNull(CLR8.short,'')) = 'Y' THEN IsNull(OH.c_state,'') ELSE ST.State END --NL03
                 , CASE WHEN MAX(IsNull(CLR8.short,'')) = 'Y' THEN IsNull(OH.c_zip,'') ELSE ST.Zip END --NL03
                 , PD.DropID
                 , PD.CartonNo
                 , PD.SKU
                 , @n_TTLCTN
                 , ROW_NUMBER() OVER (PARTITION BY OH.ExternOrderKey
                                                 , PD.CartonNo
                                      ORDER BY OH.ExternOrderKey
                                             , CartonNo
                                             , PD.SKU) / @n_Maxline + 1 AS recgrp
                 , PH.PickSlipNo
                 , CASE WHEN MAX(IsNull(CLR8.short,'')) = 'Y' THEN IsNull(OH.C_company,'') ELSE ST.Company END --NL03
                 , CASE WHEN MAX(CLR6.Short) = '1' THEN MAX(OH.OrderKey)
                        WHEN MAX(CLR6.Short) = '2' THEN OH.ExternOrderKey
                        ELSE PD.LabelNo END --NL02
                 , CASE WHEN ISNULL(CLR.Code, '') <> '' THEN 'Y'
                        ELSE 'N' END AS Hidettlctn
                 , S.Size
                 , ISNULL(OH.Notes, '') AS OHNotes
                 , CASE WHEN ISNULL(CLR1.Code, '') <> '' THEN 'Y'
                        ELSE 'N' END AS HIDEFIELD
                 , OH.BuyerPO
                 , ISNULL(CLR2.Short, '') AS showPOorPOKEY
                 , CASE WHEN OH.DocType = 'E' AND MAX(CLR3.Short) = 'Y' THEN OH.TrackingNo
                        ELSE '' END --NL01   
                 , CASE WHEN MAX(CLR4.Short) = 'Y' THEN 'Style'
                        ELSE '' END AS sstyletitle --CS02  
                 , CASE WHEN MAX(CLR4.Short) = 'Y' THEN S.Style
                        ELSE '' END AS sstyle --CS02  
                 , ISNULL(S.DESCR, '')
                 , ISNULL(S.BUSR1, '')
                 , ISNULL(CLR5.Short, '0') --CS02  
                 , CASE WHEN MAX(CLR7.Short) = '1' THEN MAX(OI.Platform) --NL03
                        WHEN MAX(CLR7.Short) = '2' THEN MAX(OH.ECOM_Platform) --NL03
                   ELSE '' END --NL03
                 , OH.B_COMPANY --NL03
   FROM ORDERS OH WITH (NOLOCK)
   --JOIN ORDERDETAIL OD WITH (NOLOCK)     
   JOIN PackHeader PH WITH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey = OH.ConsigneeKey
   LEFT JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.Sku = PD.SKU
   LEFT JOIN StorerSODefault SOD WITH (NOLOCK) ON SOD.StorerKey = ST.StorerKey
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'SLABYREGION' AND C.Short = SOD.Destination
   LEFT OUTER JOIN CODELKUP CLR (NOLOCK) ON (   OH.StorerKey = CLR.Storerkey
                                            AND CLR.Code = 'HIDETTLCTN'
                                            AND CLR.LISTNAME = 'REPORTCFG'
                                            AND CLR.Long = 'r_dw_ucc_carton_label_102'
                                            AND ISNULL(CLR.Short, '') <> 'N')
   LEFT OUTER JOIN CODELKUP CLR1 (NOLOCK) ON (   OH.StorerKey = CLR1.Storerkey
                                             AND CLR1.Code = 'HIDEFIELD'
                                             AND CLR1.LISTNAME = 'REPORTCFG'
                                             AND CLR1.Long = 'r_dw_ucc_carton_label_102'
                                             AND ISNULL(CLR1.Short, '') <> 'N')
   LEFT OUTER JOIN CODELKUP CLR2 (NOLOCK) ON (   OH.StorerKey = CLR2.Storerkey
                                             AND CLR2.Code = 'showPOorPOKEY'
                                             AND CLR2.LISTNAME = 'REPORTCFG'
                                             AND CLR2.Long = 'r_dw_ucc_carton_label_102')
   LEFT OUTER JOIN CODELKUP CLR3 (NOLOCK) ON (  OH.StorerKey = CLR3.Storerkey AND CLR3.Code = 'showTrackNo' --NL01    
                                          AND   CLR3.LISTNAME = 'REPORTCFG' AND CLR3.Long = 'r_dw_ucc_carton_label_102') --NL01    
   LEFT OUTER JOIN CODELKUP CLR4 (NOLOCK) ON (  OH.StorerKey = CLR4.Storerkey AND CLR4.Code = 'SHOWSKUSTYLE' --CS02   
                                          AND   CLR4.LISTNAME = 'REPORTCFG' AND CLR4.Long = 'r_dw_ucc_carton_label_102') --CS02  
   LEFT OUTER JOIN CODELKUP CLR5 (NOLOCK) ON (   OH.StorerKey = CLR5.Storerkey
                                          AND    CLR5.Code = 'SHOWSKUDESCBUSR1' --CS02   
                                          AND    CLR5.LISTNAME = 'REPORTCFG'
                                          AND    CLR5.Long = 'r_dw_ucc_carton_label_102') --CS02  
   LEFT OUTER JOIN CODELKUP CLR6 (NOLOCK) ON (   OH.StorerKey = CLR6.Storerkey
                                          AND    CLR6.Code = 'showOrderHideLBL' --NL02   
                                          AND    CLR6.LISTNAME = 'REPORTCFG'
                                          AND    CLR6.Long = 'r_dw_ucc_carton_label_102') --NL02  
   LEFT OUTER JOIN ORDERINFO OI (NOLOCK) ON OH.ORDERKEY = OI.ORDERKEY --NL03 
   LEFT OUTER JOIN CODELKUP CLR7 (NOLOCK) ON (   OH.StorerKey = CLR7.Storerkey --NL03 
                                          AND    CLR7.Code = 'SHOWPLATFORM' --NL03   
                                          AND    CLR7.LISTNAME = 'REPORTCFG' --NL03 
                                          AND    CLR7.Long = 'r_dw_ucc_carton_label_102') --NL03  
   LEFT OUTER JOIN CODELKUP CLR8 (NOLOCK) ON (   OH.StorerKey = CLR8.Storerkey --NL03 
                                          AND    CLR8.Code = 'SHOWORDERADD' --NL03   
                                          AND    CLR8.LISTNAME = 'REPORTCFG' --NL03 
                                          AND    CLR8.Long = 'r_dw_ucc_carton_label_102') --NL03  
   WHERE PH.PickSlipNo = @c_getpickslipno
   AND   OH.StorerKey = @c_StorerKey
   AND   PD.CartonNo >= CASE WHEN @c_StartCartonNo <> '' THEN CAST(@c_StartCartonNo AS INT)
                             ELSE PD.CartonNo END
   AND   PD.CartonNo <= CASE WHEN @c_EndCartonNo <> '' THEN CAST(@c_EndCartonNo AS INT)
                             ELSE PD.CartonNo END
   GROUP BY OH.StorerKey
          , OH.ExternOrderKey
          , OH.LoadKey
          , OH.Route
          , OH.ConsigneeKey
          , OH.Facility
          , OH.ExternPOKey
          , ST.Address1
          , ST.Address2
          , ST.Address3
          , ST.City
          , ST.State
          , ST.Zip
          , PD.DropID
          , PD.CartonNo
          , PD.SKU
          , PH.PickSlipNo
          , ST.Company
          , PD.LabelNo
          , CASE WHEN ISNULL(CLR.Code, '') <> '' THEN 'Y'
                 ELSE 'N' END
          , S.Size
          , ISNULL(OH.Notes, '')
          , ISNULL(CLR1.Code, '')
          , OH.BuyerPO
          , ISNULL(CLR2.Short, '')
          , OH.DocType
          , OH.TrackingNo
          , S.Style --NL01   --CS02  
          , ISNULL(S.DESCR, '')
          , ISNULL(S.BUSR1, '')
          , ISNULL(CLR5.Short, '0') --CS02  
          , OH.B_COMPANY --NL03
          , OH.C_Address1 --NL03
          , OH.C_Address2 --NL03
          , OH.C_Address3 --NL03
          , OH.C_Address4 --NL03
          , OH.C_city --NL03
          , OH.C_state --NL03
          , OH.C_zip --NL03
          , OH.C_company --NL03
   ORDER BY PH.PickSlipNo
          , OH.ExternOrderKey
          , PD.CartonNo
          , PD.SKU

   INSERT INTO #TMP_LCartonLBL102Date (Storerkey, OrdExtOrdKey, ODD_Date, OAD_Date, ODD, OAD, SLA)
   SELECT DISTINCT OH.StorerKey
                 , OH.ExternOrderKey
                 , CASE WHEN OH.StorerKey IN ( 'Adidas' ) THEN CONVERT(DATETIME, OH.UserDefine03)
                        ELSE OH.DeliveryDate END
                 , OH.DeliveryDate
                 , ''
                 , ''
                 , CASE WHEN ISNUMERIC(C.Long) = 1 THEN CAST(C.Long AS INT)
                        ELSE 0 END
   FROM ORDERS OH WITH (NOLOCK)
   --JOIN ORDERDETAIL OD WITH (NOLOCK)     
   JOIN PackHeader PH WITH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey = OH.StorerKey
   LEFT JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.Sku = PD.SKU
   LEFT JOIN StorerSODefault SOD WITH (NOLOCK) ON SOD.StorerKey = ST.StorerKey
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'SLABYREGION' AND C.Short = SOD.Destination
   WHERE PH.PickSlipNo = @c_getpickslipno AND OH.StorerKey = @c_StorerKey


   UPDATE #TMP_LCartonLBL102Date
   SET ODD = CASE WHEN Storerkey = 'Skechers' THEN CONVERT(NVARCHAR(11), ODD_Date - SLA, 106)
                  ELSE CONVERT(NVARCHAR(11), ODD_Date, 106)END
     , OAD = CASE WHEN Storerkey IN ( 'NIKEMY', 'JDSPORTSMY', 'TBLMY' ) THEN CONVERT(NVARCHAR(11), ODD_Date + SLA, 106)
                  ELSE CONVERT(NVARCHAR(11), OAD_Date, 106)END

   QUIT_SP:

   SELECT a.loadkey
        , a.OrdExtOrdKey AS externorderkey
        , a.TTLCtn AS CtnCnt1
        , a.cartonno
        , a.DropID
        , a.SKUStyle AS style
        , a.Storerkey
        , a.TTLQTY AS sizeqty
        , a.OHRoute
        , a.Consigneekey
        , a.Facility
        , a.ExternPOKey
        , a.ST_Address1
        , a.ST_Address2
        , a.ST_Address3
        , a.ST_City
        , a.ST_State
        , a.ST_Zip
        , a.RecGrp
        , a.Pickslipno
        , REPLACE(b.ODD, ' ', '-') AS ODD
        , REPLACE(b.OAD, ' ', '-') AS OAD
        , a.ST_Company
        , a.Labelno
        , a.HIDETTLCTN AS hidettlctn
        , a.SKUSize AS skusize
        , a.OHNotes
        , a.HIDEFIELD
        , BuyerPO
        , showPOorPOKEY
        , a.TrackingNo
        , a.sstyletitle
        , a.sstyle --NL01   --CS02  
        , a.Sdescr
        , a.Sbusr1
        , a.showskudescbusr1 --CS02  
        , a.PlatformName --NL03
        , a.b_company --NL03
   FROM #TMP_LCartonLBL102 a
   JOIN #TMP_LCartonLBL102Date b ON b.Storerkey = a.Storerkey AND b.OrdExtOrdKey = a.OrdExtOrdKey
   WHERE a.Pickslipno = @c_getpickslipno
   AND   a.Storerkey = @c_StorerKey
   AND   a.cartonno >= CASE WHEN @c_StartCartonNo <> '' THEN CAST(@c_StartCartonNo AS INT)
                            ELSE a.cartonno END
   AND   a.cartonno <= CASE WHEN @c_EndCartonNo <> '' THEN CAST(@c_EndCartonNo AS INT)
                            ELSE a.cartonno END
   ORDER BY a.Pickslipno
          , a.OrdExtOrdKey
          , a.cartonno
          , a.SKUStyle

   IF OBJECT_ID('tempdb..#TMP_LCartonLBL102') IS NOT NULL
      DROP TABLE #TMP_LCartonLBL102

   IF OBJECT_ID('tempdb..#TMP_LCartonLBL102Date') IS NOT NULL
      DROP TABLE #TMP_LCartonLBL102Date

   IF OBJECT_ID('tempdb..#TMP_OD') IS NOT NULL
      DROP TABLE #TMP_OD --NL01    


END -- procedure    

GO