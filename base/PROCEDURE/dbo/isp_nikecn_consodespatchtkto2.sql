SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_nikecn_ConsoDespatchTktO2                      */
/* Creation Date: 25-Sep-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15246 - CN NIKE O2 Shipping label for transfer order    */
/*                                                                      */
/* Called By: r_dw_despatch_ticket_nikecn_o2                            */
/*            modified from isp_nikecn_ConsoDespatchTkt9                */
/*                          r_dw_despatch_ticket_nikecn9                */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_nikecn_ConsoDespatchTktO2]
   @c_pickslipno     NVARCHAR(10),
   @n_StartCartonNo  INT = 0,
   @n_EndCartonNo    INT = 0,
   @c_StartLabelNo   NVARCHAR(20) = '',
   @c_EndLabelNo     NVARCHAR(20) = '',
   @c_RefNo          NVARCHAR(20) = ''         
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_externOrderkey            NVARCHAR(30)
          ,@c_LoadKey                   NVARCHAR(10)
          ,@i_ExtCnt                    INT
          ,@i_LineCnt                   INT
          ,@SQL                         NVARCHAR(1000)
          ,@nMaxCartonNo                INT
          ,@nCartonNo                   INT
          ,@nSumPackQty                 INT
          ,@nSumPickQty                 INT
          ,@c_ConsigneeKey              NVARCHAR(15)
          ,@c_Company                   NVARCHAR(45)
          ,@c_Address1                  NVARCHAR(45)
          ,@c_Address2                  NVARCHAR(45)
          ,@c_Address3                  NVARCHAR(45)
          ,@c_City                      NVARCHAR(45)
          ,@d_DeliveryDate              DATETIME
          ,@c_Orderkey                  NVARCHAR(10)
          ,@c_Storerkey                 NVARCHAR(15)
          ,@c_ShowQty_Cfg               NVARCHAR(10)
          ,@c_ShowOrdType_Cfg           NVARCHAR(10)
          ,@c_susr4                     NVARCHAR(10)
          ,@c_Stop                      NVARCHAR(10)
          ,@c_showfield                 NVARCHAR(1) 
          ,@c_showCRD                   NVARCHAR(1) 
          ,@c_ShippingFilterByRefNo     NVARCHAR(20)
          ,@nRowRef                     INT
          ,@nExcludeCarton              INT 
          ,@n_GetCartonNo               INT
          ,@n_cntRefno                  INT
          ,@c_GetPSlipno                NVARCHAR(20)
          ,@c_GetRefno                  NVARCHAR(20)
          ,@c_site                      NVARCHAR(30)
          ,@n_GetMaxCarton              INT
          ,@c_facility                  NVARCHAR(10)
         
   SET @c_Storerkey = ''             
   SET @c_ShowQty_Cfg = ''           
   SET @c_ShowOrdType_Cfg = ''       
   SET @c_susr4 = ''                 
   SET @c_showfield = 'N'            
   SET @c_showCRD = ''               
   SET @c_ShippingFilterByRefNo = '' 
   SET @nExcludeCarton = 1

   SELECT @c_Orderkey = Orderkey 
         ,@c_Storerkey     = ISNULL(RTRIM(Storerkey) ,'')
   FROM   PACKHEADER(NOLOCK)
   WHERE  Pickslipno       = @c_Pickslipno

   SELECT @c_ShowQty_Cfg = ISNULL(RTRIM(SValue) ,'')
   FROM   STORERCONFIG WITH (NOLOCK)
   WHERE  Storerkey         = @c_Storerkey
          AND Configkey     = 'DPTkt_NKCN3_CTNQty'

   SELECT @c_ShowOrdType_Cfg = ISNULL(RTRIM(SValue) ,'')
   FROM   STORERCONFIG WITH (NOLOCK)
   WHERE  Storerkey         = @c_Storerkey
          AND Configkey     = 'DPTkt_NKCN3_ORDType'

   SELECT @c_susr4 = ISNULL(RTRIM(SUSR4) ,'')
   FROM   STORER WITH (NOLOCK)
   WHERE  Storerkey = @c_Storerkey

   SELECT @c_showField = CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END
   FROM Codelkup CLR (NOLOCK)
   WHERE CLR.Storerkey = @c_Storerkey
   AND CLR.Code = 'SHOWFIELD'
   AND CLR.Listname = 'REPORTCFG'
   AND CLR.Long = 'r_dw_despatch_ticket_nikecn_o2' AND ISNULL(CLR.Short,'') <> 'N'
   
   SELECT @c_ShippingFilterByRefNo = Code2
   FROM dbo.CODELKUP (NOLOCK) 
   WHERE Listname = 'REPORTCFG'
   AND code = 'ShippingFilterByRefNo'
   AND Storerkey = @c_Storerkey
   AND Long = 'r_dw_despatch_ticket_nikecn_o2'

   CREATE TABLE #RESULT
   (
	   ROWREF             INT NOT NULL IDENTITY(1 ,1) PRIMARY KEY
      ,PickSlipNo         NVARCHAR(10) NULL
      ,LoadKey            NVARCHAR(10) NULL
      ,ROUTE              NVARCHAR(10) NULL
      ,ConsigneeKey       NVARCHAR(15) NULL
      ,DeliveryDate       DATETIME NULL
      ,C_Company          NVARCHAR(45) NULL
      ,C_Address1         NVARCHAR(45) NULL
      ,C_Address2         NVARCHAR(45) NULL
      ,C_Address3         NVARCHAR(45) NULL
      ,C_City             NVARCHAR(45) NULL
      ,xDockLane          NVARCHAR(10) NULL
      ,LabelNo            NVARCHAR(20) NULL
      ,CartonNo           INT NULL
      ,ExtOrder1          NVARCHAR(80) NULL
      ,ExtOrder2          NVARCHAR(80) NULL
      ,ExtOrder3          NVARCHAR(80) NULL
      ,ExtOrder4          NVARCHAR(80) NULL
      ,ExtOrder5          NVARCHAR(80) NULL
      ,ExtOrder6          NVARCHAR(80) NULL
      ,ExtOrder7          NVARCHAR(80) NULL
      ,ExtOrder8          NVARCHAR(80) NULL
      ,ExtOrder9          NVARCHAR(80) NULL
      ,ExtOrder10         NVARCHAR(80) NULL
      ,TotalSku           INT NULL
      ,TotalPcs           INT NULL
      ,MaxCarton          NVARCHAR(10) NULL
      ,ShowQtyCfg         NVARCHAR(10) NULL
      ,OrderType          NVARCHAR(10) NULL
      ,SUSR4              NVARCHAR(20) NULL
      ,STOP               NVARCHAR(10) NULL
      ,ShowField          NVARCHAR(1) NULL 
      ,ShowCRD            NVARCHAR(1) NULL 
      ,CRD                NVARCHAR(10) NULL
      ,ExtraInfo          NVARCHAR(20) NULL
      ,TotalQtyPacked     INT NULL
      ,RefNo              NVARCHAR(20) NULL
      ,RefNo2             NVARCHAR(30) NULL
      ,SITELoadkey        NVARCHAR(30) NULL
      ,UserDefine10       NVARCHAR(50) NULL
      ,B_Company          NVARCHAR(45) NULL
      ,NIKESoldTo         NVARCHAR(50) NULL
      ,C_Contact1         NVARCHAR(45) NULL
      ,C_Phone1           NVARCHAR(45) NULL
      ,C_Address4         NVARCHAR(45) NULL
      ,FUserDefine07      NVARCHAR(30) NULL
      ,ExternPOKey        NVARCHAR(50) NULL
   )

   CREATE INDEX IX_RESULT_01 on #RESULT ( LoadKey )
   CREATE INDEX IX_RESULT_02 on #RESULT ( CartonNo )
   
   CREATE TABLE #CTNRESULT (
      PickSlipNo NVARCHAR(10) NULL,
      RefNo      NVARCHAR(20) NULL,        
      RefNo2     NVARCHAR(30) NULL,       
      PCartonno  INT,
      CtnSeq     INT,
      MaxCtn     INT    )
   
   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      SET @n_cntRefno = 0
      
      SELECT @n_cntRefno = COUNT(DISTINCT c.code)
      FROM PackDetail (NOLOCK)
      JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
      JOIN ORDERS (NOLOCK) ON ( Orders.loadkey = PackHeader.loadkey )                            
      JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
      LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
      LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' 
           AND C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
      WHERE PackHeader.PickSlipNo = @c_pickslipno
      AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END

      INSERT INTO #RESULT   ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,   
                            ShowField,ShowCRD,CRD, ExtraInfo ,TotalQtyPacked                                    
                           , RefNo, RefNo2,SITELoadkey
                           , UserDefine10, B_Company
                           , NIKESoldTo    
                           , C_Contact1    
                           , C_Phone1      
                           , C_Address4    
                           , FUserDefine07, ExternPOKey                     
                           )

      SELECT PackHeader.PickSlipNo,
            PackHeader.LoadKey,
            PackHeader.Route,
            MAX(ORDERS.Consigneekey) as ConsigneeKey,
            MAX(Orders.DeliveryDate) as DeliveryDate,
            MAX(Orders.C_Company) as C_Company,
            MAX(Orders.C_Address1) as C_Address1,
            MAX(Orders.C_Address2) as C_Address2,
            MAX(Orders.C_Address3) as C_Address3,
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
         ,  MAX(Orders.Stop) as Stop
         ,  ShowField = @c_showField
         , ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
                      AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CONVERT(INT,ORDERS.Userdefine01)),111),'/',''),8))    --Cs03
                      <  LEFT(ORDERS.ExternPOKey,8))) THEN
                      CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
                      'Y' ELSE 'N' END
                      ELSE 'N' END
         ,   CRD = CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
                   CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                           --CS03
                   CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))                 --Cs03
               THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.ExternPOKey,4),'-','')) + 1))) + '-'+ substring(ORDERS.ExternPOKey,5,2)
                   + '-' + substring(ORDERS.ExternPOKey,7,2) ELSE
              CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.ExternPOKey,4),'-',''))))) + '-'+ substring(ORDERS.ExternPOKey,5,2)
                  + '-' + substring(ORDERS.ExternPOKey,7,2) END
                   ELSE '' END
                   ELSE '' END
         , CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
                WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                ELSE '' END AS ExtraInfo           
         ,  TotalQtyPacked = (SELECT ISNULL(SUM(PD.Qty),0)                       --(Wan04)
                                    FROM PACKDETAIL PD WITH (NOLOCK)             --(Wan04)
                                    WHERE PD.PickSlipNo = PACKHEADER.PickSlipNo  --(Wan04)    
                                    AND PD.CartonNo = PACKDETAIL.CartonNo        --(Wan04)
         )
         , Packdetail.RefNo, PackDetail.RefNo2                                   --(CS04)
         , CASE WHEN @n_cntRefno >1 THEN Packdetail.RefNo + '-' +PackHeader.LoadKey ELSE PackHeader.LoadKey END SITELoadkey   --(CS05)
         , CASE WHEN ISDATE(MAX(Orders.UserDefine10)) = 1 THEN RIGHT('00' + CAST(DATEPART(mm,MAX(Orders.UserDefine10)) AS NVARCHAR(2)), 2) +
         	                                                   N'月' + 
         	                                                   RIGHT('00' + CAST(DATEPART(dd,MAX(Orders.UserDefine10)) AS NVARCHAR(2)), 2) +
         	                                                   + N'日'
                                                           ELSE '' END AS UserDefine10
         , MAX(ISNULL(ORDERS.B_Company,'')) AS B_Company
         , MAX(ISNULL(CL.Notes,'')) AS NIKESoldTo     
         , MAX(ISNULL(ORDERS.C_Contact1,'')) AS C_Contact1
         , MAX(ISNULL(ORDERS.C_Phone1,'')) AS C_Phone1    
         , MAX(ISNULL(ORDERS.C_Address4,'')) AS C_Address4
         , ISNULL(F.UserDefine07,'') AS FUserDefine07
         , MAX(ISNULL(ORDERS.ExternPOKey,'')) AS ExternPOKey
      FROM Orders Orders WITH (NOLOCK)
      JOIN OrderDetail OrderDetail WITH (NOLOCK) ON Orders.OrderKey = OrderDetail.OrderKey
      JOIN Packheader Packheader WITH (NOLOCK) ON (Orders.LoadKey = Packheader.LoadKey)                                     
      JOIN Packdetail Packdetail WITH (NOLOCK) ON (Packheader.Pickslipno = Packdetail.pickslipno AND OrderDetail.SKU = PackDetail.SKU)
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = Orders.consigneekey)    
      LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'NIKESoldTo' AND CL.Storerkey = ORDERS.StorerKey AND CL.Code = ORDERS.B_Company   
      LEFT JOIN FACILITY F (NOLOCK) ON ORDERS.Facility = F.Facility                                           
      WHERE PackHeader.PickSlipNo = @c_pickslipno
      AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END
      AND 1 = CASE WHEN @c_RefNo <> '' AND RefNo = @c_RefNo THEN 1
                   WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' AND RefNo <> @c_ShippingFilterByRefNo  THEN 1
                   WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' and Refno = '' AND RefNo <> @c_ShippingFilterByRefNo THEN  1
                   WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo = '' THEN 1 ELSE 0 END                                   
      GROUP BY PackHeader.PickSlipNo,
               PackHeader.LoadKey,
               PackHeader.Route,
               PackDetail.LabelNo,
               PackDetail.CartonNo
           ,  CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END              
           ,  CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
          AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CONVERT(INT,ORDERS.Userdefine01)),111),'/',''),8)) 
          <  LEFT(ORDERS.ExternPOKey,8))) THEN
          CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
          'Y' ELSE 'N' END
          ELSE 'N' END  
           ,  CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
          CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                          
          CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))                
          THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.ExternPOKey,4),'-','')) + 1))) + '-'+ substring(ORDERS.ExternPOKey,5,2)
          + '-' + substring(ORDERS.ExternPOKey,7,2) ELSE
          CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.ExternPOKey,4),'-',''))))) + '-'+ substring(ORDERS.ExternPOKey,5,2)
          + '-' + substring(ORDERS.ExternPOKey,7,2) END
          ELSE '' END
          ELSE '' END   
           ,  STORER.SUSR1                                                                  
         , CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
                WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                ELSE '' END       
           , Packdetail.RefNo, PackDetail.RefNo2 
           , ISNULL(F.UserDefine07,'')                                          
           
           
   END
   ELSE
   BEGIN  --NJOW01
      SET @n_cntRefno = 0
      
      SELECT @n_cntRefno = COUNT(DISTINCT c.code)
          FROM ORDERS (NOLOCK)
          JOIN PackDetail (NOLOCK) ON ( ORDERS.StorerKey = PackDetail.StorerKey )
          JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo
                                    AND Packheader.Orderkey = Orders.Orderkey
                                    AND Packheader.Loadkey = Orders.Loadkey
                                    AND Packheader.Consigneekey = Orders.Consigneekey )
          LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
          LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
          LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND
          C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
          WHERE PackHeader.PickSlipNo = @c_pickslipno
          AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo = 0 THEN 9999 ELSE @n_EndCartonNo END
      
      INSERT INTO #RESULT  ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,   
                            ShowField,ShowCRD,CRD, ExtraInfo                  
                           ,TotalQtyPacked                                    
                           ,RefNo, RefNo2,SITELoadkey           
                           ,UserDefine10, B_Company 
                           ,NIKESoldTo    
                           ,C_Contact1    
                           ,C_Phone1      
                           ,C_Address4    
                           ,FUserDefine07, ExternPOKey              
                           )
      SELECT A.PickSlipNo,
            Orders.LoadKey,
            A.Route,
            ORDERS.Consigneekey,
            Orders.DeliveryDate,
            Orders.C_Company,
            Orders.C_Address1,
            Orders.C_Address2,
            Orders.C_Address3,
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
         ,  Orders.Stop                                                                
         ,  ShowField = @c_showField
         , ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
                      AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CONVERT(INT,ORDERS.Userdefine01)),111),'/',''),8))         --Cs03
                      <  LEFT(ORDERS.ExternPOKey,8))) THEN
                      CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
                      'Y' ELSE 'N' END
                      ELSE 'N' END
         ,   CRD = CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
                   CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                      --CS03
                   CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))            --CS03
                   THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)   --CS03
                   + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE
                   CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)             --CS03
                   + '-' + substring(ORDERS.ExternPOKey,3,2) END
                   ELSE '' END
                   ELSE '' END
        , CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L'  AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
                WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                ELSE '' END AS ExtraInfo        
         , TotalQtyPacked = (SELECT ISNULL(SUM(PD.Qty),0)          
                     FROM PACKDETAIL PD WITH (NOLOCK)       
         WHERE PD.PickSlipNo = A.PickSlipNo           
                     AND PD.CartonNo = PACKDETAIL.CartonNo         
                     )                                             
        , Packdetail.RefNo, PackDetail.RefNo2                      
        , CASE WHEN @n_cntRefno > 1 THEN Packdetail.RefNo + '-' + Orders.LoadKey ELSE Orders.LoadKey END AS Siteloadkey   
        , CASE WHEN ISDATE(MAX(Orders.UserDefine10)) = 1 THEN RIGHT('00' + CAST(DATEPART(mm,MAX(Orders.UserDefine10)) AS NVARCHAR(2)), 2) +
         	                                                   N'月' + 
         	                                                   RIGHT('00' + CAST(DATEPART(dd,MAX(Orders.UserDefine10)) AS NVARCHAR(2)), 2) +
         	                                                   + N'日'
                                                          ELSE '' END AS UserDefine10
        , MAX(ISNULL(ORDERS.B_Company,'')) AS B_Company
        , MAX(ISNULL(CL.Notes,'')) AS NIKESoldTo     
        , MAX(ISNULL(ORDERS.C_Contact1,'')) AS C_Contact1
        , MAX(ISNULL(ORDERS.C_Phone1,'')) AS C_Phone1    
        , MAX(ISNULL(ORDERS.C_Address4,'')) AS C_Address4
        , ISNULL(F.UserDefine07,'') AS FUserDefine07
        , MAX(ISNULL(ORDERS.ExternPOKey,'')) AS ExternPOKey
      FROM Orders Orders WITH (NOLOCK)
      JOIN (
      SELECT DISTINCT OD.OrderKey, OD.Sku, PH.Pickslipno, PH.Route
      FROM OrderDetail OD WITH (NOLOCK)
      JOIN PackHeader PH WITH (NOLOCK) ON (OD.OrderKey = PH.OrderKey)   
      WHERE PH.Pickslipno = @c_pickslipno
      ) AS A
      ON Orders.OrderKey = A.OrderKey
      JOIN Packdetail Packdetail WITH (NOLOCK) ON (A.Pickslipno = Packdetail.pickslipno AND A.SKU = PackDetail.SKU)
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = Orders.consigneekey)
      LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'NIKESoldTo' AND CL.Storerkey = ORDERS.StorerKey AND CL.Short = ORDERS.B_Company   
      LEFT JOIN FACILITY F (NOLOCK) ON ORDERS.Facility = F.Facility
      WHERE A.PickSlipNo = @c_pickslipno
      AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END
       AND 1 = CASE WHEN @c_RefNo <> '' AND RefNo = @c_RefNo THEN 1
               WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' AND RefNo <> @c_ShippingFilterByRefNo THEN 1
               WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' and Refno = '' AND RefNo <> @c_ShippingFilterByRefNo THEN  1
               WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo = '' THEN 1 ELSE 0 END                       
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
               Orders.LoadKey,
               CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END,
               Orders.Stop,                     
               CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
          AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CONVERT(INT,ORDERS.Userdefine01)),111),'/',''),8))  
          <  LEFT(ORDERS.ExternPOKey,8))) THEN                                                                                                
          CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN                                                                              
          'Y' ELSE 'N' END                                                                                                                    
          ELSE 'N' END,                                                                                                                       
                CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN                                                                      
          CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                           
          CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))                 
          THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)        
          + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE                                                                                      
          CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)                 
          + '-' + substring(ORDERS.ExternPOKey,3,2) END                                                                                       
          ELSE '' END
          ELSE '' END,   
               STORER.SUSR1                                                                        
         , CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
                WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
                WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                ELSE '' END                  
     , Packdetail.RefNo, PackDetail.RefNo2, ISNULL(F.UserDefine07,'')
   END
   
   DECLARE @nCartonIndex int

   IF @n_StartCartonNo <> 0 AND  @n_EndCartonNo <> 0
   BEGIN
      SET @nCartonIndex = @n_StartCartonNo
      WHILE @nCartonIndex <= @n_EndCartonNo
      BEGIN
      IF NOT EXISTS(SELECT 1 FROM #RESULT
                    WHERE PickSlipNo = @c_pickslipno
                    AND CartonNo = @nCartonIndex
      )
         BEGIN
            SET ROWCOUNT 1
               IF ISNULL(@c_Orderkey,'') = ''
               BEGIN
                  INSERT INTO #RESULT  ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,          
                            ShowField,ShowCRD,CRD, ExtraInfo 
                           ,TotalQtyPacked                                           
                           ) 
                  SELECT
                  PackHeader.PickSlipNo,
                  PackHeader.LoadKey,
                  PackHeader.Route,
                  MAX(ORDERS.Consigneekey) as ConsigneeKey,
                  MAX(Orders.DeliveryDate) as DeliveryDate,
                  MAX(Orders.C_Company) as C_Company,
                  MAX(Orders.C_Address1) as C_Address1,
                  MAX(Orders.C_Address2) as C_Address2,
                  MAX(Orders.C_Address3) as C_Address3,
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
               ,  MAX(Orders.Stop) as Stop
              ,  ShowField = @c_showField
              ,  ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
                            AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CONVERT(INT,ORDERS.Userdefine01)),111),'/',''),8))    --CS03
                            <  LEFT(ORDERS.ExternPOKey,8))) THEN
                            CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
                            'Y' ELSE 'N' END
                            ELSE 'N' END
              ,   CRD = CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
                   CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN
                   CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))
                   THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)
                   + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE
                   CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)                           --Cs03
                   + '-' + substring(ORDERS.ExternPOKey,3,2) END
                   ELSE '' END
                   ELSE '' END                   
            , CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
             WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
             WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
             WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
             WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
             WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
             WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
             ELSE '' END AS ExtraInfo                
             ,  0 AS TotalQtyPacked             
             FROM PackHeader (NOLOCK)
			 JOIN Orders (NOLOCK) ON Orders.loadkey = PackHeader.loadkey       
			 LEFT JOIN STORER (NOLOCK) ON STORER.StorerKey = Orders.ConsigneeKey
			 WHERE PackHeader.PickSlipNo = @c_pickslipno 
			 GROUP BY PackHeader.PickSlipNo,
					PackHeader.LoadKey,
					PackHeader.Route,
					CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END,      
					CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
                  AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CONVERT(INT,ORDERS.Userdefine01)),111),'/',''),8))    --CS03
                  <  LEFT(ORDERS.ExternPOKey,8))) THEN
                  CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
                  'Y' ELSE 'N' END
                  ELSE 'N' END, 
                        CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
                  CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN
                  CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))
                  THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)
                  + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE
                  CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)                        --CS03
                  + '-' + substring(ORDERS.ExternPOKey,3,2) END
                  ELSE '' END
                  ELSE '' END,   
                  STORER.SUSR1    
              , CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
               WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
               WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
               WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
               WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
               WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
               WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
               ELSE '' END        

            END
              ELSE
               BEGIN
                  INSERT INTO #RESULT  ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,     
                            ShowField,ShowCRD,CRD, ExtraInfo                                
                           ,TotalQtyPacked                                                                                 
                           )
                  SELECT
                  PackHeader.PickSlipNo,
                  Orders.LoadKey,
                  PackHeader.Route,
                  ORDERS.Consigneekey,
                  Orders.DeliveryDate,
                  Orders.C_Company,
                  Orders.C_Address1,
                  Orders.C_Address2,
                  Orders.C_Address3,
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
               ,  Orders.Stop                                                               
               ,  ShowField = @c_showField
               ,  ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
                            AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CONVERT(INT,ORDERS.Userdefine01)),111),'/',''),8))         --CS03
                            <  LEFT(ORDERS.ExternPOKey,8))) THEN
                            CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
                            'Y' ELSE 'N' END
                            ELSE 'N' END
              ,   CRD =  CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
                         CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN
                         CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))
                         THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)
                         + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE
                         CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)                 
                         + '-' + substring(ORDERS.ExternPOKey,3,2) END
                         ELSE '' END
                         ELSE '' END
                , CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
             WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
             WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
             WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
             WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
             WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
             WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
             ELSE '' END AS ExtraInfo        
			,  0 AS TotalQtyPacked        
			FROM PackHeader (NOLOCK)
			JOIN Orders (NOLOCK) ON Packheader.Orderkey = Orders.Orderkey
			LEFT JOIN STORER (NOLOCK) ON (STORER.StorerKey = Orders.ConsigneeKey)               
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
					Orders.LoadKey,
					CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END,          
					Orders.Stop,
					CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
                  AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CONVERT(INT,ORDERS.Userdefine01)),111),'/',''),8))       
                  <  LEFT(ORDERS.ExternPOKey,8))) THEN
                  CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
                  'Y' ELSE 'N' END
                  ELSE 'N' END,  
                        CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
                  CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN
                  CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))
                  THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)
                  + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE
                  CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)                     
                  + '-' + substring(ORDERS.ExternPOKey,3,2) END 
                  ELSE '' END
                  ELSE '' END,   
                           STORER.SUSR1     
                      , CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                    WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                    WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
                    WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
                    WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
                    WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                    WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                    ELSE '' END     
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
      
      SELECT @i_ExtCnt  = @i_ExtCnt + 1
      SELECT @i_LineCnt = @i_LineCnt + 1
      SELECT @SQL = "UPDATE #RESULT SET ExtOrder" + RTRIM(LTRIM(@i_LineCnt)) + " = '" + RTRIM(LTRIM(@c_externOrderkey)) + "' "
                     + "WHERE Pickslipno = '" + RTRIM(@c_pickslipno) + "' AND Loadkey = '" + RTRIM(@c_LoadKey) + "'"

      EXEC (@SQL)

      FETCH NEXT FROM Ext_cur INTO @c_externOrderkey, @c_LoadKey
   END
   CLOSE Ext_cur
   DEALLOCATE Ext_cur

   SET @nSumPackQty = 0
   SET @nSumPickQty = 0
   SET @nExcludeCarton = 1
   
   INSERT INTO #CTNRESULT ( PickSlipNo, RefNo, RefNo2, PCartonno, CtnSeq, MaxCtn )
   SELECT DISTINCT PickSlipNo,RefNo,refno2,cartonno,Row_number() OVER (PARTITION BY PickSlipNo,RefNo ORDER BY cartonno),0
   FROM packdetail (NOLOCK)
   WHERE PickSlipNo=@c_PickSlipNo 
   GROUP BY  PickSlipNo,RefNo,refno2,cartonno
   ORDER BY CartonNo

    IF @c_ShippingFilterByRefNo = ''
    BEGIN
      SELECT @nMaxCartonNo = MAX(CartonNo) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo 
    END
    ELSE
    BEGIN      
      SET @nMaxCartonNo = 0
    
      DECLARE CUR_SITE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT DISTINCT Pickslipno,refno   
       FROM   #CTNRESULT   
       WHERE Pickslipno = @c_pickslipno
  
      OPEN CUR_SITE   
     
      FETCH NEXT FROM CUR_SITE INTO @c_GetPSlipno,@c_GetRefno    
     
      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         SELECT @nMaxCartonNo = CASE WHEN @c_ShippingFilterByRefNo <> '' 
                                     AND @c_RefNo <> '' 
                                     AND convert(int,RefNo2) <> '' 
                                     AND RefNo <> @c_ShippingFilterByRefNo  
                                     THEN COUNT(DISTINCT  CONVERT(INT,RefNo2)) 
                                     ELSE MAX(CONVERT(INT,CtnSeq)) 
                                END 
         FROM #CTNRESULT WITH (NOLOCK) 
         WHERE PickSlipNo = @c_GetPSlipno 
         AND refno=@c_GetRefno   
         AND 1 = CASE WHEN @c_RefNo <> '' AND RefNo = @c_RefNo THEN 1
                      WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' AND RefNo <> @c_ShippingFilterByRefNo THEN 1
                      WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo = '' THEN 1 
                      ELSE 0 
                 END
         GROUP BY PCartonno,RefNo,convert(int,RefNo2)
   
         UPDATE #CTNRESULT
         SET MaxCtn = @nMaxCartonNo
         WHERE pickslipno = @c_GetPSlipno
         AND refno = @c_GetRefno
   
         SET @nMaxCartonNo = 0
   
         FETCH NEXT FROM CUR_SITE INTO @c_GetPSlipno,@c_GetRefno   
      END   
  END                 
                
  DECLARE CTN_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    SELECT CASE WHEN @c_ShippingFilterByRefNo <> '' and RefNo2 <> '' THEN CONVERT(INT,RefNo2)                   
    ELSE CartonNo  END, 
    ROWREF,refno
    FROM #RESULT WITH (NOLOCK)
    WHERE PickSlipNo = @c_PickSlipNo
    AND 1 = CASE WHEN @c_RefNo <> '' AND RefNo = @c_RefNo THEN 1
          WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' AND RefNo <> @c_ShippingFilterByRefNo THEN 1
         WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' and Refno = '' AND RefNo <> @c_ShippingFilterByRefNo THEN  1
        WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo = '' THEN 1 ELSE 0 END
   ORDER BY 1                
                                                              
   OPEN CTN_CUR
   FETCH NEXT FROM CTN_CUR INTO @nCartonNo , @nRowRef ,@c_site

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_GetCartonNo = 0   
      SET @n_GetMaxCarton = 1
    
      IF @c_ShippingFilterByRefNo <> ''
      BEGIN
         SELECT @n_GetCartonNo = CtnSeq
               ,@n_GetMaxCarton = CONVERT(INT,MaxCtn)
         FROM #CTNRESULT
         WHERE PickSlipNo=@c_pickslipno
         AND CtnSeq = @nCartonNo
         AND refno=@c_site
      END
      ELSE
      BEGIN
         SET @n_GetCartonNo = @nCartonNo
         
         SELECT @n_GetMaxCarton = MAX(CartonNo)
         FROM PACKDETAIL (NOLOCK)
         WHERE PickSlipNo = @c_pickslipno
      END 

      IF @n_GetCartonNo = @n_GetMaxCarton
      BEGIN
         SET @nSumPackQty = 0
         SET @nSumPickQty = 0
         
         SELECT @nSumPackQty = SUM(QTY) FROM PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
         AND refno = @c_site 

         IF ISNULL(@c_Orderkey,'') = ''
         BEGIN
            SELECT @c_LoadKey = LoadKey 
            FROM PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo

				SET @c_facility = ''

				SELECT @c_facility = Facility
				FROM LOADPLAN WITH (NOLOCK)
				WHERE loadkey = @c_LoadKey
				 
				SELECT @nSumPickQty =  SUM(PD.QTY) 
            FROM     LoadPlanDetail ld WITH (NOLOCK)  
            JOIN Orders O WITH (NOLOCK) ON  ld.OrderKey = O.OrderKey
            JOIN Orderdetail od WITH (NOLOCK) ON  O.OrderKey = od.OrderKey
            JOIN  PICKDETAIL pd WITH (NOLOCK) ON pd.OrderKey = od.OrderKey and pd.OrderLineNumber = od.OrderLineNumber
            JOIN  LOC LOC (NOLOCK) ON LOC.Loc = pd.Loc
            WHERE  LD.LoadKey = @c_LoadKey   AND LOC.facility = @c_facility
            AND EXISTS(SELECT 1
                FROM  CODELKUP cl(NOLOCK) 
                WHERE cl.LISTNAME = N'ALLSorting' 
                AND cl.Code = @c_site 
                AND cl.code2 = LOC.PickZone 
                AND cl.Storerkey = O.Storerkey) 
         END
         ELSE
         BEGIN 
            SELECT @nSumPickQty = SUM(PD.QTY)
            FROM PickDetail PD WITH (NOLOCK)
            WHERE PD.Orderkey = @c_Orderkey
         END
      
         IF  @n_GetCartonNo = @n_GetMaxCarton AND @nSumPackQty = @nSumPickQty
         BEGIN
            UPDATE #RESULT SET MaxCarton = ISNULL(RTRIM(Cast(@n_GetCartonNo AS NVARCHAR( 5))), 0) 
                     + '/' + ISNULL(RTRIM(Cast(@n_GetCartonNo AS NVARCHAR( 5))), 0)
            WHERE ROWREF = @nRowRef 
         END
         ELSE
         BEGIN
            UPDATE #RESULT SET MaxCarton = @n_GetCartonNo
            WHERE ROWREF = @nRowRef 
         END
      END
      ELSE
      BEGIN
         UPDATE #RESULT SET MaxCarton = @n_GetCartonNo
         WHERE ROWREF = @nRowRef                               
      END
      FETCH NEXT FROM CTN_CUR INTO @nCartonNo, @nRowRef  ,@c_site 
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
      SET @c_Stop         = ''

      SELECT @c_LoadKey = LoadKey
      FROM PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

      SELECT @c_ConsigneeKey = MAX(ISNULL(RTRIM(ConsigneeKey),''))
            , @c_Company      = MAX(ISNULL(RTRIM(C_Company),''))
            , @c_Address1     = MAX(ISNULL(RTRIM(C_Address1),''))
            , @c_Address2     = MAX(ISNULL(RTRIM(C_Address2),''))
            , @c_Address3     = MAX(ISNULL(RTRIM(C_Address3),''))
            , @c_City         = MAX(ISNULL(RTRIM(C_City),''))
            , @d_DeliveryDate = MAX(ISNULL(RTRIM(DeliveryDate),''))
            , @c_Stop         = MAX(ISNULL(RTRIM(Stop),''))
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
            , Stop         = @c_Stop
      WHERE PickSlipNo     = @c_pickslipno
   END
   
   SELECT PickSlipNo, LoadKey, [Route], ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, [Stop],
                            ShowField,ShowCRD,CRD, ExtraInfo               
                           ,TotalQtyPacked,RefNo, RefNo2, SITELoadkey
                           ,UserDefine10, B_Company  
                           ,NIKESoldTo    
                           ,C_Contact1    
                           ,C_Phone1      
                           ,C_Address4    
                           ,FUserDefine07, ExternPOKey 
   FROM #RESULT
   WHERE 1 = CASE WHEN @c_RefNo <> '' AND RefNo = @c_RefNo THEN 1
                  WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' AND refno <> '' AND RefNo <> @c_ShippingFilterByRefNo THEN 1
                  WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' and Refno = '' AND RefNo <> @c_ShippingFilterByRefNo THEN  1
                  WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo = '' THEN 1 
                  ELSE 0 
             END
   AND MaxCarton NOT LIKE '-%' 
   AND MaxCarton >'0'
   ORDER BY CartonNo
   
   DROP TABLE #RESULT
   DROP TABLE #CTNRESULT
END

GO