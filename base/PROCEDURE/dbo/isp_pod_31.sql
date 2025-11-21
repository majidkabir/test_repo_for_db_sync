SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_POD_31                                              */
/* Creation Date: 02-Aug-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: MINGLE                                                   */
/*                                                                      */
/* Purpose: WMS-20369 - [CN] NIKESDC B2B POD CR                         */
/*        :                                                             */
/* Called By: r_dw_pod_31 (reporttype = 'NIKEPODRPT')                   */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 02-Aug-2022  MINGLE    1.0 WMS-20369 - DevOps Combine Script         */
/* 05-Feb-2023  WLChooi   1.1 WMS-21686 - Modify logic (WL01)           */
/************************************************************************/
CREATE   PROC [dbo].[isp_POD_31] @c_MBOLKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt      INT
         , @n_Continue       INT
         , @c_getmbolkey     NVARCHAR(20)
         , @c_GetLoadkey     NVARCHAR(1000) --WL01
         , @c_GetPrevLoadkey NVARCHAR(1000) --WL01
         , @c_GetNotes       NVARCHAR(1000) --WL01

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TMP_POD
   (
      RowRef       INT          IDENTITY(1, 1)
    , MBOLKey      NVARCHAR(10) NULL DEFAULT ('')
    , Orderkey     NVARCHAR(10) NULL DEFAULT ('')
    , LoadKey      NVARCHAR(10) NULL DEFAULT ('')
    , Consigneekey NVARCHAR(15) NULL DEFAULT ('')
    , PickSlipNo   NVARCHAR(10) NULL DEFAULT ('')
    , CRD          NVARCHAR(30) NULL DEFAULT ('')
   )

   CREATE TABLE #TMP_PODRPT
   (
      MBOLKey        NVARCHAR(10)   NULL DEFAULT ('')
    , Facility       NVARCHAR(5)    NULL DEFAULT ('')
    , MBOLShipDate   DATETIME       NULL
    , EstArrivalDate DATETIME       NULL
    , Address1       NVARCHAR(45)   NULL DEFAULT ('')
    , Address2       NVARCHAR(45)   NULL DEFAULT ('')
    , Address3       NVARCHAR(45)   NULL DEFAULT ('')
    , Address4       NVARCHAR(45)   NULL DEFAULT ('')
    , Contact1       NVARCHAR(30)   NULL DEFAULT ('')
    , Phone1         NVARCHAR(18)   NULL DEFAULT ('')
    , Fax1           NVARCHAR(18)   NULL DEFAULT ('')
    , Loadkey        NVARCHAR(500)  NULL DEFAULT ('')
    , PickSlipNo     NVARCHAR(1000) NULL DEFAULT ('')
    , Storerkey      NVARCHAR(15)   NULL DEFAULT ('')
    , Consigneekey   NVARCHAR(15)   NULL DEFAULT ('')
    , C_Company      NVARCHAR(45)   NULL DEFAULT ('')
    , C_Address1     NVARCHAR(45)   NULL DEFAULT ('')
    , C_Address2     NVARCHAR(45)   NULL DEFAULT ('')
    , C_Address3     NVARCHAR(45)   NULL DEFAULT ('')
    , C_Address4     NVARCHAR(45)   NULL DEFAULT ('')
    , C_City         NVARCHAR(45)   NULL DEFAULT ('')
    , C_Contact1     NVARCHAR(30)   NULL DEFAULT ('')
    , C_Phone1       NVARCHAR(18)   NULL DEFAULT ('')
    , FWQty          INT            NULL DEFAULT (0)
    , APPQty         INT            NULL DEFAULT (0)
    , EQQty          INT            NULL DEFAULT (0)
    , NoOfCarton     INT            NULL DEFAULT (0)
    , CRD            NVARCHAR(30)   NULL DEFAULT ('')
    , POD_Barcode    NVARCHAR(30)   NULL DEFAULT ('')
    , FWCtn          INT            NULL DEFAULT (0)
    , APPCtn         INT            NULL DEFAULT (0)
    , EQCtn          INT            NULL DEFAULT (0)
    --,  DELDate        NVARCHAR(30)   NULL  DEFAULT('')      
    , DELDate        NVARCHAR(30)   NULL DEFAULT ('')
    , ODNotes        NVARCHAR(500)  NULL DEFAULT ('')
    , LabelNo        NVARCHAR(20)   NULL DEFAULT (0)
    , PDQTY          INT            NULL DEFAULT (0)
   )

   INSERT INTO #TMP_POD (MBOLKey, Orderkey, LoadKey, Consigneekey, PickSlipNo, CRD)
   SELECT OH.MBOLKey
        , OH.OrderKey
        , OH.LoadKey
        , OH.ConsigneeKey
        , PH.PickSlipNo
        --,  format(ISNULL(RTRIM(OH.DeliveryDate),''),'yyyy-mm-dd') AS deliverydate      
        , REPLACE(CONVERT(VARCHAR, OH.DeliveryDate, 111), '/', '-')
   FROM ORDERS OH WITH (NOLOCK)
   JOIN PackHeader PH WITH (NOLOCK) ON (OH.OrderKey = PH.OrderKey)
   LEFT JOIN OrderInfo OIF WITH (NOLOCK) ON (OH.OrderKey = OIF.OrderKey)
   WHERE OH.MBOLKey = @c_MBOLKey AND PH.OrderKey <> ''
   UNION ALL
   SELECT OH.MBOLKey
        , OH.OrderKey
        , OH.LoadKey
        , OH.ConsigneeKey
        , PH.PickSlipNo
        , REPLACE(CONVERT(VARCHAR, OH.DeliveryDate, 111), '/', '-')
   FROM ORDERS OH WITH (NOLOCK)
   JOIN LoadPlanDetail LD WITH (NOLOCK) ON OH.OrderKey = LD.OrderKey
   JOIN PackHeader PH WITH (NOLOCK) ON (LD.LoadKey = PH.LoadKey)
   LEFT JOIN OrderInfo OIF WITH (NOLOCK) ON (OH.OrderKey = OIF.OrderKey)
   WHERE OH.MBOLKey = @c_MBOLKey AND PH.OrderKey = '' AND PH.LoadKey <> ''

   INSERT INTO #TMP_PODRPT (MBOLKey, Facility, MBOLShipDate, EstArrivalDate, Address1, Address2, Address3, Address4
                          , Contact1, Phone1, Fax1, Loadkey, PickSlipNo, Storerkey, Consigneekey, C_Company, C_Address1
                          , C_Address2, C_Address3, C_Address4, C_City, C_Contact1, C_Phone1, FWQty, APPQty, EQQty
                          , NoOfCarton, CRD, POD_Barcode, FWCtn, APPCtn, EQCtn, DELDate, ODNotes, LabelNo, PDQTY)
   SELECT TMP.MBOLKey
        , MH.Facility
        , MH.EditDate
        , MH.EditDate
        , Address1 = ISNULL(RTRIM(FC.Address1), '')
        , Address2 = ISNULL(RTRIM(FC.Address2), '')
        , Address3 = ISNULL(RTRIM(FC.Address3), '')
        , Address4 = ISNULL(RTRIM(FC.Address4), '')
        , Contact1 = ISNULL(RTRIM(FC.Contact1), '')
        , Phone1 = ISNULL(RTRIM(FC.Phone1), '')
        , Fax1 = ISNULL(RTRIM(FC.Fax1), '')
        , Loadkey = ISNULL(
                       STUFF(
                       (  SELECT DISTINCT '/' + TPOD.LoadKey
                          FROM #TMP_POD TPOD WITH (NOLOCK)
                          WHERE TPOD.MBOLKey = TMP.MBOLKey
                          AND   TPOD.Consigneekey = TMP.Consigneekey
                          AND   TPOD.CRD = TMP.CRD
                          FOR XML PATH(''))
                     , 1
                     , 1
                     , '')
                     , '')
        , PickSlipno = ISNULL(
                          STUFF(
                          (  SELECT DISTINCT '/ ' + TPOD.PickSlipNo
                             FROM #TMP_POD TPOD WITH (NOLOCK)
                             WHERE TPOD.MBOLKey = TMP.MBOLKey
                             AND   TPOD.Consigneekey = TMP.Consigneekey
                             AND   TPOD.CRD = TMP.CRD
                             FOR XML PATH(''))
                        , 1
                        , 2
                        , '')
                        , '')
        , OH.StorerKey
        , TMP.Consigneekey
        , C_Company = ISNULL(MAX(RTRIM(OH.C_Company)), '')
        , C_Address1 = ISNULL(MAX(RTRIM(OH.C_Address1)), '')
        , C_Address2 = ISNULL(MAX(RTRIM(OH.C_Address2)), '')
        , C_Address3 = ISNULL(MAX(RTRIM(OH.C_Address3)), '')
        , C_Address4 = ISNULL(MAX(RTRIM(OH.C_Address4)), '')
        , C_City = ISNULL(MAX(RTRIM(OH.C_City)), '')
        , C_Contact1 = ISNULL(MAX(RTRIM(OH.C_contact1)), '')
        , C_Phone1 = ISNULL(MAX(RTRIM(OH.C_Phone1)), '')
        , FWQty = 0 --SUM(CASE WHEN ISNULL(RTRIM(SKU.BUSR7), '') = '20' THEN PD.Qty    --WL01
        --ELSE 0 END)                                                                  --WL01
        , APPQty = 0 --SUM(CASE WHEN ISNULL(RTRIM(SKU.BUSR7), '') = '10' THEN PD.Qty   --WL01
        --ELSE 0 END)                                                                  --WL01
        , EQQty = 0 --SUM(CASE WHEN ISNULL(RTRIM(SKU.BUSR7), '') = '30' THEN PD.Qty    --WL01
        --ELSE 0 END)                                                                  --WL01
        , NoOfCarton = COUNT(DISTINCT PD.CaseID)
        --,CRD         = (SELECT ISNULL(MAX(RTRIM(ORDERINFO.OrderInfo07)),'')      
        --                FROM ORDERS     WITH (NOLOCK)      
        --                JOIN ORDERINFO  WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERINFO.Orderkey)      
        --                WHERE ORDERS.MBOLkey = MH.MBOLKey      
        --                AND   ORDERS.Consigneekey = OH.Consigneekey      
        --                )      
        , CRD = TMP.CRD
        , POD_Barcode = CASE WHEN ISNULL(CL.Short, '') = 'Y' THEN RTRIM(TMP.MBOLKey)
                             ELSE 'POD-' + RTRIM(TMP.MBOLKey)END
        , '0' --FWCtn       = CASE WHEN ISNULL(RTRIM(SKU.BUSR7),'') = '20' THEN COUNT(DISTINCT PD.CaseID) ELSE 0 END      
        , '0' --APPCtn      = CASE WHEN ISNULL(RTRIM(SKU.BUSR7),'') = '10' THEN COUNT(DISTINCT PD.CaseID) ELSE 0 END      
        , '0' --EQCtn       = CASE WHEN ISNULL(RTRIM(SKU.BUSR7),'') = '30' THEN COUNT(DISTINCT PD.CaseID) ELSE 0 END      
        --,DELDate = MAX(ISNULL(OH.DeliveryDate,''))  
        --,DELDate = (CONVERT(VARCHAR(20), OH.DeliveryDate, 23) + ' ' + LEFT(CONVERT(VARCHAR(20),OH.DeliveryDate, 108) ,5))  
        , DELDate = (CONVERT(VARCHAR(20), MAX(ISNULL(OH.DeliveryDate, '')), 23) + ' '
                     + LEFT(CONVERT(VARCHAR(20), MAX(ISNULL(OH.DeliveryDate, '')), 108), 5))
        , ISNULL(OD.Notes, '')
        , 0 --COUNT(DISTINCT PAD.LabelNo) --LabelNo   --WL01 
        , 0 --PDQTY = ISNULL(SUM(PAD.Qty), '0')       --WL01
   --exec isp_POD_31 '0000769030'  
   FROM MBOL MH WITH (NOLOCK)
   JOIN MBOLDETAIL MD WITH (NOLOCK) ON (MH.MbolKey = MD.MbolKey)
   JOIN ORDERS OH WITH (NOLOCK) ON (MD.OrderKey = OH.OrderKey)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (   OD.OrderKey = PD.OrderKey
                                        AND OD.StorerKey = PD.Storerkey
                                        AND OD.OrderLineNumber = PD.OrderLineNumber) --ML01  
   --JOIN PackDetail PAD WITH (NOLOCK) ON PAD.LabelNo = PD.CaseID AND PAD.SKU = PD.Sku AND PAD.StorerKey = PD.Storerkey   --WL01
   JOIN SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.Storerkey) AND (SKU.Sku = PD.Sku)
   JOIN FACILITY FC WITH (NOLOCK) ON (MH.Facility = FC.Facility)
   JOIN #TMP_POD TMP WITH (NOLOCK) ON (OH.OrderKey = TMP.Orderkey)
   LEFT JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'REPORTCFG'
                                  AND CL.Storerkey = OH.StorerKey
                                  AND CL.Code = 'RemovePODfrPODBarcode'
                                  AND CL.Long = 'r_dw_pod_31'
   WHERE MH.MbolKey = @c_MBOLKey
   GROUP BY TMP.MBOLKey
          , MH.Facility
          , MH.EditDate
          , ISNULL(RTRIM(FC.Address1), '')
          , ISNULL(RTRIM(FC.Address2), '')
          , ISNULL(RTRIM(FC.Address3), '')
          , ISNULL(RTRIM(FC.Address4), '')
          , ISNULL(RTRIM(FC.Contact1), '')
          , ISNULL(RTRIM(FC.Phone1), '')
          , ISNULL(RTRIM(FC.Fax1), '')
          , OH.StorerKey
          , TMP.Consigneekey
          , TMP.CRD
          --,ISNULL(RTRIM(SKU.BUSR7),'')            
          , ISNULL(CL.Short, '')
          , ISNULL(OD.Notes, '')
   --,  PAD.LabelNo  
   --,  OH.DeliveryDate  
   ORDER BY TMP.Consigneekey
          , TMP.CRD

   UPDATE TMP
   SET EstArrivalDate = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN DATEADD(dd, CONVERT(INT, CL.Short), MBOLShipDate)
                             ELSE MBOLShipDate END
   FROM #TMP_PODRPT TMP
   JOIN CODELKUP CL WITH (NOLOCK) ON  (CL.LISTNAME = 'CityLdTime')
                                  AND (CL.Storerkey = TMP.Storerkey)
                                  AND (CL.Long = TMP.Facility)
                                  AND (CL.Description = TMP.C_City)


   DECLARE C_loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT MBOLKey
        , Loadkey --PickSlipNo   --WL01
        , ODNotes --WL01
   FROM #TMP_PODRPT
   WHERE MBOLKey = @c_MBOLKey

   OPEN C_loop
   FETCH NEXT FROM C_loop
   INTO @c_getmbolkey
      , @c_GetLoadkey --WL01
      , @c_GetNotes --WL01

   WHILE (@@FETCH_STATUS = 0)
   BEGIN
      --WL01 S
      --UPDATE #TMP_PODRPT
      --SET FWCtn = ISNULL(
      --            (  SELECT COUNT(DISTINCT PD.CaseID)
      --               FROM MBOL MH WITH (NOLOCK)
      --               JOIN MBOLDETAIL MD WITH (NOLOCK) ON (MH.MbolKey = MD.MbolKey)
      --               JOIN ORDERS OH WITH (NOLOCK) ON (MD.OrderKey = OH.OrderKey)
      --               JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
      --               JOIN SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.Storerkey) AND (SKU.Sku = PD.Sku)
      --               JOIN FACILITY FC WITH (NOLOCK) ON (MH.Facility = FC.Facility)
      --               --JOIN #TMP_POD   TMP WITH (NOLOCK) ON (OH.Orderkey = TMP.Orderkey)      
      --               WHERE MH.MbolKey = @c_MBOLKey
      --               AND   ISNULL(RTRIM(SKU.BUSR7), '') = '20'
      --               AND   PD.PickSlipNo IN (  SELECT RTRIM(LTRIM(ColValue))
      --                                         FROM dbo.fnc_DelimSplit('/', @c_getPickslipno) ))
      --          , 0)
      --  , APPCtn = ISNULL(
      --             (  SELECT COUNT(DISTINCT PD.CaseID)
      --                FROM MBOL MH WITH (NOLOCK)
      --                JOIN MBOLDETAIL MD WITH (NOLOCK) ON (MH.MbolKey = MD.MbolKey)
      --                JOIN ORDERS OH WITH (NOLOCK) ON (MD.OrderKey = OH.OrderKey)
      --                JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
      --                JOIN SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.Storerkey) AND (SKU.Sku = PD.Sku)
      --                JOIN FACILITY FC WITH (NOLOCK) ON (MH.Facility = FC.Facility)
      --                --JOIN #TMP_POD   TMP WITH (NOLOCK) ON (OH.Orderkey = TMP.Orderkey)      
      --                WHERE MH.MbolKey = @c_MBOLKey
      --                AND   ISNULL(RTRIM(SKU.BUSR7), '') = '10'
      --                AND   PD.PickSlipNo IN (  SELECT RTRIM(LTRIM(ColValue))
      --                                          FROM dbo.fnc_DelimSplit('/', @c_getPickslipno) )
      --                GROUP BY ISNULL(RTRIM(SKU.BUSR7), ''))
      --           , 0)
      --  , EQCtn = ISNULL(
      --            (  SELECT COUNT(DISTINCT PD.CaseID)
      --               FROM MBOL MH WITH (NOLOCK)
      --               JOIN MBOLDETAIL MD WITH (NOLOCK) ON (MH.MbolKey = MD.MbolKey)
      --               JOIN ORDERS OH WITH (NOLOCK) ON (MD.OrderKey = OH.OrderKey)
      --               JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
      --               JOIN SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.Storerkey) AND (SKU.Sku = PD.Sku)
      --               JOIN FACILITY FC WITH (NOLOCK) ON (MH.Facility = FC.Facility)
      --               --JOIN #TMP_POD   TMP WITH (NOLOCK) ON (OH.Orderkey = TMP.Orderkey)      
      --               WHERE MH.MbolKey = @c_MBOLKey
      --               AND   ISNULL(RTRIM(SKU.BUSR7), '') = '30'
      --               AND   PD.PickSlipNo IN (  SELECT RTRIM(LTRIM(ColValue))
      --                                         FROM dbo.fnc_DelimSplit('/', @c_getPickslipno) )
      --               GROUP BY ISNULL(RTRIM(SKU.BUSR7), ''))
      --          , 0)

      --LabelNo = ISNULL((SELECT COUNT(DISTINCT PAD.LabelNo)                                                                         
      --          FROM MBOL       MH  WITH (NOLOCK)      
      --          JOIN MBOLDETAIL MD  WITH (NOLOCK) ON (MH.MBOLKey  = MD.MBOLKey)      
      --          JOIN ORDERS     OH  WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)   
      --          JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)  
      -- JOIN PACKDETAIL PAD WITH (NOLOCK) ON PAD.PickSlipNo = PD.PickSlipNo  
      --          JOIN SKU        SKU WITH (NOLOCK) ON (SKU.Storerkey = PD.Storerkey)      
      --           AND(SKU.Sku = PD.Sku)      
      --          JOIN FACILITY   FC  WITH (NOLOCK) ON (MH.Facility = FC.Facility)      
      --          --JOIN #TMP_POD   TMP WITH (NOLOCK) ON (OH.Orderkey = TMP.Orderkey)      
      --          WHERE MH.MBOLKey = @c_MBOLKey      
      --        AND PD.pickslipno IN ( SELECT RTRIM(LTRIM(Colvalue)) FROM dbo.fnc_DelimSplit('/',@c_getpickslipno) )    
      --  GROUP BY ISNULL(RTRIM(SKU.BUSR7),'')),0)  



      --WHERE MBOLKey = @c_getmbolkey AND PickSlipNo = @c_getPickslipno

      ;WITH FW (Loadkey, FWCtn, FWQty, ODNotes) AS
       (
          SELECT @c_GetLoadkey
               , COUNT(DISTINCT PD.CaseID)
               , SUM(PD.Qty)
               , @c_GetNotes
          FROM ORDERS OH WITH (NOLOCK)
          JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
          JOIN SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.Storerkey) AND (SKU.Sku = PD.Sku)
          JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = OH.OrderKey)
          JOIN ORDERDETAIL OD WITH (NOLOCK) ON  (OD.OrderKey = OH.OrderKey)
                                            AND (OD.Sku = PD.Sku)
                                            AND (OD.StorerKey = PD.Storerkey)
                                            AND (OD.OrderLineNumber = PD.OrderLineNumber)
          WHERE OH.MBOLKey = @c_MBOLKey
          AND   ISNULL(RTRIM(SKU.BUSR7), '') = '20'
          AND   LPD.LoadKey IN (  SELECT RTRIM(LTRIM(ColValue))
                                  FROM dbo.fnc_DelimSplit('/', @c_GetLoadkey) )
          AND   OD.Notes = @c_GetNotes
       )
      UPDATE #TMP_PODRPT
      SET #TMP_PODRPT.FWCtn = ISNULL(FW.FWCtn, 0)
        , #TMP_PODRPT.FWQty = ISNULL(FW.FWQty, 0)
      FROM FW
      JOIN #TMP_PODRPT ON #TMP_PODRPT.Loadkey = FW.Loadkey AND #TMP_PODRPT.ODNotes = FW.ODNotes;

      WITH APP (Loadkey, APPCtn, APPQty, ODNotes) AS
      (
         SELECT @c_GetLoadkey
              , COUNT(DISTINCT PD.CaseID)
              , SUM(PD.Qty)
              , @c_GetNotes
         FROM ORDERS OH WITH (NOLOCK)
         JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
         JOIN SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.Storerkey) AND (SKU.Sku = PD.Sku)
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = OH.OrderKey)
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON  (OD.OrderKey = OH.OrderKey)
                                           AND (OD.Sku = PD.Sku)
                                           AND (OD.StorerKey = PD.Storerkey)
                                           AND (OD.OrderLineNumber = PD.OrderLineNumber)
         WHERE OH.MBOLKey = @c_MBOLKey
         AND   ISNULL(RTRIM(SKU.BUSR7), '') = '10'
         AND   LPD.LoadKey IN (  SELECT RTRIM(LTRIM(ColValue))
                                 FROM dbo.fnc_DelimSplit('/', @c_GetLoadkey) )
         AND   OD.Notes = @c_GetNotes
      )
      UPDATE #TMP_PODRPT
      SET #TMP_PODRPT.APPCtn = ISNULL(APP.APPCtn, 0)
        , #TMP_PODRPT.APPQty = ISNULL(APP.APPQty, 0)
      FROM APP
      JOIN #TMP_PODRPT ON #TMP_PODRPT.Loadkey = APP.Loadkey AND #TMP_PODRPT.ODNotes = APP.ODNotes;

      WITH EQ (Loadkey, EQCtn, EQQty, ODNotes) AS
      (
         SELECT @c_GetLoadkey
              , COUNT(DISTINCT PD.CaseID)
              , SUM(PD.Qty)
              , @c_GetNotes
         FROM ORDERS OH WITH (NOLOCK)
         JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
         JOIN SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.Storerkey) AND (SKU.Sku = PD.Sku)
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = OH.OrderKey)
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON  (OD.OrderKey = OH.OrderKey)
                                           AND (OD.Sku = PD.Sku)
                                           AND (OD.StorerKey = PD.Storerkey)
                                           AND (OD.OrderLineNumber = PD.OrderLineNumber)
         WHERE OH.MBOLKey = @c_MBOLKey
         AND   ISNULL(RTRIM(SKU.BUSR7), '') = '30'
         AND   LPD.LoadKey IN (  SELECT RTRIM(LTRIM(ColValue))
                                 FROM dbo.fnc_DelimSplit('/', @c_GetLoadkey) )
         AND   OD.Notes = @c_GetNotes
      )
      UPDATE #TMP_PODRPT
      SET #TMP_PODRPT.EQCtn = ISNULL(EQ.EQCtn, 0)
        , #TMP_PODRPT.EQQty = ISNULL(EQ.EQQty, 0)
      FROM EQ
      JOIN #TMP_PODRPT ON #TMP_PODRPT.Loadkey = EQ.Loadkey AND #TMP_PODRPT.ODNotes = EQ.ODNotes;
      WITH CTE (ODNotes, LabelNo, PDQty, Loadkey) AS
      (
         SELECT OD.Notes
              , COUNT(DISTINCT PD.CaseID)
              , SUM(PD.Qty)
              , @c_GetLoadkey
         FROM ORDERS OH WITH (NOLOCK)
         JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = OH.OrderKey)
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON  (OD.OrderKey = OH.OrderKey)
                                           AND (OD.Sku = PD.Sku)
                                           AND (OD.StorerKey = PD.Storerkey)
                                           AND (OD.OrderLineNumber = PD.OrderLineNumber)
         WHERE OH.MBOLKey = @c_MBOLKey
         AND   LPD.LoadKey IN (  SELECT RTRIM(LTRIM(ColValue))
                                 FROM dbo.fnc_DelimSplit('/', @c_GetLoadkey) )
         AND   OD.Notes = @c_GetNotes
         GROUP BY OD.Notes
      )
      UPDATE #TMP_PODRPT
      SET #TMP_PODRPT.LabelNo = ISNULL(CTE.LabelNo, 0)
        , #TMP_PODRPT.PDQTY = ISNULL(CTE.PDQty, 0)
      FROM CTE
      JOIN #TMP_PODRPT ON #TMP_PODRPT.ODNotes = CTE.ODNotes AND #TMP_PODRPT.Loadkey = CTE.Loadkey
      --WL01 E

      FETCH NEXT FROM C_loop
      INTO @c_getmbolkey
         , @c_GetLoadkey --WL01
         , @c_GetNotes --WL01
   END

   CLOSE C_loop
   DEALLOCATE C_loop;

   --WL01 S
   WITH SUMBUSR7 (SumFWCtn, SumAppCtn, SumEQCtn, Loadkey) AS
   (
      SELECT SUM(ISNULL(FWCtn, 0))
           , SUM(ISNULL(APPCtn, 0))
           , SUM(ISNULL(EQCtn, 0))
           , Loadkey
      FROM #TMP_PODRPT
      GROUP BY Loadkey
   )
   UPDATE #TMP_PODRPT
   SET #TMP_PODRPT.FWCtn = SUMBUSR7.SumFWCtn
     , #TMP_PODRPT.APPCtn = SUMBUSR7.SumAppCtn
     , #TMP_PODRPT.EQCtn = SUMBUSR7.SumEQCtn
   FROM SUMBUSR7
   JOIN #TMP_PODRPT ON #TMP_PODRPT.Loadkey = SUMBUSR7.Loadkey
   --WL01 E

   SELECT MBOLKey
        , Facility
        , MBOLShipDate
        , EstArrivalDate
        , Address1
        , Address2
        , Address3
        , Address4
        , Contact1
        , Phone1
        , Fax1
        , Loadkey
        , PickSlipNo
        , Storerkey
        , Consigneekey
        , C_Company
        , C_Address1
        , C_Address2
        , C_Address3
        , C_Address4
        , C_City
        , C_Contact1
        , C_Phone1
        , FWQty
        , APPQty
        , EQQty
        , NoOfCarton
        , CRD
        , POD_Barcode
        , FWCtn
        , APPCtn
        , EQCtn
        , DELDate
        , ODNotes
        , LabelNo
        , PDQTY
   FROM #TMP_PODRPT

   --WL01 S
   IF OBJECT_ID('tempdb..#TMP_PODRPT') IS NOT NULL
      DROP TABLE #TMP_PODRPT

   IF (SELECT CURSOR_STATUS('LOCAL', 'C_loop')) >= 0
   BEGIN
      CLOSE C_loop
      DEALLOCATE C_loop
   END
   --WL01 E

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure   

GO