SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_nikecn_ConsoDespatchTkt6                       */
/* Creation Date: 12-May-2016                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: 366617 - Packing list detail label Enhancement              */
/*                                                                      */
/* Called By: r_dw_despatch_ticket_nikecn6                              */
/*                                                                      */
/* PVCS Version: 2.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 14-APR-2016	 CSCHONG 1.0   SOS#368516 wraptext for address (CS01)    */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_nikecn_ConsoDespatchTkt6]
   @c_pickslipno     NVARCHAR(10),
   @n_StartCartonNo  INT = 0,
   @n_EndCartonNo    INT = 0,
   @c_StartLabelNo   NVARCHAR(20) = '',
   @c_EndLabelNo     NVARCHAR(20) = ''
AS
BEGIN

   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_externOrderkey NVARCHAR(50)   --tlting_ext
         , @c_LoadKey        NVARCHAR(10)
         , @i_ExtCnt         INT
         , @i_LineCnt        INT
         , @SQL              NVARCHAR(1000)
         , @nMaxCartonNo     INT
         , @nCartonNo        INT
         , @nSumPackQty      INT
         , @nSumPickQty      INT
         , @c_ConsigneeKey   NVARCHAR(15)--SOS# 174296
         , @c_Company        NVARCHAR(45)
         , @c_Address1       NVARCHAR(150)
         , @c_Address2       NVARCHAR(45)
         , @c_Address3       NVARCHAR(45)
         , @c_City           NVARCHAR(45)
         , @d_DeliveryDate   DATETIME
         , @c_Orderkey       NVARCHAR(10)  --NJOW01
         , @c_Storerkey      NVARCHAR(15)             --(Wan01)
         , @c_ShowQty_Cfg    NVARCHAR(10)             --(Wan01)
         , @c_ShowOrdType_Cfg NVARCHAR(10)            --(Wan02) 
         , @c_susr4           NVARCHAR(10)            --(Wan03)
         , @c_ShowOrdDoor_Cfg NVARCHAR(10)            --(Wan04)   
         , @c_Loc             NVARCHAR(10)            --(Wan04)
         , @c_SOStatus        NVARCHAR(10)            --(Wan04)
         , @n_MultiExtOrd     INT                     --(Wan06)
         , @c_ShowTransportRoute_Cfg NVARCHAR(10)     --(CS01)
         , @c_Fax2                   NVARCHAR(18)     --(CS01)
         , @c_showsku                NVARCHAR(1)      --(CS01)
     

   SET @c_Storerkey  = ''                             --(Wan01)
   SET @c_ShowQty_Cfg= ''                             --(Wan01)
   SET @c_ShowOrdType_Cfg = ''                        --(Wan02)
   SET @c_susr4           = ''                        --(Wan03)
   SET @c_ShowOrdDoor_Cfg = ''                        --(Wan04)
   SET @c_Loc             = ''                        --(Wan04)
   SET @c_SOStatus        = ''                        --(Wan04)
   SET @n_MultiExtOrd     = 1                         --(Wan06)
   SET @c_ShowTransportRoute_Cfg = ''                 --(CS01)
   SET @c_Fax2                   = ''                 --(CS01)
   SET @c_showsku                ='N'
   
   SELECT @c_Orderkey = Orderkey  --NJOW01
         ,@c_Storerkey= ISNULL(RTRIM(Storerkey),'')   --(Wan01)
   FROM PACKHEADER (NOLOCK)
   WHERE Pickslipno = @c_Pickslipno

   --(Wan01) - START
   SELECT @c_ShowQty_Cfg = ISNULL(RTRIM(SValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Configkey = 'DPTkt_NKCN3_CTNQty'
   --(Wan01) - END

   --(Wan02) - START
   SELECT @c_ShowOrdType_Cfg = ISNULL(RTRIM(SValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Configkey = 'DPTkt_NKCN3_ORDType'
   --(Wan02) - END

   --(Wan03) - START
   SELECT @c_susr4 = ISNULL(RTRIM(SUSR4),'')
   FROM STORER WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   --(Wan03) - END

   --(Wan05) - START
   IF @c_susr4 <> '1028' 
   BEGIN
      SET @c_susr4 = ''
   END
   --(Wan05) - END
   
   --(Wan04) - START
   SELECT @c_ShowOrdDoor_Cfg = ISNULL(RTRIM(SValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Configkey = 'DPTkt_NKCN3_OrdDoor'

   IF @c_ShowOrdDoor_Cfg = '1'
   BEGIN
      SELECT @c_LoadKey        = ISNULL(RTRIM(Loadkey),'') 
            ,@c_ExternOrderkey = ISNULL(RTRIM(ExternOrderkey),'') 
            ,@c_Consigneekey   = ISNULL(RTRIM(Consigneekey),'') 
            ,@c_SOStatus       = ISNULL(RTRIM(SOStatus),'')
      FROM ORDERS (NOLOCK)
      WHERE Orderkey = @c_Orderkey

      IF @c_SOStatus = 'HOLD'
      BEGIN
         SET @c_Loc = 'N/A'
      END
      ELSE
      BEGIN
         --For VFCDC, 1 Despatch Loc assign to 1 Loadkey
         SELECT TOP 1 @c_Loc = LPLD.Loc
         FROM LOADPLANLANEDETAIL LPLD WITH (NOLOCK) 
         WHERE LPLD.Loadkey = @c_LoadKey
         --AND   LPLD.ExternOrderkey = @c_ExternOrderkey 
         --AND   LPLD.Consigneekey   = @c_Consigneekey
         AND   LPLD.LocationCategory = 'STAGING'
         ORDER BY LPLD.LP_LaneNumber
      END
   END
   --(Wan04) - END

   --(CS01) - START
   SELECT @c_ShowTransportRoute_Cfg = ISNULL(RTRIM(SValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Configkey = 'DPTkt_NKCN3_TransportRoute'

   IF @c_ShowTransportRoute_Cfg = '1'
   BEGIN
      SELECT @c_Fax2       = ISNULL(RTRIM(c_fax2),'') 
      FROM ORDERS (NOLOCK)
      WHERE Orderkey = @c_Orderkey
   END
   --(CS01) - END

  --(CS02) Start
   SELECT @c_showsku = CASE WHEN ISNULL(Code,'') <> '' THEN 'Y' ELSE 'N' END
   FROM Codelkup (NOLOCK)
   WHERE listname='REPORTCFG'
   AND Code = 'SHOWSKUFIELD'                                        
   AND Long = 'r_dw_despatch_ticket_nikecn6' AND ISNULL(Short,'') <> 'N'    
   AND Storerkey =  @c_Storerkey

 --(CS02 End)

   --NJOW01
   CREATE TABLE #RESULT (
       ROWREF INT NOT NULL IDENTITY(1,1) Primary Key,
       PickSlipNo NVARCHAR(10) NULL,
       LoadKey NVARCHAR(10) NULL,
       Route NVARCHAR(10) NULL,
       ConsigneeKey NVARCHAR(15) NULL,
       DeliveryDate DATETIME NULL,
       C_Company NVARCHAR(45) NULL,
       C_Address1 NVARCHAR(150) NULL,
       C_Address2 NVARCHAR(45) NULL,
       C_Address3 NVARCHAR(45) NULL,
       C_City NVARCHAR(45) NULL,
       xDockLane NVARCHAR(10) NULL,
       LabelNo NVARCHAR(20) NULL,
       CartonNo INT NULL,
       ExtOrder1 NVARCHAR(80) NULL,
       ExtOrder2 NVARCHAR(80) NULL,
       ExtOrder3 NVARCHAR(80) NULL,
       ExtOrder4 NVARCHAR(80) NULL,
       ExtOrder5 NVARCHAR(80) NULL,
       ExtOrder6 NVARCHAR(80) NULL,
       ExtOrder7 NVARCHAR(80) NULL,
       ExtOrder8 NVARCHAR(80) NULL,
       ExtOrder9 NVARCHAR(80) NULL,
       ExtOrder10 NVARCHAR(80) NULL,
       TotalSku INT NULL,
       TotalPcs INT NULL,
       MaxCarton NVARCHAR(10) NULL
      ,ShowQtyCfg NVARCHAR(10) NULL       --(Wan01)
      ,OrderType  VARCHAR(10) NULL        --(Wan02)
      ,SUSR4      NVARCHAR(20) NULL       --(Wan03)
      ,Door       NVARCHAR(10) NULL       --(Wan04)
      ,Loc        NVARCHAR(10) NULL       --(Wan04)
      ,C_Fax2     NVARCHAR(18) NULL       --(CS01)
      ,ShowSKU    NVARCHAR(1)  NULL       --(CS02)
      )
      
   CREATE INDEX IX_RESULT_01 on #RESULT ( LoadKey )
   CREATE INDEX IX_RESULT_02 on #RESULT ( CartonNo )

--   INSERT INTO TraceInfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5) -- SOS# 174296
--   VALUES ('isp_nikecn_ConsoDespatchTkt: ' + RTRIM(SUSER_SNAME()), GETDATE()
--         , @c_pickslipno, @n_StartCartonNo, @n_EndCartonNo
--         , @c_StartLabelNo, @c_EndLabelNo)

   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      SET @n_MultiExtOrd = 1

      INSERT INTO #RESULT   ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc,C_Fax2  --(Wan01), (Wan02) Add OrderType,  (Wan03) Add SUSR4, (Wan04) - Add Door --(CS01)
                            ,showsku)                                                   --(CS02)   
                          
      SELECT PackHeader.PickSlipNo,
            PackHeader.LoadKey,
            PackHeader.Route,
            MAX(ORDERS.Consigneekey) as ConsigneeKey,
            MAX(Orders.DeliveryDate) as DeliveryDate,
            MAX(Orders.C_Company) as C_Company,
            -- MAX(Orders.C_Address1) as C_Address1, --(CS02)
            dbo.Fnc_Wraptext(MAX(Orders.C_Address1) + MAX(Orders.C_Address2) + MAX(Orders.C_Address3),18)  as C_Address1, --(CS02)
           '',-- MAX(Orders.C_Address2) as C_Address2,       --(CS02)
           '',-- MAX(Orders.C_Address3) as C_Address3,       --(CS02)
            MAX(Orders.C_City) as C_City,
            xDockLane = CASE WHEN MAX(ORDERS.xDockFlag) = '1' THEN
               (SELECT StorerSODefault.xDockLane FROM StorerSODefault (NOLOCK)
                WHERE StorerSODefault.StorerKey = MAX(ORDERS.StorerKey))
               ELSE SPACE(10)
               END,
            PackDetail.LabelNo,
            PackDetail.CartonNo,
            ExtOrder1 = SPACE(80),
            ExtOrder2 = SPACE(80),
            ExtOrder3 = SPACE(80),
            ExtOrder4 = SPACE(80),
            ExtOrder5 = SPACE(80),
            ExtOrder6 = SPACE(80),
            ExtOrder7 = SPACE(80),
            ExtOrder8 = SPACE(80),
            ExtOrder9 = SPACE(80),
            ExtOrder10 = SPACE(80),
            COUNT(DISTINCT PACKDETAIL.Sku) AS TotalSku,    -- (YokeBeen01) -- SOS# 248050
            SUM(DISTINCT PACKDETAIL.Qty) AS TotalPcs,      -- (YokeBeen01) -- SOS# 248050
            MaxCarton = SPACE(10)
         ,  ShowQtyCfg= @c_ShowQty_Cfg                --(Wan01)
         ,  OrderType = CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END            --(Wan02)
         ,  Plant = @c_Susr4                                                                       --(Wan03)
         ,  Door  = ISNULL(RTRIM(ORDERS.Door),'')                                                  --(Wan04)
         ,  Loc   = @c_Loc                                                                         --(Wan04)
         ,  c_Fax2 = @c_Fax2                                                                       --(CS01)
         ,  showsku  = @c_showsku                                                                  --(CS02)
      FROM Orders Orders WITH (NOLOCK)
      JOIN OrderDetail OrderDetail WITH (NOLOCK) ON Orders.OrderKey = OrderDetail.OrderKey
      JOIN LoadPlanDetail LoadPlanDetail WITH (NOLOCK) ON (Orders.OrderKey = LoadplanDetail.OrderKey)
      JOIN Packheader Packheader WITH (NOLOCK) ON (LoadPlanDetail.LoadKey = Packheader.LoadKey)
      JOIN Packdetail Packdetail WITH (NOLOCK) ON (Packheader.Pickslipno = Packdetail.pickslipno AND OrderDetail.SKU = PackDetail.SKU)
      WHERE PackHeader.PickSlipNo = @c_pickslipno
      AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END
      GROUP BY PackHeader.PickSlipNo,
               PackHeader.LoadKey,
               PackHeader.Route,
               PackDetail.LabelNo,
               PackDetail.CartonNo
           ,  CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END                     --(Wan02) 
           ,  ISNULL(RTRIM(ORDERS.Door),'')                                                       --(Wan04)
           --,  ISNULL(Orders.C_Fax2,'')                                                            --(CS01)
   END
   ELSE
   BEGIN  --NJOW01
      SET @n_MultiExtOrd = 0

      INSERT INTO #RESULT  ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc,C_Fax2  --(Wan01), (Wan02)Add OrderType, (Wan03) Add SUSR4, (Wan04) - Add Door  --(CS01)
                            ,showsku)                                                   --(CS02)  
      SELECT A.PickSlipNo,
            Orders.LoadKey,
            A.Route,
            ORDERS.Consigneekey,
            Orders.DeliveryDate,
            Orders.C_Company,
           -- Orders.C_Address1,        --(CS02)
           dbo.Fnc_Wraptext(MAX(Orders.C_Address1) + MAX(Orders.C_Address2) + MAX(Orders.C_Address3),18)  as C_Address1, --(CS02)
          '',--  Orders.C_Address2,     --(CS02)
          '',--  Orders.C_Address3,     --(CS02)
            Orders.C_City,
            xDockLane = CASE WHEN ORDERS.xDockFlag = '1' THEN
               (SELECT StorerSODefault.xDockLane FROM StorerSODefault (NOLOCK)
                WHERE StorerSODefault.StorerKey = ORDERS.StorerKey)
               ELSE SPACE(10)
               END,
            PackDetail.LabelNo,
            PackDetail.CartonNo,
            ExtOrder1 = SPACE(80),
            ExtOrder2 = SPACE(80),
            ExtOrder3 = SPACE(80),
            ExtOrder4 = SPACE(80),
            ExtOrder5 = SPACE(80),
            ExtOrder6 = SPACE(80),
            ExtOrder7 = SPACE(80),
            ExtOrder8 = SPACE(80),
            ExtOrder9 = SPACE(80),
            ExtOrder10 = SPACE(80),
            COUNT(PACKDETAIL.Sku) AS TotalSku,   -- (YokeBeen01)
            SUM(PACKDETAIL.Qty) AS TotalPcs,     -- (YokeBeen01)
            MaxCarton = SPACE(10)
         ,  ShowQtyCfg= @c_ShowQty_Cfg                --(Wan01)
         ,  OrderType = CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END            --(Wan02)
         ,  Plant = @c_Susr4                                                                       --(Wan03) 
         ,  Door  = CASE WHEN @c_ShowOrdDoor_Cfg = '1'                                             --(Wan04)
                         THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                            --(Wan04)
         ,  Loc   = @c_Loc                                                                         --(Wan04)
         ,  c_Fax2 = @c_Fax2                                                                       --(CS01)
         ,  showsku  = @c_showsku                                                                  --(CS02)
      FROM Orders Orders WITH (NOLOCK)
      -- SOS# 248050 (Start)
      --      JOIN OrderDetail OrderDetail WITH (NOLOCK) ON Orders.OrderKey = OrderDetail.OrderKey
      --      JOIN Packheader Packheader WITH (NOLOCK) ON (Orders.Orderkey = Packheader.Orderkey)
      JOIN (
      SELECT DISTINCT OD.OrderKey, OD.Sku, PH.Pickslipno, PH.Route
      FROM OrderDetail OD WITH (NOLOCK)
      JOIN PackHeader PH WITH (NOLOCK) ON (OD.OrderKey = PH.OrderKey)
      WHERE PH.Pickslipno = @c_pickslipno
      ) AS A
      ON Orders.OrderKey = A.OrderKey
      -- SOS# 248050 (End)
      JOIN Packdetail Packdetail WITH (NOLOCK) ON (A.Pickslipno = Packdetail.pickslipno AND A.SKU = PackDetail.SKU)
      WHERE A.PickSlipNo = @c_pickslipno
      AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END
      GROUP BY A.PickSlipNo,
               Orders.LoadKey,
               A.Route,
               PackDetail.LabelNo,
               PackDetail.CartonNo,
               ORDERS.Consigneekey,
               Orders.DeliveryDate,
               Orders.C_Company,
               Orders.C_Address1,
               Orders.C_Address2,
               Orders.C_Address3,
               Orders.C_City,
               Orders.Storerkey,
               Orders.xDockFlag,
               Orders.LoadKey
            ,  CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END                     --(Wan02)
            ,  CASE WHEN @c_ShowOrdDoor_Cfg = '1' THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END   --(Wan04)                                                     --(Wan04)
          --  ,  ISNULL(Orders.C_Fax2,'')                                                      --(CS01)

   END

   DECLARE @nCartonIndex int

   IF @n_StartCartonNo <> 0 AND  @n_EndCartonNo <> 0
   BEGIN
      SET @nCartonIndex = @n_StartCartonNo
      WHILE @nCartonIndex <= @n_EndCartonNo
      BEGIN
      IF NOT EXISTS(SELECT 1 FROM #RESULT
                    WHERE PickSlipNo = @c_pickslipno
                    AND CartonNo = @nCartonIndex)
         BEGIN
            SET ROWCOUNT 1
               IF ISNULL(@c_Orderkey,'') = ''
               BEGIN
                  INSERT INTO #RESULT  ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc,C_Fax2                   --(Wan01), (Wan02)AddOrderType, (Wan03) Add SUSR4, (Wan04) - Add Door   --(CS01)
                            ,showsku)                                                   --(CS02)
                  SELECT
                  PackHeader.PickSlipNo,
                  PackHeader.LoadKey,
                  PackHeader.Route,
                  MAX(ORDERS.Consigneekey) as ConsigneeKey,
                  MAX(Orders.DeliveryDate) as DeliveryDate,
                  MAX(Orders.C_Company) as C_Company,
                --  MAX(Orders.C_Address1) as C_Address1,            --(CS02)
                dbo.Fnc_Wraptext(MAX(Orders.C_Address1) + MAX(Orders.C_Address2) + MAX(Orders.C_Address3),18)  as C_Address1, --(CS02)
                '',--  MAX(Orders.C_Address2) as C_Address2,         --(CS02)
                '',--  MAX(Orders.C_Address3) as C_Address3,         --(CS02)
                  MAX(Orders.C_City) as C_City,
                  xDockLane = CASE WHEN MAX(ORDERS.xDockFlag) = '1' THEN
                  (  SELECT StorerSODefault.xDockLane FROM StorerSODefault (NOLOCK)
                     WHERE StorerSODefault.StorerKey = MAX(ORDERS.StorerKey)  )
                     ELSE SPACE(10)
                     END,
                  @c_StartLabelNo AS LabelNo,
                  @nCartonIndex AS CartonNo,
                  ExtOrder1 = SPACE(80),
                  ExtOrder2 = SPACE(80),
                  ExtOrder3 = SPACE(80),
                  ExtOrder4 = SPACE(80),
                  ExtOrder5 = SPACE(80),
                  ExtOrder6 = SPACE(80),
                  ExtOrder7 = SPACE(80),
                  ExtOrder8 = SPACE(80),
                  ExtOrder9 = SPACE(80),
                  ExtOrder10 = SPACE(80),
                  0 AS TotalSku,      -- (YokeBeen01)
                  0 AS TotalPcs,      -- (YokeBeen01)
                  MaxCarton = SPACE(80)
               ,  ShowQtyCfg= @c_ShowQty_Cfg     
               ,  OrderType = CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END      --(Wan02)                    --(Wan01)
               ,  Plant = @c_Susr4                                                                 --(Wan03)
               ,  Door  = CASE WHEN @c_ShowOrdDoor_Cfg = '1'                                       --(Wan04)
                               THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                      --(Wan04)
               ,  Loc   = @c_Loc                                                                   --(Wan04)
               ,  c_Fax2 = @c_Fax2                                                                 --(CS01) 
               ,  showsku  = @c_showsku                                                            --(CS02)
                  FROM PackHeader (NOLOCK),
                  Orders (NOLOCK),
                  -- PackDetail (NOLOCK),
                  LoadplanDetail (NOLOCK)
                  WHERE PackHeader.PickSlipNo = @c_pickslipno AND
                  PackHeader.LoadKey = LoadplanDetail.LoadKey AND
                  Orders.OrderKey = LoadplanDetail.OrderKey
                  -- PackHeader.PickSlipNo = PackDetail.PickSlipNo
                  GROUP BY PackHeader.PickSlipNo,
                          PackHeader.LoadKey,
                          PackHeader.Route
                        , CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END          --(Wan02)
                        , CASE WHEN @c_ShowOrdDoor_Cfg = '1'                                       --(Wan04)
                               THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                      --(Wan04)    
                       --  ,ISNULL(Orders.C_Fax2,'')                                                 --(CS01)                     
               END
               ELSE
               BEGIN  --NJOW01
                  INSERT INTO #RESULT  ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc,C_Fax2                   --(Wan01), (Wan02)Add ORderType, (Wan03) Add SUSR4, (Wan04) Add Door  (CS01)
                            ,showsku)                                                   --(CS02)
                  SELECT
                  PackHeader.PickSlipNo,
                  Orders.LoadKey,
                  PackHeader.Route,
                  ORDERS.Consigneekey,
                  Orders.DeliveryDate,
                  Orders.C_Company,
                  -- Orders.C_Address1,        --(CS02)
                  dbo.Fnc_Wraptext(MAX(Orders.C_Address1) + MAX(Orders.C_Address2) + MAX(Orders.C_Address3),18)  as C_Address1, --(CS02)
                  '',--  Orders.C_Address2,     --(CS02)
                  '',--  Orders.C_Address3,     --(CS02)
                  Orders.C_City,
                  xDockLane = CASE WHEN ORDERS.xDockFlag = '1' THEN
                  (  SELECT StorerSODefault.xDockLane FROM StorerSODefault (NOLOCK)
                     WHERE StorerSODefault.StorerKey = ORDERS.StorerKey )
                     ELSE SPACE(10)
                     END,
                  @c_StartLabelNo AS LabelNo,
                  @nCartonIndex AS CartonNo,
                  ExtOrder1 = SPACE(80),
                  ExtOrder2 = SPACE(80),
                  ExtOrder3 = SPACE(80),
                  ExtOrder4 = SPACE(80),
                  ExtOrder5 = SPACE(80),
                  ExtOrder6 = SPACE(80),
                  ExtOrder7 = SPACE(80),
                  ExtOrder8 = SPACE(80),
                  ExtOrder9 = SPACE(80),
                  ExtOrder10 = SPACE(80),
                  0 AS TotalSku,      -- (YokeBeen01)
                  0 AS TotalPcs,      -- (YokeBeen01)
                  MaxCarton = SPACE(80)
               ,  ShowQtyCfg= @c_ShowQty_Cfg      
               ,  OrderType = CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END      --(Wan02)                   --(Wan01)
               ,  Plant = @c_Susr4                                                                 --(Wan03)
               ,  Door  = CASE WHEN @c_ShowOrdDoor_Cfg = '1'                                       --(Wan04)
                               THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                      --(Wan04)                        
               ,  Loc   = @c_Loc                                                                   --(Wan04)
               ,  c_Fax2 = @c_Fax2                                                                 --(CS01)
               ,  showsku  = @c_showsku                                                            --(CS02)
                  FROM PackHeader (NOLOCK)
                  JOIN Orders (NOLOCK) ON Packheader.Orderkey = Orders.Orderkey
                  WHERE PackHeader.PickSlipNo = @c_pickslipno
                  GROUP BY PackHeader.PickSlipNo,
                           PackHeader.LoadKey,
                           PackHeader.Route,
                           ORDERS.Consigneekey,
                           Orders.DeliveryDate,
                           Orders.C_Company,
                           Orders.C_Address1,
                           Orders.C_Address2,
                           Orders.C_Address3,
                           Orders.C_City,
                           Orders.Storerkey,
                           Orders.xDockFlag,
                           Orders.LoadKey
                        ,  CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END         --(Wan02)
                        ,  CASE WHEN @c_ShowOrdDoor_Cfg = '1'                                      --(Wan04)
                                THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                     --(Wan04)
                     --   ,  ISNULL(Orders.C_Fax2,'')                                                --(CS01)
               END
            SET ROWCOUNT 0
         END

         -- SET @nCartonIndex = @n_StartCartonNo + 1 Edit by james, Logic error
         SET @nCartonIndex = @nCartonIndex + 1
      END
   END -- If start carton and end carton <> 0

   IF ISNULL(@c_Orderkey,'') = ''
      DECLARE Ext_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.ExternOrderkey, O.Loadkey
      FROM   ORDERS O (NOLOCK)
      JOIN   LoadPlanDetail Ld (NOLOCK) ON O.Loadkey = Ld.Loadkey AND O.Orderkey = Ld.Orderkey
      JOIN   PackHeader Ph (NOLOCK) ON Ph.Loadkey = Ld.Loadkey
      WHERE  Ph.Pickslipno = @c_PickSlipNo
      ORDER BY O.ExternOrderkey
   ELSE  --NJOW01
      DECLARE Ext_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.ExternOrderkey, O.Loadkey
      FROM   ORDERS O (NOLOCK)
      JOIN   PackHeader Ph (NOLOCK) ON O.Orderkey = Ph.Orderkey
      WHERE  Ph.Pickslipno = @c_PickSlipNo
      ORDER BY O.ExternOrderkey

   OPEN Ext_cur

   SELECT @i_ExtCnt  = 1
   SELECT @i_LineCnt = 0

   FETCH NEXT FROM Ext_cur INTO @c_externOrderkey, @c_LoadKey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @i_ExtCnt = 10  -- SOS147156, Change from 11 to 10
      BREAK

      IF @i_LineCnt = 5
      BEGIN
         SELECT @i_LineCnt = 0
         SELECT @i_ExtCnt  = @i_ExtCnt + 1
      END

      SELECT @i_LineCnt = @i_LineCnt + 1

      -- PRINT @c_pickslipno + ' ' + @c_LoadKey + ' ' + @c_externOrderkey
      IF @i_LineCnt = 1
      BEGIN
         SELECT @SQL = "UPDATE #RESULT SET ExtOrder" + RTRIM(LTRIM(@i_ExtCnt)) + " = '" + RTRIM(LTRIM(@c_externOrderkey)) + "' "
                     + "WHERE Pickslipno = '" + RTRIM(@c_pickslipno) + "' AND Loadkey = '" + RTRIM(@c_LoadKey) + "'"
      END
      ELSE
      BEGIN
         SELECT @SQL = "UPDATE #RESULT SET ExtOrder" + RTRIM(LTRIM(@i_ExtCnt)) + " = RTRIM(LTRIM(Extorder" + RTRIM(LTRIM(@i_ExtCnt)) + ")) + ' ' + '" + RTRIM(LTRIM(@c_externOrderkey)) + "' "
       + "WHERE Pickslipno = '" + RTRIM(@c_pickslipno) + "' AND Loadkey = '" + RTRIM(@c_LoadKey) + "'"
      END

      EXEC (@SQL)

      FETCH NEXT FROM Ext_cur INTO @c_externOrderkey, @c_LoadKey
   END
   CLOSE Ext_cur
   DEALLOCATE Ext_cur

   SET @nSumPackQty = 0
   SET @nSumPickQty = 0
   SELECT @nMaxCartonNo = MAX(CartonNo) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo

   DECLARE CTN_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT CartonNo FROM #RESULT WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   ORDER BY CartonNo

   OPEN CTN_CUR
   FETCH NEXT FROM CTN_CUR INTO @nCartonNo

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @nCartonNo = @nMaxCartonNo
      BEGIN
         SET @nSumPackQty = 0
         SET @nSumPickQty = 0

         SELECT @nSumPackQty = SUM(QTY) FROM PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo

         --SELECT @nSumPickQty = SUM(QTY) FROM PickDetail With (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo
         IF ISNULL(@c_Orderkey,'') = ''
         BEGIN
            SELECT @c_LoadKey = LoadKey FROM PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo

            SELECT @nSumPickQty = SUM(PD.QTY) FROM PickDetail PD WITH (NOLOCK)
            JOIN Orders O (nolock) ON (O.StorerKey = PD.StorerKey AND O.OrderKey = PD.OrderKey)
            WHERE O.LoadKey = @c_LoadKey
         END
         ELSE
         BEGIN  --NJOW01
            SELECT @nSumPickQty = SUM(PD.QTY)
            FROM PickDetail PD WITH (NOLOCK)
            WHERE PD.Orderkey = @c_Orderkey
         END

         IF @nSumPackQty = @nSumPickQty
         BEGIN
            UPDATE #RESULT SET MaxCarton = ISNULL(RTRIM(Cast(@nCartonNo AS NVARCHAR( 5))), 0) + '/' + ISNULL(RTRIM(Cast(@nCartonNo AS NVARCHAR( 5))), 0)
            WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @nCartonNo
         END
         ELSE
         BEGIN
            UPDATE #RESULT SET MaxCarton = @nCartonNo
            WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @nCartonNo
         END
      END
      ELSE
      BEGIN
         UPDATE #RESULT SET MaxCarton = @nCartonNo
         WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @nCartonNo
      END
      FETCH NEXT FROM CTN_CUR INTO @nCartonNo
   END
   CLOSE CTN_CUR
   DEALLOCATE CTN_CUR

   IF ISNULL(@c_Orderkey,'') = '' --NJOW01
   BEGIN
      -- SOS# 174296 (Start)
      SET @c_LoadKey      = ''
      SET @c_ConsigneeKey = ''
      SET @c_Company      = ''
      SET @c_Address1     = ''
      SET @c_Address2     = ''
      SET @c_Address3     = ''
      SET @c_City         = ''
      SET @d_DeliveryDate = ''

      SELECT @c_LoadKey = LoadKey
        FROM PackHeader WITH (NOLOCK)
       WHERE PickSlipNo = @c_PickSlipNo

      SELECT  @c_ConsigneeKey = MAX(ISNULL(RTRIM(ConsigneeKey),''))
            , @c_Company      = MAX(ISNULL(RTRIM(C_Company),''))
            , @c_Address1     = MAX(ISNULL(RTRIM(C_Address1),''))
            , @c_Address2     = MAX(ISNULL(RTRIM(C_Address2),''))
            , @c_Address3     = MAX(ISNULL(RTRIM(C_Address3),''))
            , @c_City         = MAX(ISNULL(RTRIM(C_City),''))
            , @d_DeliveryDate = MAX(ISNULL(RTRIM(DeliveryDate),''))
      FROM ORDERS WITH (NOLOCK)
      WHERE LoadKey = @c_LoadKey

      UPDATE #RESULT SET
              ConsigneeKey = @c_ConsigneeKey
            , C_Company    = @c_Company
            , C_Address1   = @c_Address1
            , C_Address2   = @c_Address2
            , C_Address3   = @c_Address3
            , C_City       = @c_City
            , DeliveryDate = @d_DeliveryDate
            , LoadKey      = @c_LoadKey
      WHERE PickSlipNo     = @c_pickslipno
      -- SOS# 174296 (End)
   END

   IF @c_showsku <> 'Y'
   BEGIN
   SELECT PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc             --(Wan01), (Wan03), (Wan04)
      ,  @n_MultiExtOrd                                                                      --(Wan06)
      ,  C_Fax2,showsku,'' as sku, 0 as qty                                                                       --(CS01)    --(CS02)                           
   FROM #RESULT
   END
   ELSE
   BEGIN
    
    CREATE TABLE #RESULT_DET (
       ROWREF INT NOT NULL IDENTITY(1,1) Primary Key,
       PickSlipNo NVARCHAR(10) NULL,
       CartonNo  INT,
       SKU       NVARCHAR(20),
       Qty       INT)
    
   INSERT INTO #RESULT_DET(Pickslipno,cartonno,SKU,Qty)
   SELECT DISTINCT PD.Pickslipno,PD.Cartonno,SKU, SUM(Pd.Qty) 
   FROM PACKDETAIL PD (NOLOCK)
   JOIN #RESULT R (NOLOCK) ON R.Pickslipno = PD.Pickslipno and  R.Cartonno = PD.Cartonno
   WHERE PD.Pickslipno = @c_pickslipno
   GROUP BY PD.Pickslipno,PD.Cartonno,SKU

   
   SELECT R.PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  R.CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc             --(Wan01), (Wan03), (Wan04)
      ,  @n_MultiExtOrd                                                                      --(Wan06)
      ,  C_Fax2,showsku,RDET.SKU,RDET.Qty                                                                       --(CS01)    --(CS02)                           
   FROM #RESULT R
   JOIN #RESULT_DET RDET ON RDET.PickSlipNo = R.Pickslipno and RDET.Cartonno = R.Cartonno


   DROP TABLE #RESULT_DET
   END

   DROP TABLE #RESULT
   
END

GO