SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_OrderReview                                     */  
/* Creation Date: 18-APR-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#238875: Open/WIP Orders Report/View                      */  
/*                                                                       */  
/* Called By: Call from Shipment Orders Review - d_dw_orders_review_grid */
/*                      Report 'IDSUS008'- r_dw_orders_review            */  
/*                      Report 'IDSUS009'- r_dw_orders_review_fsr        */ 
/*                      Report 'IDSUS010'- r_dw_orders_review_oor        */ 
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/*************************************************************************/  

CREATE PROC [dbo].[isp_OrderReview]
      @c_Storerkey      NVARCHAR(15)
   ,  @c_Facility       NVARCHAR(5)
   ,  @c_ExternOrderkey NVARCHAR(50)  --tlting_ext
   ,  @c_BuyerPO        NVARCHAR(20)
   ,  @c_LoadKey        NVARCHAR(10)
   ,  @c_MBOLKey        NVARCHAR(10) 
   ,  @c_Dept           NVARCHAR(20)
   ,  @c_Status         NVARCHAR(10)
   ,  @dt_ShippedDate   DATETIME 
   ,  @dt_PickUpDate    DATETIME
   ,  @dt_StartDateFr   DATETIME
   ,  @dt_StartDateTo   DATETIME
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   CREATE TABLE #TEMP_ORD (
        Orderkey           NVARCHAR(10)    NULL DEFAULT('')
      , Storerkey          NVARCHAR(15)NULL DEFAULT('')
      , OriginalQty        FLOAT       NULL DEFAULT(0)
      , QtyAllocated       FLOAT       NULL DEFAULT(0)
      , QtyPicked          FLOAT       NULL DEFAULT(0) 
      , ShippedQty         FLOAT       NULL DEFAULT(0) 
      , QtyPIP             FLOAT       NULL DEFAULT(0) 
                              )
   CREATE INDEX IDX_ORD_Orderkey ON #TEMP_ORD (Orderkey)

   CREATE TABLE #TEMP_PACKINFO (
        Orderkey           NVARCHAR(10)    NULL DEFAULT('')
