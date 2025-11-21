SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_VF_ConsoDespatchTkt_rdt                        */
/* Creation Date: 09-Mar-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16532 - [CN] VF_B2B_Sam_Carton_Label_CR                 */
/*          Copy from isp_nikecn_ConsoDespatchTkt                       */
/*                                                                      */
/* Called By: r_dw_despatch_ticket_VF_rdt                               */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_VF_ConsoDespatchTkt_rdt]
   @c_pickslipno     NVARCHAR(10),
   @n_StartCartonNo  INT = 0,
   @n_EndCartonNo    INT = 0,
   @c_StartLabelNo   NVARCHAR(20) = '',
   @c_EndLabelNo     NVARCHAR(20) = '',
   @c_Type           NVARCHAR(10) = 'D1'
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_externOrderkey         NVARCHAR(50)  
         , @c_LoadKey                NVARCHAR(10)
         , @i_ExtCnt                 INT
         , @i_LineCnt                INT
         , @SQL                      NVARCHAR(1000)
         , @nMaxCartonNo             INT
         , @nCartonNo                INT
         , @nSumPackQty              INT
         , @nSumPickQty              INT
         , @c_ConsigneeKey           NVARCHAR(15)  
         , @c_Company                NVARCHAR(45)
         , @c_Address1               NVARCHAR(150)
         , @c_Address2               NVARCHAR(45)
         , @c_Address3               NVARCHAR(45)
         , @c_City                   NVARCHAR(45)
         , @d_DeliveryDate           DATETIME
         , @c_Orderkey               NVARCHAR(10)  
         , @c_Storerkey              NVARCHAR(15)  
         , @c_ShowQty_Cfg            NVARCHAR(10)  
         , @c_ShowOrdType_Cfg        NVARCHAR(10) 
         , @c_susr4                  NVARCHAR(10) 
         , @c_ShowOrdDoor_Cfg        NVARCHAR(10) 
         , @c_Loc                    NVARCHAR(10) 
         , @c_SOStatus               NVARCHAR(10) 
         , @n_MultiExtOrd            INT          
         , @c_ShowTransportRoute_Cfg NVARCHAR(10)  
         , @c_Fax2                   NVARCHAR(18)  
         , @c_showsku                NVARCHAR(1)   
         , @c_Brand                  NVARCHAR(20)  
         , @n_PrintNextLBL           INT = 0
         , @c_IsConso                NVARCHAR(10) = 'N'
         , @c_DocType                NVARCHAR(1)
         , @c_UserDefine01           NVARCHAR(20)
         , @n_MaxRec                 INT = 0
         , @n_CurrentRec             INT = 0
         , @n_MaxLineno              INT = 6
     
   SET @c_Storerkey  = ''                          
   SET @c_ShowQty_Cfg= ''                          
   SET @c_ShowOrdType_Cfg = ''                     
   SET @c_susr4           = ''                     
   SET @c_ShowOrdDoor_Cfg = ''                     
   SET @c_Loc             = ''                     
   SET @c_SOStatus        = ''                     
   SET @n_MultiExtOrd     = 1                      
   SET @c_ShowTransportRoute_Cfg = ''              
   SET @c_Fax2                   = ''              
   SET @c_showsku                ='N'
   SET @c_Brand                  = ''         

   CREATE TABLE #TMP_D2 (
      Company           NVARCHAR(45)  NULL
    , Externorderkey    NVARCHAR(50)  NULL
    , Notes             NVARCHAR(255) NULL
    , Cartonno          NVARCHAR(10)  NULL
    , Notes2            NVARCHAR(255) NULL
    , SKUCount          INT           NULL
    , Sku               NVARCHAR(20)  NULL
    , Manufacturersku   NVARCHAR(20)  NULL
    , AltSKU            NVARCHAR(20)  NULL
    , Qty               INT           NULL
    , Labelno           NVARCHAR(20)  NULL
    , IsDummy           NVARCHAR(1)   NULL
   )
   
   --Discrete
   SELECT @c_ConsigneeKey = ORDERS.ConsigneeKey
        , @c_Storerkey    = ORDERS.StorerKey
        , @c_DocType      = ORDERS.DocType
        , @c_UserDefine01 = ORDERS.UserDefine01
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PACKHEADER.OrderKey = ORDERS.OrderKey
   WHERE PACKHEADER.PickSlipNo = @c_pickslipno
   	
   --Conso
   IF ISNULL(@c_ConsigneeKey,'') = '' AND ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT @c_ConsigneeKey = MAX(ORDERS.ConsigneeKey)
           , @c_Storerkey    = MAX(ORDERS.StorerKey)
           , @c_DocType      = MAX(ORDERS.DocType)
           , @c_UserDefine01 = MAX(ORDERS.UserDefine01)
      FROM PACKHEADER (NOLOCK)
      JOIN LOADPLANDETAIL (NOLOCK) ON PACKHEADER.Loadkey = LOADPLANDETAIL.Loadkey
      JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.OrderKey = ORDERS.OrderKey
      WHERE PACKHEADER.PickSlipNo = @c_pickslipno
      
      SET @c_IsConso = 'Y'
   END      
   
   --H1 Part - START
   IF @c_Type = 'H1'
   BEGIN
   	IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK)
   	           WHERE CODELKUP.LISTNAME = 'VFSAMLBL'
   	           AND CODELKUP.Code = @c_ConsigneeKey
   	           AND CODELKUP.Storerkey = @c_Storerkey
   	           AND CODELKUP.Short = 'Y') AND @c_UserDefine01 = 'VC15' AND @c_DocType = 'N'
   	   SET @n_PrintNextLBL = 1 
   	
   	IF @n_PrintNextLBL = 1
   	BEGIN
         SELECT @c_pickslipno    AS Pickslipno 
              , @n_StartCartonNo AS StartCartonNo
              , @n_EndCartonNo   AS EndCartonNo
              , @c_StartLabelNo  AS StartLabelNo
              , @c_EndLabelNo    AS EndLabelNo
              , 0                AS PrintNextLBL
         UNION ALL
         SELECT @c_pickslipno    AS Pickslipno 
              , @n_StartCartonNo AS StartCartonNo
              , @n_EndCartonNo   AS EndCartonNo
              , @c_StartLabelNo  AS StartLabelNo
              , @c_EndLabelNo    AS EndLabelNo
              , 1                AS PrintNextLBL
   	END
   	ELSE
   	BEGIN
   	   SELECT @c_pickslipno    AS Pickslipno 
              , @n_StartCartonNo AS StartCartonNo
              , @n_EndCartonNo   AS EndCartonNo
              , @c_StartLabelNo  AS StartLabelNo
              , @c_EndLabelNo    AS EndLabelNo
              , 0                AS PrintNextLBL
   	END
           
      GOTO QUIT_SP
   END
   --H1 Part - END
   
   --D2 Part - START
   IF @c_Type = 'D2' 
   BEGIN
      IF @c_IsConso = 'Y'
      BEGIN
      	INSERT INTO #TMP_D2
         SELECT N'利威格服饰（中国）有限公司' AS Company
              , MAX(OH.Externorderkey) AS Externorderkey
              , MAX(ISNULL(OH.Notes,'')) AS Notes
              , PD.Cartonno
              , MAX(ISNULL(OH.Notes2,'')) AS Notes2
              , COUNT(DISTINCT PD.Sku) AS SKUCount
              , S.Sku
              , S.Manufacturersku
              , S.AltSKU
              , SUM(PD.Qty) AS Qty
              , PD.Labelno
              , 'N'
         FROM PACKHEADER PH (NOLOCK)
         JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
         JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = PD.StorerKey
         WHERE PH.PickSlipNo = @c_pickslipno AND PD.CartonNo BETWEEN @n_StartCartonNo AND @n_EndCartonNo
         GROUP BY PD.Cartonno
                , S.Sku
                , S.Manufacturersku
                , S.AltSKU
                , PD.Labelno
      END
      ELSE
      BEGIN  
      	INSERT INTO #TMP_D2
         SELECT N'利威格服饰（中国）有限公司' AS Company
              , MAX(OH.Externorderkey) AS Externorderkey
              , MAX(ISNULL(OH.Notes,'')) AS Notes
              , PD.Cartonno
              , MAX(ISNULL(OH.Notes2,'')) AS Notes2
              , COUNT(DISTINCT PD.Sku) AS SKUCount
              , S.Sku
              , S.Manufacturersku
              , S.AltSKU
              , SUM(PD.Qty) AS Qty
              , PD.Labelno
              , 'N'
         FROM PACKHEADER PH (NOLOCK)
         JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
         JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = PD.StorerKey
         WHERE PH.PickSlipNo = @c_pickslipno AND PD.CartonNo BETWEEN @n_StartCartonNo AND @n_EndCartonNo
         GROUP BY PD.Cartonno
                , S.Sku
                , S.Manufacturersku
                , S.AltSKU
                , PD.Labelno
      END
      
      --SELECT @n_MaxRec = COUNT(1)                 
      --FROM #TMP_D2                 
             
      --SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno                
                
      --WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)             
      --BEGIN  
      --	INSERT INTO #TMP_D2
      --   SELECT TOP 1 Company        
      --              , Externorderkey 
      --              , Notes          
      --              , CartonNo       
      --              , Notes2         
      --              , NULL       
      --              , NULL            
      --              , NULL
      --              , NULL         
      --              , NULL            
      --              , Labelno        
      --              , 'Y'
      --   FROM #TMP_D2
        
      --   SET @n_CurrentRec = @n_CurrentRec + 1      
      --END            
      
      SELECT *, (Row_Number() OVER (PARTITION BY Cartonno Order BY Cartonno, CASE WHEN ISNULL(SKU,'') = '' THEN 2 ELSE 1 END ) - 1 ) / @n_MaxLineno AS PageNo FROM #TMP_D2
      ORDER BY Cartonno, CASE WHEN ISNULL(SKU,'') = '' THEN 2 ELSE 1 END
      
      GOTO QUIT_SP
   END
   --D2 Part - END
   
   --D1 Part - START
   SELECT @c_Orderkey = Orderkey
         ,@c_Storerkey= ISNULL(RTRIM(Storerkey),'')
   FROM PACKHEADER (NOLOCK)
   WHERE Pickslipno = @c_Pickslipno
   
   SELECT @c_ShowQty_Cfg = ISNULL(RTRIM(SValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Configkey = 'DPTkt_NKCN3_CTNQty'
   
   SELECT @c_ShowOrdType_Cfg = ISNULL(RTRIM(SValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Configkey = 'DPTkt_NKCN3_ORDType'
   
   SELECT @c_susr4 = ISNULL(RTRIM(SUSR4),'')
   FROM STORER WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   
   IF @c_susr4 <> '1028' 
   BEGIN
      SET @c_susr4 = ''
   END

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
         AND   LPLD.LocationCategory = 'STAGING'
         ORDER BY LPLD.LP_LaneNumber
      END
   END

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
   
   SELECT @c_showsku = CASE WHEN ISNULL(Code,'') <> '' THEN 'Y' ELSE 'N' END
   FROM Codelkup (NOLOCK)
   WHERE listname='REPORTCFG'
   AND Code = 'SHOWSKUFIELD'                                        
   AND Long = 'r_dw_despatch_ticket_nikecn3' AND ISNULL(Short,'') <> 'N'    
   AND Storerkey =  @c_Storerkey

   SELECT @c_Brand = CL.long
   FROM CODELKUP AS CL WITH (NOLOCK)
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.UserDefine01 = CL.Code
   WHERE Ord.OrderKey= @c_Orderkey
   AND CL.LISTNAME='BrandList'

   CREATE TABLE #RESULT (
       ROWREF INT NOT NULL IDENTITY(1,1) Primary Key,
       PickSlipNo NVARCHAR(10) NULL,
       LoadKey NVARCHAR(10) NULL,
       [Route] NVARCHAR(10) NULL,
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
      ,ShowQtyCfg NVARCHAR(10) NULL     
      ,OrderType  VARCHAR(10) NULL      
      ,SUSR4      NVARCHAR(20) NULL     
      ,Door       NVARCHAR(10) NULL     
      ,Loc        NVARCHAR(10) NULL     
      ,C_Fax2     NVARCHAR(18) NULL     
      ,ShowSKU    NVARCHAR(1)  NULL     
      ,Brand      NVARCHAR(20) NULL     
      )
      
   CREATE INDEX IX_RESULT_01 on #RESULT ( LoadKey )
   CREATE INDEX IX_RESULT_02 on #RESULT ( CartonNo )

   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      SET @n_MultiExtOrd = 1

      INSERT INTO #RESULT   ( PickSlipNo, LoadKey, [Route], ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc,C_Fax2
                            ,showsku,Brand)                                            
                          
      SELECT PackHeader.PickSlipNo,
            PackHeader.LoadKey,
            PackHeader.[Route],
            MAX(ORDERS.Consigneekey) as ConsigneeKey,
            MAX(Orders.DeliveryDate) as DeliveryDate,
            MAX(Orders.C_Company) as C_Company,
            dbo.Fnc_Wraptext(MAX(Orders.C_Address1) + MAX(Orders.C_Address2) + MAX(Orders.C_Address3),18)  as C_Address1,
            '',
            '',
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
            COUNT(DISTINCT PACKDETAIL.Sku) AS TotalSku, 
            SUM(DISTINCT PACKDETAIL.Qty) AS TotalPcs,   
            MaxCarton = SPACE(10)
         ,  ShowQtyCfg= @c_ShowQty_Cfg             
         ,  OrderType = CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END          
         ,  Plant = @c_Susr4                                                                     
         ,  Door  = ISNULL(RTRIM(ORDERS.Door),'')                                                
         ,  Loc   = @c_Loc                                                                       
         ,  c_Fax2  = @c_Fax2                                                                     
         ,  showsku = @c_showsku                                                                
         ,  brand   = @c_Brand                                                                    
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
               PackHeader.[Route],
               PackDetail.LabelNo,
               PackDetail.CartonNo
           ,  CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END                  
           ,  ISNULL(RTRIM(ORDERS.Door),'')                                                        
   END
   ELSE
   BEGIN
      SET @n_MultiExtOrd = 0

      INSERT INTO #RESULT  ( PickSlipNo, LoadKey, [Route], ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc,C_Fax2 
                            ,showsku,Brand)                                            
      SELECT A.PickSlipNo,
            Orders.LoadKey,
            A.[Route],
            ORDERS.Consigneekey,
            Orders.DeliveryDate,
            Orders.C_Company,
            dbo.Fnc_Wraptext(MAX(Orders.C_Address1) + MAX(Orders.C_Address2) + MAX(Orders.C_Address3),18)  as C_Address1,
            '',
            '',
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
            COUNT(PACKDETAIL.Sku) AS TotalSku,  
            SUM(PACKDETAIL.Qty) AS TotalPcs,    
            MaxCarton = SPACE(10)
         ,  ShowQtyCfg= @c_ShowQty_Cfg              
         ,  OrderType = CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END          
         ,  Plant = @c_Susr4                                                                     
         ,  Door  = CASE WHEN @c_ShowOrdDoor_Cfg = '1'                                           
                         THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                          
         ,  Loc      = @c_Loc                                                                    
         ,  c_Fax2   = @c_Fax2                                                                   
         ,  showsku  = @c_showsku                                                                
         ,  brand    = @c_Brand                                                                   
      FROM Orders Orders WITH (NOLOCK)
      JOIN (
         SELECT DISTINCT OD.OrderKey, OD.Sku, PH.Pickslipno, PH.[Route]
         FROM OrderDetail OD WITH (NOLOCK)
         JOIN PackHeader PH WITH (NOLOCK) ON (OD.OrderKey = PH.OrderKey)
         WHERE PH.Pickslipno = @c_pickslipno
      ) AS A
      ON Orders.OrderKey = A.OrderKey
      JOIN Packdetail Packdetail WITH (NOLOCK) ON (A.Pickslipno = Packdetail.pickslipno AND A.SKU = PackDetail.SKU)
      WHERE A.PickSlipNo = @c_pickslipno
      AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END
      GROUP BY A.PickSlipNo,
               Orders.LoadKey,
               A.[Route],
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
            ,  CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END                   
            ,  CASE WHEN @c_ShowOrdDoor_Cfg = '1' THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                                                
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
                  INSERT INTO #RESULT  ( PickSlipNo, LoadKey, [Route], ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc,C_Fax2
                            ,showsku,Brand)                                           
                  SELECT
                  PackHeader.PickSlipNo,
                  PackHeader.LoadKey,
                  PackHeader.[Route],
                  MAX(ORDERS.Consigneekey) as ConsigneeKey,
                  MAX(Orders.DeliveryDate) as DeliveryDate,
                  MAX(Orders.C_Company) as C_Company,

                  dbo.Fnc_Wraptext(MAX(Orders.C_Address1) + MAX(Orders.C_Address2) + MAX(Orders.C_Address3),18)  as C_Address1,
                  '',
                  '',
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
                  0 AS TotalSku,     
                  0 AS TotalPcs,     
                  MaxCarton = SPACE(80)
               ,  ShowQtyCfg= @c_ShowQty_Cfg     
               ,  OrderType = CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END   
               ,  Plant = @c_Susr4                                                              
               ,  Door  = CASE WHEN @c_ShowOrdDoor_Cfg = '1'                                    
                               THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                   
               ,  Loc   = @c_Loc                                                                
               ,  c_Fax2 = @c_Fax2                                                              
               ,  showsku  = @c_showsku                                                         
               ,  brand   =@c_Brand                                                             
                  FROM PackHeader (NOLOCK),
                  Orders (NOLOCK),
                  LoadplanDetail (NOLOCK)
                  WHERE PackHeader.PickSlipNo = @c_pickslipno AND
                  PackHeader.LoadKey = LoadplanDetail.LoadKey AND
                  Orders.OrderKey = LoadplanDetail.OrderKey
                  GROUP BY PackHeader.PickSlipNo,
                          PackHeader.LoadKey,
                          PackHeader.[Route]
                        , CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END  
                        , CASE WHEN @c_ShowOrdDoor_Cfg = '1'                               
                               THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                                                               
               END
               ELSE
               BEGIN 
                  INSERT INTO #RESULT  ( PickSlipNo, LoadKey, [Route], ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc,C_Fax2     
                            ,showsku,Brand)                                         
                  SELECT
                  PackHeader.PickSlipNo,
                  Orders.LoadKey,
                  PackHeader.[Route],
                  ORDERS.Consigneekey,
                  Orders.DeliveryDate,
                  Orders.C_Company,
                  dbo.Fnc_Wraptext(MAX(Orders.C_Address1) + MAX(Orders.C_Address2) + MAX(Orders.C_Address3),18)  as C_Address1,
                  '',
                  '',
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
                  0 AS TotalSku,     
                  0 AS TotalPcs,    
                  MaxCarton = SPACE(80)
               ,  ShowQtyCfg= @c_ShowQty_Cfg      
               ,  OrderType = CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END 
               ,  Plant = @c_Susr4                                                            
               ,  Door  = CASE WHEN @c_ShowOrdDoor_Cfg = '1'                                  
                               THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                 
               ,  Loc     = @c_Loc                                                              
               ,  c_Fax2  = @c_Fax2                                                            
               ,  showsku = @c_showsku                                                       
               ,  brand   = @c_Brand                                                           
                  FROM PackHeader (NOLOCK)
                  JOIN Orders (NOLOCK) ON Packheader.Orderkey = Orders.Orderkey
                  WHERE PackHeader.PickSlipNo = @c_pickslipno
                  GROUP BY PackHeader.PickSlipNo,
                           PackHeader.LoadKey,
                           PackHeader.[Route],
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
                        ,  CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END    
                        ,  CASE WHEN @c_ShowOrdDoor_Cfg = '1'                                 
                                THEN ISNULL(RTRIM(ORDERS.Door),'') ELSE '' END                                                       
               END
            SET ROWCOUNT 0
         END

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
   ELSE
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
      IF @i_ExtCnt = 10
      BREAK

      IF @i_LineCnt = 5
      BEGIN
         SELECT @i_LineCnt = 0
         SELECT @i_ExtCnt  = @i_ExtCnt + 1
      END

      SELECT @i_LineCnt = @i_LineCnt + 1

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

         IF ISNULL(@c_Orderkey,'') = ''
         BEGIN
            SELECT @c_LoadKey = LoadKey FROM PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo

            SELECT @nSumPickQty = SUM(PD.QTY) FROM PickDetail PD WITH (NOLOCK)
            JOIN Orders O (nolock) ON (O.StorerKey = PD.StorerKey AND O.OrderKey = PD.OrderKey)
            WHERE O.LoadKey = @c_LoadKey
         END
         ELSE
         BEGIN 
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

   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
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
   END
   
   IF @c_showsku <> 'Y'
   BEGIN
      SELECT PickSlipNo, LoadKey, [Route], ConsigneeKey, DeliveryDate,
                               C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                               xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                               ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                               ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                               MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc,
                               @n_MultiExtOrd, 
                               C_Fax2,Brand                                                                 
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
      
      
      SELECT R.PickSlipNo, LoadKey, [Route], ConsigneeKey, DeliveryDate,
             C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
             xDockLane,  LabelNo,  R.CartonNo,  ExtOrder1,  ExtOrder2,
             ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
             ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
             MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Door, Loc,      
             @n_MultiExtOrd,                                                                                                     
             C_Fax2,R.Brand                                                             
      FROM #RESULT R
      JOIN #RESULT_DET RDET ON RDET.PickSlipNo = R.Pickslipno and RDET.Cartonno = R.Cartonno

   END
   --D1 Part - END
   
QUIT_SP:
   IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL
      DROP TABLE #RESULT
      
   IF OBJECT_ID('tempdb..#RESULT_DET') IS NOT NULL
      DROP TABLE #RESULT_DET
      
   IF OBJECT_ID('tempdb..#TMP_D2') IS NOT NULL
      DROP TABLE #TMP_D2
      
END

GO