--      , Loadkey            NVARCHAR(10) NULL DEFAULT('')
--      , MBOLkey            NVARCHAR(10) NULL DEFAULT('')
      , NoOfPickTicket     INT         NULL DEFAULT(0)
      , NoOfLabel          INT         NULL DEFAULT(0) 
      , PackedQty          INT         NULL DEFAULT(0)
                              )
   CREATE INDEX IDX_PACKINFO_Orderkey ON #TEMP_PACKINFO (Orderkey)

   CREATE TABLE #TEMP_ORDPACK (
        Orderkey           NVARCHAR(10)NULL DEFAULT('')
      , QtyLabelled        FLOAT       NULL DEFAULT(0)
      , QtyPalletized      FLOAT       NULL DEFAULT(0)
      , QtyOnStaged        FLOAT       NULL DEFAULT(0) 
      , QtyLoaded          FLOAT       NULL DEFAULT(0)
                              )
   CREATE INDEX IDX_PACK_Orderkey ON #TEMP_ORDPACK (Orderkey)

   
   CREATE TABLE #TEMP_ORDPICK (
        Orderkey           NVARCHAR(10)NULL DEFAULT('')
      , PickCnt            INT         NULL DEFAULT(0)
      , PickLoose          INT         NULL DEFAULT(0) 
                              )
   CREATE INDEX IDX_PICK_Orderkey ON #TEMP_ORDPICK (Orderkey)

   CREATE TABLE #TEMP_PREPACK (
        Orderkey           NVARCHAR(10)    NULL DEFAULT('')
      , Storerkey          NVARCHAR(15)NULL DEFAULT('')
      , Sku                NVARCHAR(20)NULL DEFAULT('') 
      , BOMQty             INT         NULL DEFAULT(0)
      , BOMCaseCnt         INT         NULL DEFAULT(0) 
                              ) 
   CREATE INDEX IDX_PREPACK_Orderkey ON #TEMP_PREPACK (Orderkey, Storerkey, Sku)

   IF @dt_ShippedDate IS NULL SET @dt_ShippedDate = CONVERT(DATETIME,'19000101')
   IF @dt_PickupDate  IS NULL SET @dt_PickupDate  = CONVERT(DATETIME,'19000101')
   IF @dt_StartDateFr IS NULL SET @dt_StartDateFr = CONVERT(DATETIME,'19000101')
   IF @dt_StartDateTo IS NULL SET @dt_StartDateTo = CONVERT(DATETIME,'19000101')
   IF ISNULL(RTRIM(@c_Status),'') = '' SET @c_Status = 'ALL'
   
   INSERT INTO #TEMP_ORD (Orderkey, Storerkey, OriginalQty, QtyAllocated, QtyPicked, ShippedQty, QtyPIP)
   SELECT ISNULL(RTRIM(OH.Orderkey),'')   'Orderkey'
         ,ISNULL(RTRIM(OH.Storerkey),'')  'Storerkey'
         ,SUM(OD.OriginalQty)             'OriginalQty'                    
         ,SUM(OD.QtyAllocated)            'QtyAllocated'             
         ,SUM(OD.QtyPicked)               'QtyPicked'                         
         ,SUM(OD.QtyAllocated + OD.QtyPicked  + OD.ShippedQty) 'ShippedQty'
         ,SUM(CASE LP.Status WHEN '3' THEN OD.QtyPicked ELSE 0 END) 'QtyPIP'
   FROM dbo.ORDERS         OH WITH (NOLOCK)
   JOIN dbo.ORDERDETAIL    OD WITH (NOLOCK) ON (OH.Orderkey=OD.Orderkey) 
   LEFT JOIN dbo.LOADPLAN  LP WITH (NOLOCK) ON (OH.Loadkey=LP.Loadkey)
   LEFT JOIN dbo.MBOL      MB WITH (NOLOCK) ON (OH.MbolKey=MB.MBOLKey)
   WHERE OH.Storerkey = CASE WHEN ISNULL(RTRIM(@c_Storerkey),'') IN ('', 'ALL') THEN OH.Storerkey ELSE @c_Storerkey END
   AND   OH.Facility  = CASE WHEN ISNULL(RTRIM(@c_Facility),'')  IN ('', 'ALL') THEN OH.Facility ELSE @c_Facility END
   AND   ISNULL(RTRIM(OH.Loadkey),'')         = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'') IN ('', 'ALL') 
                                                     THEN ISNULL(RTRIM(OH.Loadkey),'') ELSE @c_LoadKey END
   AND   ISNULL(RTRIM(OH.MBOLKey),'')         = CASE WHEN ISNULL(RTRIM(@c_MBOLKey),'') IN ('', 'ALL') 
                                                     THEN ISNULL(RTRIM(OH.MBOLKey),'') ELSE @c_MBOLKey END
   AND   ISNULL(RTRIM(OH.ExternOrderkey),'')  = CASE WHEN ISNULL(RTRIM(@c_ExternOrderkey),'') = '' 
                                                     THEN ISNULL(RTRIM(OH.ExternOrderkey),'') ELSE @c_ExternOrderkey END
   AND   ISNULL(RTRIM(OH.BuyerPO),'')         = CASE WHEN ISNULL(RTRIM(@c_BuyerPO),'') = '' 
                                                     THEN ISNULL(RTRIM(OH.BuyerPO),'') ELSE @c_BuyerPO END
   AND   ISNULL(RTRIM(OH.UserDefine03),'')    = CASE WHEN ISNULL(RTRIM(@c_Dept),'') = '' 
                                                     THEN ISNULL(RTRIM(OH.UserDefine03),'') ELSE @c_Dept END
   AND   OH.Status < ISNULL(RTRIM(@c_Status),' ')
   AND   CONVERT(NVARCHAR(8),OH.EditDate,112)  = CASE WHEN CONVERT(CHAR(8),@dt_ShippedDate,112) = '19000101' 
                                                     THEN CONVERT(CHAR(8),OH.EditDate,112) 
                                                     ELSE CONVERT(CHAR(8),@dt_ShippedDate,112) END
   AND   CONVERT(NVARCHAR(8),ISNULL(MB.UserDefine07,'19000101'),112) 
                                              = CASE WHEN CONVERT(CHAR(8),@dt_PickupDate,112) = '19000101' 
                                                     THEN CONVERT(CHAR(8),ISNULL(MB.UserDefine07,'19000101'),112) 
                                                     ELSE CONVERT(CHAR(8),@dt_PickupDate,112) END
   AND   CONVERT(NVARCHAR(8),ISNULL(OH.OrderDate,'19000101'),112) 
                                              >=CASE WHEN CONVERT(CHAR(8),@dt_StartDateFr,112) = '19000101' 
                                                     THEN CONVERT(CHAR(8),ISNULL(OH.OrderDate,'19000101'),112) 
                                                     ELSE CONVERT(CHAR(8),@dt_StartDateFr,112) END
   AND   CONVERT(NVARCHAR(8),ISNULL(OH.OrderDate,'19000101'),112) 
                                              <=CASE WHEN CONVERT(CHAR(8),@dt_StartDateTo,112) = '19000101' 
                                                     THEN CONVERT(CHAR(8),ISNULL(OH.OrderDate,'19000101'),112) 
                                                     ELSE CONVERT(CHAR(8),@dt_StartDateTo,112) END
   GROUP BY ISNULL(RTRIM(OH.Orderkey),'') 
         ,  ISNULL(RTRIM(OH.Storerkey),'')

   INSERT INTO #TEMP_PREPACK (Orderkey, Storerkey, Sku, BOMQty, BOMCaseCnt)
   SELECT ISNULL(RTRIM(TOH.Orderkey),'')
        , ISNULL(RTRIM(PD.Storerkey),'')
        , ISNULL(RTRIM(BOM.Sku),'')
        , ISNULL(SUM(BOM.Qty),0)
        , ISNULL(BOMPK.CaseCnt,0)
   FROM dbo.#TEMP_ORD TOH WITH (NOLOCK)
   JOIN dbo.STORERCONFIG SC1 WITH (NOLOCK) ON (TOH.Storerkey= SC1.Storerkey) AND (SC1.Configkey = 'PREPACKBYBOM') AND (SC1.SValue = '1')
   JOIN dbo.STORERCONFIG SC2 WITH (NOLOCK) ON (TOH.Storerkey= SC2.Storerkey) AND (SC2.Configkey = 'PREPACKCONSOALLOCATION') AND (SC2.SValue = '1')
   LEFT JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON (TOH.Orderkey=PD.Orderkey) 
   LEFT JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)
   LEFT JOIN dbo.BILLOFMATERIAL BOM WITH (NOLOCK) ON (PD.Storerkey = BOM.Storerkey) AND (LA.Lottable03 = BOM.Sku)
   LEFT JOIN dbo.UPC UPC WITH (NOLOCK) ON (BOM.Storerkey = UPC.Storerkey) AND (BOM.Sku = UPC.Sku) AND (UPC.UOM = 'CS')
   LEFT JOIN dbo.PACK BOMPK WITH (NOLOCK) ON (UPC.Packkey=BOMPK.Packkey) 
   GROUP BY ISNULL(RTRIM(TOH.Orderkey),'')
         ,  ISNULL(RTRIM(PD.Storerkey),'')
         ,  ISNULL(RTRIM(BOM.Sku),'')
         ,  ISNULL(BOMPK.CaseCnt,0)

   INSERT INTO #TEMP_ORDPICK (Orderkey, PickCnt, PickLoose)
   SELECT ISNULL(RTRIM(TOH.Orderkey),'')
         ,ISNULL(CASE WHEN PPACK.Orderkey IS NULL 
                      THEN SUM(FLOOR(PD.Qty / (CASE WHEN ISNULL(SPK.CaseCnt,0)= 0 THEN 1 ELSE SPK.CaseCnt END)))
                      ELSE SUM(FLOOR(PD.Qty / (CASE WHEN ISNULL(PPACK.BOMCaseCnt,0)= 0 THEN 1 ELSE PPACK.BOMCaseCnt END  
                                            *  CASE WHEN ISNULL(PPACK.BOMQty,0) = 0 THEN 1 ELSE PPACK.BOMQty END)))
                      END,0)  PickCnt
         ,ISNULL(CASE WHEN PPACK.Orderkey IS NULL 
                      THEN SUM(PD.Qty % (CASE WHEN ISNULL(SPK.CaseCnt,0) = 0 THEN 1 ELSE CONVERT(INT, SPK.CaseCnt) END)) 
                      ELSE SUM(PD.Qty % (CASE WHEN ISNULL(PPACK.BOMCaseCnt,0)= 0 THEN 1 ELSE CONVERT(INT, PPACK.BOMCaseCnt) END 
                                      *  CASE WHEN ISNULL(PPACK.BOMQty,0) = 0 THEN 1 ELSE PPACK.BOMQty END))
                      END,0)  PickLoose
   FROM dbo.#TEMP_ORD TOH       WITH (NOLOCK)
   LEFT JOIN dbo.PICKDETAIL PD  WITH (NOLOCK) ON (TOH.Orderkey=PD.Orderkey) 
   LEFT JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.Storerkey=SKU.Storerkey) AND (PD.Sku=SKU.Sku)
   LEFT JOIN dbo.PACK SPK WITH (NOLOCK) ON (SKU.Packkey=SPK.Packkey)  
   LEFT JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)
   LEFT JOIN #TEMP_PREPACK PPACK ON (TOH.Orderkey = PPACK.Orderkey) AND (TOH.Storerkey = PPACK.Storerkey) AND (LA.Lottable03 = PPACK.Sku)
   GROUP BY ISNULL(RTRIM(TOH.Orderkey),'')
         ,  PPACK.Orderkey

   INSERT INTO #TEMP_PACKINFO (Orderkey, NoOfPickTicket, NoOfLabel, PackedQty)
   SELECT ISNULL(RTRIM(OH.Orderkey),'')
--         ,ISNULL(RTRIM(OH.Loadkey),'')
--         ,ISNULL(RTRIM(OH.MBOLKey),'')
         ,COUNT( DISTINCT PH.PickHeaderkey )
         ,CASE WHEN PD.PickSlipNo IS NULL THEN 0 ELSE COUNT( DISTINCT PD.LabelNo ) END
         ,SUM( ISNULL(PD.Qty,0) )
   FROM #TEMP_ORD TOH
   JOIN dbo.ORDERS     OH WITH (NOLOCK) ON (TOH.Orderkey=OH.Orderkey)
   JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON (OH.Orderkey=PH.Orderkey) 
   LEFT JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickHeaderKey=PD.PickSlipNo) 
   GROUP BY ISNULL(RTRIM(OH.Orderkey),'')
--         ,  ISNULL(RTRIM(OH.Loadkey),'')
--         ,  ISNULL(RTRIM(OH.MBOLKey),'')
         ,  PD.PickSlipNo

   -- Labelled -> Dropid.Type = 'C' AND PACKDETAIL.LabelNo = DROPIDDETAIL.ChildID and dropid.LabelPrinted = 'Y' and locationcategory <> 'STAGING'
   -- Palletize -> Dropid.Type = 'P' AND PACKDETAIL.LabelNo = DROPIDDETAIL.ChildID  and locationcategory <> 'STAGING'

   INSERT INTO #TEMP_ORDPACK (Orderkey, QtyLabelled, QtyPalletized, QtyOnStaged, QtyLoaded)
   SELECT T.Orderkey
         -- When need palletization, system will create a new dropid with type 'P' for the carton with dropidtype = 'C', and later droploc will updated after sent to STAGE. 
         -- Carton does not need to palletize will remain as dropidtype = 'C' and its droploc will updated to after sent to STAGE 
         ,ISNULL(SUM(CASE WHEN T.NoOfDropIDType > 1 THEN T.QtyLabelled - T.QtyPalletized ELSE T.QtyLabelled END),0) 
         ,ISNULL(SUM(T.QtyPalletized),0)
         ,ISNULL(SUM(T.QtyOnStaged),0)
         ,ISNULL(SUM(T.QtyLoaded),0)
   FROM (
      SELECT Orderkey  = ISNULL(RTRIM(TOH.Orderkey),'')
            ,LabelNo   = ISNULL(RTRIM(PD.LabelNo),'')
            ,NoOfDropIDType = COUNT( DISTINCT ISNULL(RTRIM(DI.DropIDType),'') )
            ,QtyLabelled  = ISNULL(SUM(CASE WHEN L.LocationCategory <> 'STAGING' AND ISNULL(RTRIM(DI.DropIDType),'') =  'C' AND (DI.LabelPrinted = 'Y')
                            THEN ISNULL(PD.Qty,0) ELSE 0 END),0)
            ,QtyPalletized= ISNULL(SUM(CASE WHEN L.LocationCategory <> 'STAGING' AND ISNULL(RTRIM(DI.DropIDType),'') = 'P'THEN ISNULL(PD.Qty,0) ELSE 0 END),0)  
            ,QtyOnStaged = ISNULL(SUM(CASE WHEN L.LocationCategory = 'STAGING' AND ISNULL(RTRIM(DI.AdditionalLoc),'')= '' THEN ISNULL(PD.Qty,0) ELSE 0 END),0) 
            ,QtyLoaded = ISNULL(SUM(CASE WHEN L.LocationCategory = 'STAGING' AND ISNULL(RTRIM(DI.AdditionalLoc),'') <> '' THEN ISNULL(PD.Qty,0) ELSE 0 END),0) 
      FROM #TEMP_ORD TOH WITH (NOLOCK)
      LEFT JOIN dbo.PACKHEADER   PH  WITH (NOLOCK) ON (TOH.Orderkey=PH.Orderkey) 
      LEFT JOIN dbo.PACKDETAIL   PD  WITH (NOLOCK) ON (PH.PickSlipNo=PD.PickSlipNo) 
      LEFT JOIN dbo.DROPIDDETAIL DID WITH (NOLOCK) ON (PD.LabelNo = DID.ChildID) 
      LEFT JOIN dbo.DROPID       DI  WITH (NOLOCK) ON (DID.DropID = DI.DropID) --AND (DI.LabelPrinted = 'Y')
      LEFT JOIN dbo.LOC          L   WITH (NOLOCK) ON (DI.Droploc = L.Loc)
      GROUP BY ISNULL(RTRIM(TOH.Orderkey),'') 
            ,  ISNULL(RTRIM(PD.LabelNo),'')
         ) T
   GROUP BY T.Orderkey

   SELECT ISNULL(RTRIM(MB.BookingReference),'')                'Route Auth'
        , ISNULL(RTRIM(MB.CarrierKey),'')                      'SCAC'
        , ISNULL(RTRIM(MB.ExternMbolKey),'')                   'VicsBill'
        , ISNULL(RTRIM(OH.Facility),'')                        'WHSE'
        , ISNULL(RTRIM(MB.UserDefine10),'')                    'Lane#'
        , CASE WHEN ISNULL(RTRIM(MB.DriverName),'') <> '' THEN '(' +  ISNULL(RTRIM(MB.DriverName),'') + ')' ELSE '' END
                                                               'DriverName'
        , ISNULL(RTRIM(OH.Storerkey),'')                       'BU'
        , ISNULL(RTRIM(OH.ExternOrderKey),'')                  'PO'
        , ISNULL(RTRIM(OH.BuyerPO),'')                         'PT' -- Pick ticket 
        , ISNULL(RTRIM(OH.LoadKey),'')                         'Loadkey'
        , ISNULL(RTRIM(OH.C_Company),'')                       'ShipTo'
        , CONVERT(CHAR(8), OH.AddDate, 112)                    'RecvDate'
        , CONVERT(CHAR(8), OH.OrderDate, 112)                  'StartDate'
        , CONVERT(CHAR(8), OH.DeliveryDate, 112)               'CancelDate'
        , CONVERT(CHAR(8), OH.PODCust, 112)                    'MABD'
        , CASE WHEN LP.UserDefine06 IS NULL OR CONVERT(CHAR(8),LP.UserDefine06,112) = '19000101' 
               THEN CASE WHEN MB.UserDefine06 IS NULL OR CONVERT(CHAR(8),MB.UserDefine06,112) = '19000101' 
                         THEN NULL ELSE CONVERT(CHAR(8), MB.UserDefine06, 112) END
               ELSE CONVERT(CHAR(8), LP.UserDefine06, 112)
               END                                             'Routing date'
        , CASE WHEN MB.UserDefine07 IS NULL OR CONVERT(NVARCHAR(20), MB.UserDefine07, 120) = '1900-01-01 00:00:00' THEN NULL
               ELSE MB.UserDefine07 END 'PickUp Date'
        , ISNULL(TPI.NoOfLabel,0)                              '# Labels'  
        , ISNULL(TPI.NoOfPickTicket,0)                         '# Of PickTickets'
        , SUM(TOH.OriginalQty)                                 'OriginalQty'
        , SUM(TOH.QtyAllocated)                                'QtyAllocated'
        , ISNULL(SUM(TOH.QtyAllocated)/CASE WHEN SUM(TOH.OriginalQty)= 0 THEN 1 ELSE SUM(TOH.OriginalQty) END ,0)  * 100       '% Allocated'
        , ISNULL(SUM(TOH.QtyPIP)/CASE WHEN SUM(TOH.QtyAllocated + TOH.QtyPicked)= 0 THEN 1 ELSE SUM(TOH.QtyAllocated + TOH.QtyPicked) END,0)  
                                                                                                                   * 100       '% Qty PIP'
        , ISNULL(SUM(TOH.QtyPicked-(TPACK.QtyLabelled+TPACK.QtyPalletized+TPACK.QtyOnStaged+TPACK.QtyLoaded))
                /CASE WHEN SUM(TOH.ShippedQty) = 0 THEN 1 ELSE SUM(TOH.ShippedQty) END,0)                          * 100       '% QtyPicked'
        , ISNULL(SUM(TPACK.QtyLabelled)/CASE WHEN SUM(TOH.ShippedQty) = 0 THEN 1 ELSE SUM(TOH.ShippedQty) END,0)   * 100       '% QtyLabelled'
        , ISNULL(SUM(TPACK.QtyPalletized)/CASE WHEN SUM(TOH.ShippedQty) = 0 THEN 1 ELSE SUM(TOH.ShippedQty) END,0) * 100       '% QtyPalletized'
        , ISNULL(SUM(TPACK.QtyOnStaged)/CASE WHEN SUM(TOH.ShippedQty) = 0 THEN 1 ELSE SUM(TOH.ShippedQty) END,0)   * 100       '% QtyOnStage'
        , ISNULL(SUM(TPACK.QtyLoaded)/CASE WHEN SUM(TOH.ShippedQty) = 0 THEN 1 ELSE SUM(TOH.ShippedQty) END,0)     * 100       '% QtyLoaded'
        , SUM(TOH.ShippedQty)                                                                           'ShippedQty'
        , SUM(TOH.QtyPIP)                                                                               'QTYPIP'
        , SUM(TOH.QtyPicked-(TPACK.QtyLabelled+TPACK.QtyPalletized+TPACK.QtyOnStaged+TPACK.QtyLoaded))  'QtyPicked'
        , SUM(TPACK.QtyLabelled)                                                                        'QtyLabelled'
        , SUM(TPACK.QtyPalletized)                                                                      'QtyPalletized'
        , SUM(TPACK.QtyOnStaged)                                                                        'QtyOnStaged'
        , SUM(TPACK.QtyLoaded)                                                                          'QtyLoaded'
        , SUM(TPICK.PickCnt)                                                                            'PickCnt'
        , SUM(TPICK.PickLoose)                                                                          'PickLoose'
      FROM #TEMP_ORD TOH 
      JOIN #TEMP_ORDPACK TPACK                  ON (TOH.Orderkey=TPACK.Orderkey) 
      JOIN #TEMP_ORDPICK TPICK                  ON (TOH.Orderkey=TPICK.Orderkey)  
      JOIN dbo.ORDERS        OH   WITH (NOLOCK) ON (TOH.Orderkey=OH.Orderkey) 
      LEFT JOIN dbo.MBOL     MB   WITH (NOLOCK) ON (OH.MbolKey=MB.MBOLKey) 
      LEFT JOIN dbo.LOADPLAN LP   WITH (NOLOCK) ON (OH.LoadKey=LP.LoadKey) 
      LEFT JOIN #TEMP_PACKINFO TPI              ON (OH.Orderkey = TPI.Orderkey)

      GROUP BY ISNULL(RTRIM(MB.BookingReference),'')  
            ,  ISNULL(RTRIM(MB.CarrierKey),'')          
            ,  ISNULL(RTRIM(MB.ExternMbolKey),'')       
            ,  ISNULL(RTRIM(OH.Facility),'')           
            ,  ISNULL(RTRIM(MB.UserDefine10),'') 
            ,  CASE WHEN ISNULL(RTRIM(MB.DriverName),'') <> '' THEN '(' +  ISNULL(RTRIM(MB.DriverName),'') + ')' ELSE '' END 
            ,  ISNULL(RTRIM(OH.Storerkey),'')     
            ,  ISNULL(RTRIM(OH.ExternOrderKey),'')  
            ,  ISNULL(RTRIM(OH.BuyerPO),'')  
            ,  ISNULL(RTRIM(OH.LoadKey),'')               
            ,  ISNULL(RTRIM(OH.C_Company),'')
            ,  CONVERT(CHAR(8), OH.AddDate, 112)                            
            ,  CONVERT(CHAR(8), OH.OrderDate, 112)                               
            ,  CONVERT(CHAR(8), OH.DeliveryDate, 112) 
            ,  CONVERT(CHAR(8), OH.PODCust, 112)                           
            ,  CASE WHEN LP.UserDefine06 IS NULL OR CONVERT(CHAR(8),LP.UserDefine06,112) = '19000101' 
               THEN CASE WHEN MB.UserDefine06 IS NULL OR CONVERT(CHAR(8),MB.UserDefine06,112) = '19000101' 
                         THEN NULL ELSE CONVERT(CHAR(8), MB.UserDefine06, 112) END
               ELSE CONVERT(CHAR(8), LP.UserDefine06, 112)
               END                     
            ,  CASE WHEN MB.UserDefine07 IS NULL OR CONVERT(NVARCHAR(20), MB.UserDefine07, 120) = '1900-01-01 00:00:00' THEN NULL
                    ELSE MB.UserDefine07 END
            ,  ISNULL(TPI.NoOfPickTicket,0)  
            ,  ISNULL(TPI.NoOfLabel,0) 
      ORDER BY CASE WHEN MB.UserDefine07 IS NULL OR CONVERT(NVARCHAR(20), MB.UserDefine07, 120) = '1900-01-01 00:00:00' THEN NULL
                    ELSE MB.UserDefine07 END
            ,  ISNULL(RTRIM(MB.BookingReference),'')
          
END

GO