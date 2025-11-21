SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_nikecn_ConsoDespatchTkt9                       */
/* Creation Date: 14-MAR-2019                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-8298 - [CN] NIKECN_CICO_Shipping label                  */
/*                                                                      */
/* Called By: r_dw_despatch_ticket_nikecn9                              */
/*            modified from isp_nikecn_ConsoDespatchTkt5                */
/*                          r_dw_despatch_ticket_nikecn5                */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 2020-09-17   WLChooi 1.1   WMS-15113 - Add Orders.UserDefine10 (WL01)*/
/* 2020-12-02   WLChooi 1.2   WMS-15802 - Show Full LabelNo (WL03)      */  
/* 20-Jan-2021  CSCHONG 2.8   WMS-16072 - add new field (CS01)          */
/* 09-APR-2021  CSCHONG 2.8   WMS-16072 - revised field logic(CS01a)    */
/* 06-SEP-2021  CSCHONG 2.9   WMS-17855 - revised field logic (CS02a)   */
/* 25-OCT-2021  CSCHONG 3.0   Devops Scripts combine                    */
/* 15-OCT-2021  CSCHONG 2.9   WMS-17855 - revised field logic (CS02b)   */
/* 24-NOV-2021  CSCHONG 3.0   WMS-17855 - revised field logic (CS02c)   */
/* 25-JUL-2022  MINGLE  3.1   WMS-20315 - revised field logic (ML01)    */
/* 25-OCT-2022  CSCHONG 3.3   WMS-20997 - Revised field logic (CS03)    */
/************************************************************************/

CREATE PROC [dbo].[isp_nikecn_ConsoDespatchTkt9]
   @c_pickslipno     NVARCHAR(10),
   @n_StartCartonNo  INT = 0,
   @n_EndCartonNo    INT = 0,
   @c_StartLabelNo   NVARCHAR(20) = '',
   @c_EndLabelNo     NVARCHAR(20) = '',
   @c_RefNo          NVARCHAR(20) = ''          --(CS04)
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
          ,@c_ConsigneeKey              NVARCHAR(15)--SOS# 174296
          ,@c_Company                   NVARCHAR(45)
          ,@c_Address1                  NVARCHAR(45)
          ,@c_Address2                  NVARCHAR(45)
          ,@c_Address3                  NVARCHAR(45)
          ,@c_City                      NVARCHAR(45)
          ,@d_DeliveryDate              DATETIME
          ,@c_Orderkey                  NVARCHAR(10) --NJOW01
          ,@c_Storerkey                 NVARCHAR(15) --(Wan01)
          ,@c_ShowQty_Cfg               NVARCHAR(10) --(Wan01)
          ,@c_ShowOrdType_Cfg           NVARCHAR(10) --(Wan02)
          ,@c_susr4                     NVARCHAR(10) --(Wan03)
          ,@c_Stop                      NVARCHAR(10)
          ,@c_showfield                 NVARCHAR(1) --(CS02)
          ,@c_showCRD                   NVARCHAR(1) --(CS02)
          ,@c_ShippingFilterByRefNo     NVARCHAR(20) --(CS04)
          ,@nRowRef                     INT --(CS04)
          ,@nExcludeCarton              INT --(CS04)
          ,@n_GetCartonNo               INT --(CS04)
          ,@n_cntRefno                  INT --(CS05)
          ,@c_GetPSlipno                NVARCHAR(20) --(CS05)
          ,@c_GetRefno                  NVARCHAR(20) --(CS05)
          ,@c_site                      NVARCHAR(30) --(CS05)
          ,@n_GetMaxCarton              INT --(CS05)  
          ,@c_facility                  NVARCHAR(10) --(CS08)
          ,@n_CtnOHNotes                INT          --CS01
          ,@c_FUDF14                    NVARCHAR(30) --CS01a    
          ,@c_CodeCityLdTime            NVARCHAR(30) = 'CityLdTime'   --CS01a
          ,@n_CtnSKUCategory            INT          --CS02a
          ,@c_Ssusr4                    NVARCHAR(20) --CS02a
          ,@c_busr4                     NVARCHAR(100) --CS02a
          ,@c_busr7                     NVARCHAR(30)  --CS02a    
          ,@c_Gbusr4                    NVARCHAR(100) --CS02a   
          ,@c_Csusr4                    NVARCHAR(20)  --CS02a
          ,@c_Dbusr7                    NVARCHAR(30)  --CS02a 
          ,@c_ItemDESCR                 NVARCHAR(40)  --CS02a 
         
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
   AND CLR.Long = 'r_dw_despatch_ticket_nikecn9' AND ISNULL(CLR.Short,'') <> 'N'
   
   SELECT @c_ShippingFilterByRefNo = Code2
   FROM dbo.CODELKUP (NOLOCK) 
   WHERE Listname = 'REPORTCFG'
   AND code = 'ShippingFilterByRefNo'
   AND Storerkey = @c_Storerkey
   

   --NJOW01
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
      ,ShowQtyCfg         NVARCHAR(10) NULL --(Wan01)
      ,OrderType          NVARCHAR(10) NULL --(Wan02)
      ,SUSR4              NVARCHAR(20) NULL --(Wan03)
      ,STOP               NVARCHAR(10) NULL
      ,ShowField          NVARCHAR(1) NULL --(CS02)
      ,ShowCRD            NVARCHAR(1) NULL --(CS02)
      ,CRD                NVARCHAR(10) NULL --(CS02)
      ,ExtraInfo          NVARCHAR(20) NULL --NJOW01
      ,TotalQtyPacked     INT NULL --(Wan04)
      ,RefNo              NVARCHAR(20) NULL --(CS04)
      ,RefNo2             NVARCHAR(30) NULL --(CS04)
      ,SITELoadkey        NVARCHAR(30) NULL --(CS05)
      ,UserDefine10       NVARCHAR(50) NULL --WL01
      ,OHNotes            NVARCHAR(40) NULL --(CS01)
   )

   CREATE INDEX IX_RESULT_01 on #RESULT ( LoadKey )
   CREATE INDEX IX_RESULT_02 on #RESULT ( CartonNo )
   
   /*CS04 Start*/
   CREATE TABLE #CTNRESULT (
      PickSlipNo NVARCHAR(10) NULL,
      RefNo      NVARCHAR(20) NULL,        
      RefNo2     NVARCHAR(30) NULL,       
      PCartonno  INT,
      CtnSeq     INT,
      MaxCtn     INT    )
   
   /*CS04 END*/

   --INSERT INTO TraceInfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5) -- SOS# 174296
   --VALUES ('isp_nikecn_ConsoDespatchTkt9: ' + RTRIM(SUSER_SNAME()), GETDATE()
   --      , @c_pickslipno, @n_StartCartonNo, @n_EndCartonNo
   --      , @c_StartLabelNo, @c_EndLabelNo)
         
   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      /*CS 05 start*/
      SET @n_cntRefno = 0
      
      SELECT @n_cntRefno = COUNT(DISTINCT c.code)
      FROM PackDetail (NOLOCK)
      JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
      JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )   --WL02
      JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.Orderkey )             --WL02                           
      JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
      LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
      LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' 
           AND C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
      WHERE PackHeader.PickSlipNo = @c_pickslipno
      AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END
     
    
    /*CS05 End*/

      /*CS01 START*/
      SET @n_CtnOHNotes = 0

       SELECT @n_CtnOHNotes = COUNT(DISTINCT ORDERS.Notes)
      FROM PackDetail (NOLOCK)
      JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
      JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )   --WL02
      JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.Orderkey )             --WL02                           
      WHERE PackHeader.PickSlipNo = @c_pickslipno
      AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END   
      AND ISNULL(ORDERS.notes,'') <> ''
      /*CS01 END*/
      INSERT INTO #RESULT   ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,   
                            ShowField,ShowCRD,CRD, ExtraInfo ,TotalQtyPacked                                    
                           , RefNo, RefNo2,SITELoadkey
                           , UserDefine10,OHNotes   --WL01  --CS01                      
                           )

      SELECT PackHeader.PickSlipNo,
            PackHeader.LoadKey,
            PackHeader.Route,
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(orders.B_company) ELSE MAX(ORDERS.Consigneekey) END as ConsigneeKey,     --CS03
            MAX(Orders.DeliveryDate) as DeliveryDate,
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.company) ELSE 
                     CASE WHEN orders.type in ('ZS05','ZS06') THEN MAX(Orders.M_Company) ELSE MAX(Orders.C_Company) END END as C_Company, --ML01  --CS03
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.Address1) ELSE MAX(Orders.C_Address1) END as C_Address1,     --CS03 S
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.Address2) ELSE MAX(Orders.C_Address2) END AS C_Address2,
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.Address3) ELSE MAX(Orders.C_Address3) END AS C_Address3,
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.City) ELSE MAX(Orders.C_City) END AS C_City,              --CS03 E
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
         --(CS02) Start
         ,  ShowField = @c_showField
         --CS02a START
         --, ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
         --             AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CONVERT(INT,ORDERS.Userdefine01)),111),'/',''),8))    --Cs03
         --             <  LEFT(ORDERS.ExternPOKey,8))) THEN
         --             CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
         --             'Y' ELSE 'N' END
         --             ELSE 'N' END
         --,   CRD = CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
         --          CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                           --CS03
         --          CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))                 --Cs03
         --      THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.ExternPOKey,4),'-','')) + 1))) + '-'+ substring(ORDERS.ExternPOKey,5,2)
         --          + '-' + substring(ORDERS.ExternPOKey,7,2) ELSE
         --     CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.ExternPOKey,4),'-',''))))) + '-'+ substring(ORDERS.ExternPOKey,5,2)
         --         + '-' + substring(ORDERS.ExternPOKey,7,2) END
         --          ELSE '' END
         --          ELSE '' END
           , ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
                      AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,MAX(Orders.UserDefine10)) + CAST(MAX(CLC.Short) AS INT)),121))      
                      <  MAX(CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121)))) THEN           
                      'Y' ELSE 'N' END          
           ,   CRD =   
                   CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                               
                   CONVERT(NVARCHAR(10),Orders.DeliveryDate,121)  ELSE '' END 
         --, CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
          --, CASE WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
          --       WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
          --       ELSE '' END AS ExtraInfo      
           , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS02b
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END AS ExtraInfo  
        /*CS03 End*/
                       
        --CS02a END    
         ,  TotalQtyPacked = (SELECT ISNULL(SUM(PD.Qty),0)                       --(Wan04)
                                    FROM PACKDETAIL PD WITH (NOLOCK)             --(Wan04)
                                    WHERE PD.PickSlipNo = PACKHEADER.PickSlipNo  --(Wan04)    
                                    AND PD.CartonNo = PACKDETAIL.CartonNo        --(Wan04)
         )
         , Packdetail.RefNo, PackDetail.RefNo2                                   --(CS04)
         , CASE WHEN @n_cntRefno >1 THEN Packdetail.RefNo + '-' +PackHeader.PickSlipNo ELSE PackHeader.PickSlipNo END SITELoadkey   --(CS05) --(CS03)
         --WL01 START
         , CASE WHEN ISDATE(MAX(Orders.UserDefine10)) = 1 THEN RIGHT('00' + CAST(DATEPART(mm,MAX(Orders.UserDefine10)) AS NVARCHAR(2)), 2) +
                                                               N'月' + 
                                                               RIGHT('00' + CAST(DATEPART(dd,MAX(Orders.UserDefine10)) AS NVARCHAR(2)), 2) +
                                                               + N'日'
                                                           ELSE '' END AS UserDefine10
         --WL01 END
         ,'' --CASE WHEN @n_CtnOHNotes > 1 THEN 'MIX' ELSE MAX(SUBSTRING(Orders.Notes,1,40)) END as OHNotes           --(CS01)   --(CS02a)
      FROM Orders Orders WITH (NOLOCK)
      JOIN OrderDetail OrderDetail WITH (NOLOCK) ON Orders.OrderKey = OrderDetail.OrderKey
     -- JOIN LoadPlanDetail LoadPlanDetail WITH (NOLOCK) ON (Orders.OrderKey = LoadplanDetail.OrderKey)                       --(CS10)
      JOIN Packheader Packheader WITH (NOLOCK) ON (Orders.LoadKey = Packheader.LoadKey)                                       --(CS10)
      JOIN Packdetail Packdetail WITH (NOLOCK) ON (Packheader.Pickslipno = Packdetail.pickslipno AND OrderDetail.SKU = PackDetail.SKU)
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = Orders.consigneekey)                                              --(CS02)
       --CS01a START
      LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND   
                                                CLC.Description = ORDERS.c_City AND  
                                                CLC.ListName = @c_CodeCityLdTime )   
     --CS01a END
     --CS03 S
     LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
     --CS03 E
      WHERE PackHeader.PickSlipNo = @c_pickslipno
      AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END
     --CS04 start
       AND 1 = CASE WHEN @c_RefNo <> '' AND RefNo = @c_RefNo THEN 1
         WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' AND RefNo <> @c_ShippingFilterByRefNo  THEN 1
         WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' and Refno = '' AND RefNo <> @c_ShippingFilterByRefNo THEN  1
        WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo = '' THEN 1 ELSE 0 END
        
     --CS04 End                                    
      GROUP BY PackHeader.PickSlipNo,
               PackHeader.LoadKey,
               PackHeader.Route,
               PackDetail.LabelNo,
               PackDetail.CartonNo
           ,  CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END                     --(Wan02)
          --CS02a START
          -- ,  CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
          --AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CONVERT(INT,ORDERS.Userdefine01)),111),'/',''),8))  --CS03
          --<  LEFT(ORDERS.ExternPOKey,8))) THEN
          --CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
          --'Y' ELSE 'N' END
          --ELSE 'N' END    --TS00048233
          -- ,  CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
          --CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                            --CS03
          --CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))                  --CS03
          --THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.ExternPOKey,4),'-','')) + 1))) + '-'+ substring(ORDERS.ExternPOKey,5,2)
          --+ '-' + substring(ORDERS.ExternPOKey,7,2) ELSE
          --CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.ExternPOKey,4),'-',''))))) + '-'+ substring(ORDERS.ExternPOKey,5,2)
          --+ '-' + substring(ORDERS.ExternPOKey,7,2) END
          --ELSE '' END
          --ELSE '' END   --TS00048233        
            ,CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                               
                   CONVERT(NVARCHAR(10),Orders.DeliveryDate,121)  ELSE '' END      
           ,  STORER.SUSR1                                                                        --(CS02)
         --, CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
         --, CASE   WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
         --         WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
         --         ELSE '' END       
            , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS02b
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END  
         --CS02a END
           , Packdetail.RefNo, PackDetail.RefNo2                                                     --(CS04)
         , ORDERS.TYPE  --ML01
         , ISNULL(ST.storerkey,'')                                    --CS03
           
           
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
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END
                                                               
      --CS05 END
      
      INSERT INTO #RESULT  ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,   
                            ShowField,ShowCRD,CRD, ExtraInfo                  
                           ,TotalQtyPacked                                    
                           ,RefNo, RefNo2,SITELoadkey           
                           ,UserDefine10,OHNotes   --WL01       --CS01         
                           )
      SELECT A.PickSlipNo,
            Orders.LoadKey,
            A.Route,
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN orders.B_company ELSE ORDERS.Consigneekey END as ConsigneeKey,     --CS03
            Orders.DeliveryDate,
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.company ELSE 
                          CASE WHEN orders.type in ('ZS05','ZS06') THEN Orders.M_Company ELSE Orders.C_Company END END, --ML01  --CS03
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address1 ELSE Orders.C_Address1 END,              --CS03
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address2 ELSE Orders.C_Address2 END,              --CS03
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address3 ELSE Orders.C_Address3 END,              --CS03 
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.City ELSE  Orders.C_City END,                     --CS03
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
       --CS02a START
        -- , ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
        --              AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),111),'/',''),8))  --Cs03  --CS01b
        --              <  LEFT(ORDERS.ExternPOKey,8))) THEN
        --              CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
        --              'Y' ELSE 'N' END
        --              ELSE 'N' END
        -- ,   CRD = CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
        --           CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                      --CS03
        --           CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))            --CS03
        --           THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)   --CS03
        --           + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE
        --           CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)             --CS03
        --           + '-' + substring(ORDERS.ExternPOKey,3,2) END
        --           ELSE '' END
        --           ELSE '' END
           , ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
                      AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,MAX(Orders.UserDefine10)) + CAST(MAX(CLC.Short) AS INT)),121))      
                      <  MAX(CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121)))) THEN           
                      'Y' ELSE 'N' END              
           ,   CRD =   
                   CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                               
                   CONVERT(NVARCHAR(10),Orders.DeliveryDate,121)  ELSE '' END  
        --, CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L'  AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
        --        WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
        --        WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
        --        WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
        --        WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
          --, CASE  WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
          --        WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
          --        ELSE '' END AS ExtraInfo  
            
             , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS02b
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END AS ExtraInfo 
        --CS02a END      
         , TotalQtyPacked = (SELECT ISNULL(SUM(PD.Qty),0)          
                     FROM PACKDETAIL PD WITH (NOLOCK)       
         WHERE PD.PickSlipNo = A.PickSlipNo           
                     AND PD.CartonNo = PACKDETAIL.CartonNo         
                     )                                             
        , Packdetail.RefNo, PackDetail.RefNo2                      
        , CASE WHEN @n_cntRefno > 1 THEN Packdetail.RefNo + '-' + A.PickSlipNo ELSE A.PickSlipNo END AS Siteloadkey        --CS03
        --WL01 START
        , CASE WHEN ISDATE(MAX(Orders.UserDefine10)) = 1 THEN RIGHT('00' + CAST(DATEPART(mm,MAX(Orders.UserDefine10)) AS NVARCHAR(2)), 2) +
                                                               N'月' + 
                                                               RIGHT('00' + CAST(DATEPART(dd,MAX(Orders.UserDefine10)) AS NVARCHAR(2)), 2) +
                                                               + N'日'
                                                          ELSE '' END AS UserDefine10
         --WL01 END
        ,'' --SUBSTRING(Orders.Notes,1,40)                   --CS01   --CS02a
      FROM Orders Orders WITH (NOLOCK)
      JOIN (
      SELECT DISTINCT OD.OrderKey, OD.Sku, PH.Pickslipno, PH.Route
      FROM OrderDetail OD WITH (NOLOCK)
      JOIN PackHeader PH WITH (NOLOCK) ON (OD.OrderKey = PH.OrderKey)   
      WHERE PH.Pickslipno = @c_pickslipno
      ) AS A
      ON Orders.OrderKey = A.OrderKey
      -- SOS# 248050 (End)
      JOIN Packdetail Packdetail WITH (NOLOCK) ON (A.Pickslipno = Packdetail.pickslipno AND A.SKU = PackDetail.SKU)
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = Orders.consigneekey)
       --CS01a START
      LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND   
                                                CLC.Description = ORDERS.c_City AND  
                                                CLC.ListName = @c_CodeCityLdTime )   
     --CS01a END
      --CS03 S
     LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
     --CS03 E
      WHERE A.PickSlipNo = @c_pickslipno
      AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
                                      CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END
      --CS04 start
       AND 1 = CASE WHEN @c_RefNo <> '' AND RefNo = @c_RefNo THEN 1
                 WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' AND RefNo <> @c_ShippingFilterByRefNo THEN 1
                 WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' and Refno = '' AND RefNo <> @c_ShippingFilterByRefNo THEN  1
                WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo = '' THEN 1 ELSE 0 END 
     --CS04 End                                  
      GROUP BY A.PickSlipNo,
               Orders.LoadKey,
               A.Route,
               PackDetail.LabelNo,
               PackDetail.CartonNo,
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN orders.B_company ELSE ORDERS.Consigneekey END,   --CS03
               Orders.DeliveryDate,
               Orders.C_Company,
               Orders.M_Company, --ML01
               orders.B_Company, --CS03 
               ST.Company,       --CS03
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address1 ELSE Orders.C_Address1 END,              --CS03
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address2 ELSE Orders.C_Address2 END,              --CS03
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address3 ELSE Orders.C_Address3 END,              --CS03 
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.City ELSE Orders.C_City END,                      --CS03
               Orders.Storerkey,
               Orders.xDockFlag,
               Orders.LoadKey,
               CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END,
               Orders.Stop,   
             --CS02a START                  
          --     CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
          --AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),111),'/',''),8))  
          --<  LEFT(ORDERS.ExternPOKey,8))) THEN                                                                                                
          --CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN                                                                              
          --'Y' ELSE 'N' END                                                                                                                    
          --ELSE 'N' END,                                                                                                                       
          --      CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN                                                                      
          --CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                           
          --CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))                 
          --THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)        
          --+ '-' + substring(ORDERS.ExternPOKey,3,2) ELSE                                                                                      
          --CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)                 
          --+ '-' + substring(ORDERS.ExternPOKey,3,2) END                                                                                       
          --ELSE '' END
          --ELSE '' END,          
            CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                               
                   CONVERT(NVARCHAR(10),Orders.DeliveryDate,121)  ELSE '' END,      
               STORER.SUSR1                                                                        
         --, CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
          --, CASE  WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
          --        WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
          --        ELSE '' END      
           , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS02b
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END    
     /*CS03 End*/           
      --CS02a END
     , Packdetail.RefNo, PackDetail.RefNo2 , SUBSTRING(Orders.Notes,1,40)          --CS01   
     , ORDERS.TYPE   --ML01
     , ISNULL(ST.storerkey,'')   --CS03  
   END


--  SELECT '2',* FROM #RESULT AS r
  
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
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(orders.B_company) ELSE MAX(ORDERS.Consigneekey) END as ConsigneeKey,     --CS03
                  MAX(Orders.DeliveryDate) as DeliveryDate,
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.company) ELSE 
                     CASE WHEN orders.type in ('ZS05','ZS06') THEN MAX(Orders.M_Company) ELSE MAX(Orders.C_Company) END END as C_Company, --ML01  --CS03
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.Address1) ELSE MAX(Orders.C_Address1) END as C_Address1,     --CS03
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.Address2) ELSE MAX(Orders.C_Address2) END AS C_Address2,     --CS03
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.Address3) ELSE MAX(Orders.C_Address3) END AS C_Address3,     --CS03
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.City) ELSE MAX(Orders.C_City) END AS C_City,             --CS03
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
               ,  Plant = @c_Susr4 --(Wan03)
               ,  MAX(Orders.Stop) as Stop
               --(CS02) Start
              ,  ShowField = @c_showField
            --CS02a START
            --  ,  ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
            --                AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),111),'/',''),8))    --CS03 --CS01b
            --                <  LEFT(ORDERS.ExternPOKey,8))) THEN
            --                CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
            --                'Y' ELSE 'N' END
            --                ELSE 'N' END
            --  ,   CRD = CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
            --       CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN
            --       CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))
            --       THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)
            --       + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE
            --       CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)                           --Cs03
            --       + '-' + substring(ORDERS.ExternPOKey,3,2) END
            --       ELSE '' END
            --       ELSE '' END     
             , ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
                      AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,MAX(Orders.UserDefine10)) + CAST(MAX(CLC.Short) AS INT)),121))      
                      <  MAX(CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121)))) THEN           
                      'Y' ELSE 'N' END               
             , CRD =   
                   CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                               
                   CONVERT(NVARCHAR(10),Orders.DeliveryDate,121)  ELSE '' END                
            --, CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
            -- WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
            -- WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
            -- WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
            -- WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
             --, CASE WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
             --       WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
             --       ELSE '' END AS ExtraInfo         --CS03 End   
              , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS02b
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END AS ExtraInfo  
             --CS02a END         
             ,  0 AS TotalQtyPacked                 -- (Wan04)  
             FROM PackHeader (NOLOCK)
         -- JOIN LoadplanDetail (NOLOCK) ON PackHeader.LoadKey = LoadplanDetail.LoadKey             --(CS10)
          JOIN Orders (NOLOCK) ON Orders.loadkey = PackHeader.loadkey          --(CS02)       --(CS10)
          LEFT JOIN STORER (NOLOCK) ON STORER.StorerKey = Orders.ConsigneeKey
           --CS01a START
          LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND   
                                                CLC.Description = ORDERS.c_City AND  
                                                CLC.ListName = @c_CodeCityLdTime )   
          --CS01a END 
          --CS03 S
          LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
          --CS03 E
          WHERE PackHeader.PickSlipNo = @c_pickslipno 
          --AND  PackHeader.LoadKey = LoadplanDetail.LoadKey AND     --CS10
          --Orders.OrderKey = LoadplanDetail.OrderKey
          --AND STORER.StorerKey = Orders.ConsigneeKey              --(CS02)
          GROUP BY PackHeader.PickSlipNo,
               PackHeader.LoadKey,
               PackHeader.Route,
               CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END,          --(Wan02)
               --CS02a START
               --CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
               --   AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),111),'/',''),8))    --CS03
               --   <  LEFT(ORDERS.ExternPOKey,8))) THEN
               --   CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
               --   'Y' ELSE 'N' END
               --   ELSE 'N' END, --TS00048233
               --         CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
               --   CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN
               --   CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))
               --   THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)
               --   + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE
               --   CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)                        --CS03
               --   + '-' + substring(ORDERS.ExternPOKey,3,2) END
               --   ELSE '' END
               --   ELSE '' END,    --TS00048233
                   CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                               
                   CONVERT(NVARCHAR(10),Orders.DeliveryDate,121)  ELSE '' END,      
                  STORER.SUSR1    
              --, CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
              -- WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
              -- WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
              -- WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
              -- WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
              --, CASE WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
              --       WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
              --       ELSE '' END           --CS03 End
              , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS02b
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END
           , Orders.Type   --ML01
           , ISNULL(ST.storerkey,'')     --CS03

              --CS02a END
               
               --SELECT * FROM #RESULT AS r
            END
              ELSE
               BEGIN  --NJOW01
                  INSERT INTO #RESULT  ( PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,     --(Wan01), (Wan02)Add ORderType, (Wan03) Add SUSR4
                            ShowField,ShowCRD,CRD, ExtraInfo                                       --(CS02)
                           ,TotalQtyPacked                                                         --(Wan04)
                         --  ,RefNo, RefNo2                                                          --(CS04)
                           )
                  SELECT
                  PackHeader.PickSlipNo,
                  Orders.LoadKey,
                  PackHeader.Route,
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN orders.B_company ELSE ORDERS.Consigneekey END,  --CS03
                  Orders.DeliveryDate,
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.company ELSE                                        --CS03
                        CASE WHEN orders.type in ('ZS05','ZS06') THEN Orders.M_Company ELSE Orders.C_Company END END,   --ML01   --CS03
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN (ST.Address1) ELSE (Orders.C_Address1) END as C_Address1,     --CS03 S
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN (ST.Address2) ELSE (Orders.C_Address2) END AS C_Address2,
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN (ST.Address3) ELSE (Orders.C_Address3) END AS C_Address3,     --CS03 S
                  CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN (ST.City) ELSE Orders.C_City END,                         --CS03
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
               ,  OrderType = CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END     
               ,  Plant = @c_Susr4
               ,  Orders.Stop                                                               
              ,  ShowField = @c_showField
             --CS02a START
             -- ,  ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
             --               AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),111),'/',''),8))  --CS01a       --CS03
             --               <  LEFT(ORDERS.ExternPOKey,8))) THEN
             --               CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
             --               'Y' ELSE 'N' END
             --               ELSE 'N' END
             -- ,   CRD =  CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
             --            CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN
             --            CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))
             --            THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)
             --            + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE
             --            CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)                 
             --            + '-' + substring(ORDERS.ExternPOKey,3,2) END
             --            ELSE '' END
             --            ELSE '' END
               , ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
                      AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,MAX(Orders.UserDefine10)) + CAST(MAX(CLC.Short) AS INT)),121))      
                      <  MAX(CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121)))) THEN           
                      'Y' ELSE 'N' END                 
               ,   CRD =   
                   CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                               
                   CONVERT(NVARCHAR(10),Orders.DeliveryDate,121)  ELSE '' END      
             --   , CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
             --WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
             --WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
             --WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
             --WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
             --, CASE WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
             --       WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
             --       ELSE '' END AS ExtraInfo 
               , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS02b
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END AS ExtraInfo    

            --CS02a END       
         ,  0 AS TotalQtyPacked        
         FROM PackHeader (NOLOCK)
         JOIN Orders (NOLOCK) ON Packheader.Orderkey = Orders.Orderkey
         LEFT JOIN STORER (NOLOCK) ON (STORER.StorerKey = Orders.ConsigneeKey)  
          --CS01a START
          LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND   
                                                CLC.Description = ORDERS.c_City AND  
                                                CLC.ListName = @c_CodeCityLdTime )   
          --CS01a END          
         --CS03 S
          LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
          --CS03 E    
         WHERE PackHeader.PickSlipNo = @c_pickslipno
         GROUP BY PackHeader.PickSlipNo,
               PackHeader.LoadKey,
               PackHeader.Route,
               ORDERS.Consigneekey,
               Orders.DeliveryDate,
               Orders.C_Company,
               Orders.M_Company, --ML01
               Orders.b_company, --CS03 
               ST.company ,      --CS03 S
               ISNULL(ST.storerkey,''),
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN (ST.Address1) ELSE (Orders.C_Address1) END ,     --CS03 S
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN (ST.Address2) ELSE (Orders.C_Address2) END ,
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN (ST.Address3) ELSE (Orders.C_Address3) END ,     --CS03 E
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN (ST.City) ELSE Orders.C_City END,                --CS03
               Orders.Storerkey,
               Orders.xDockFlag,
               Orders.LoadKey,
               CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END,          
               Orders.Stop,
              --CS02a START
               --CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'
               --   AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),111),'/',''),8))       
               --   <  LEFT(ORDERS.ExternPOKey,8))) THEN
               --   CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN
               --   'Y' ELSE 'N' END
               --   ELSE 'N' END,  
               --         CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN
               --   CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN
               --   CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))
               --   THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)
               --   + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE
               --   CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)                     
               --   + '-' + substring(ORDERS.ExternPOKey,3,2) END 
               --   ELSE '' END
               --   ELSE '' END,          
              CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                               
                   CONVERT(NVARCHAR(10),Orders.DeliveryDate,121)  ELSE '' END,       
                           STORER.SUSR1     
                    --  , CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                    --WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                    --WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'
                    --WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'
                    --WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''
                   --,CASE WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'
                   --      WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'
                   --      ELSE '' END     
                   , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS02b
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END,
                 Orders.Type  --ML01
                 ,ISNULL(ST.storerkey,'')    --CS03
                  --CS02a END   
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
   
   /*CS04 start*/
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
                                END   --CS06
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
    END 
 

       --CS02a START

          SET @n_CtnSKUCategory = 1
          SET @c_Ssusr4         = ''
          SET @c_busr4          = ''
          SET @c_busr7          = '' 
          SET @c_Gbusr4         = ''
          SET @c_Csusr4         = ''
          SET @c_Dbusr7         = ''
          SET @c_ItemDESCR      = ''


          SELECT @n_CtnSKUCategory = COUNT(DISTINCT RTRIM(S.susr4) + RTRIM(S.busr4) + RTRIM(S.busr7))
          FROM PACKDETAIL (NOLOCK)   
          JOIN SKU S WITH (NOLOCK) ON s.StorerKey = PACKDETAIL.storerkey AND s.sku= PACKDETAIL.sku  
          WHERE PACKDETAIL.PICKSLIPNO = @c_Pickslipno 


          IF @n_CtnSKUCategory > 1
          BEGIN
              SET @c_ItemDESCR = 'MIX'  
          END
          ELSE
          BEGIN
                SELECT distinct @c_Gbusr4 = GC.Description 
                               ,@c_Csusr4 = CTGY.Description 
                               ,@c_Dbusr7 = DIV.Description 
                FROM PACKDETAIL (NOLOCK)   
                JOIN SKU S WITH (NOLOCK) ON s.StorerKey = PACKDETAIL.storerkey AND s.sku= PACKDETAIL.sku  
                LEFT JOIN dbo.CODELKUP GC WITH (NOLOCK) ON GC.LISTNAME = 'Gendercode' AND GC.Storerkey = PACKDETAIL.Storerkey AND GC.Code = S.busr4
                LEFT JOIN dbo.CODELKUP CTGY WITH (NOLOCK) ON CTGY.LISTNAME = 'Category' AND CTGY.Storerkey = PACKDETAIL.Storerkey AND CTGY.Code = S.susr4   
                LEFT JOIN dbo.CODELKUP DIV WITH (NOLOCK) ON DIV.LISTNAME = 'Division' AND DIV.Storerkey = PACKDETAIL.Storerkey AND DIV.Code = S.busr7   
                WHERE PACKDETAIL.PICKSLIPNO = @c_Pickslipno 


               SET @c_ItemDESCR =  @c_Gbusr4 + '-' +   @c_Csusr4 + '-' + @c_Dbusr7

          END

      --CS02b    move up
        IF ISNULL(@c_Orderkey,'') = ''
         BEGIN
            SELECT @c_LoadKey = LoadKey 
            FROM PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            --CS08 start
            SET @c_facility = ''

            SELECT @c_facility = Facility
            FROM LOADPLAN WITH (NOLOCK)
            WHERE loadkey = @c_LoadKey

            --CS08 End

           
            --CS01a START
            SET @c_FUDF14 = ''

            SELECT @c_FUDF14 = ISNULL(UserDefine14,'')
            FROM FACILITY WITH (NOLOCK)
            WHERE facility =  @c_facility
           --CS01a End
      --CS02a END
 
      IF  @n_GetCartonNo = @n_GetMaxCarton
      BEGIN
         SET @nSumPackQty = 0
         SET @nSumPickQty = 0
         

         SELECT @nSumPackQty = SUM(QTY) FROM PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
         AND refno = @c_site 

         
          /*  SELECT @nSumPickQty = SUM(PD.QTY)    --CS09
            FROM PICKDETAIL pd WITH (NOLOCK)
            JOIN LoadPlanDetail ld WITH (NOLOCK) ON  ld.OrderKey = pd.OrderKey
            WHERE  ld.LoadKey = @c_LoadKey
            AND EXISTS(SELECT 1
                FROM LOC l WITH (NOLOCK) 
                JOIN CODELKUP cl(NOLOCK) ON cl.LISTNAME = 'ALLSorting' 
                WHERE l.Loc = pd.Loc 
                AND cl.code2 = l.PickZone 
                AND cl.Storerkey = pd.Storerkey 
                AND cl.Code = @c_site
                AND l.facility = @c_facility )       --(CS08) 
                */ -- CS09 
            --CS09 Start    
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
                
         --CS09 End   
         END
         ELSE
         BEGIN  --NJOW01
            SELECT @nSumPickQty = SUM(PD.QTY)
            FROM PickDetail PD WITH (NOLOCK)
            WHERE PD.Orderkey = @c_Orderkey
         END
      
         IF  @n_GetCartonNo = @n_GetMaxCarton AND @nSumPackQty = @nSumPickQty
         BEGIN
            UPDATE #RESULT SET MaxCarton = ISNULL(RTRIM(Cast(@n_GetCartonNo AS NVARCHAR( 5))), 0) 
                     + '/' + ISNULL(RTRIM(Cast(@n_GetCartonNo AS NVARCHAR( 5))), 0)
                              ,OHNotes = @c_ItemDESCR                                       --CS02a   
            WHERE ROWREF = @nRowRef 
         END
         ELSE
         BEGIN
            UPDATE #RESULT SET MaxCarton = @n_GetCartonNo
                              ,OHNotes = @c_ItemDESCR                                       --CS02a   
            WHERE ROWREF = @nRowRef 
         END
      END
      ELSE
      BEGIN
         UPDATE #RESULT SET MaxCarton = @n_GetCartonNo
                           ,OHNotes = @c_ItemDESCR                                       --CS02a   
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

      SELECT @c_ConsigneeKey = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(orders.B_company) ELSE MAX(ISNULL(RTRIM(orders.ConsigneeKey),''))  END  --CS03 
            --, @c_Company      = MAX(ISNULL(RTRIM(C_Company),''))
            , @c_Company      = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(ST.company) ELSE 
                                   CASE WHEN ORDERS.type in ('ZS05','ZS06') THEN MAX(orders.M_Company) ELSE MAX(orders.C_Company) END   END --ML01   --CS03
            , @c_Address1     = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(ISNULL(RTRIM(ST.Address1),'')) ELSE MAX(ISNULL(RTRIM(C_Address1),''))  END    --CS03 S
            , @c_Address2     = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(ISNULL(RTRIM(ST.Address2),'')) ELSE MAX(ISNULL(RTRIM(C_Address2),''))  END    
            , @c_Address3     = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(ISNULL(RTRIM(ST.Address3),'')) ELSE MAX(ISNULL(RTRIM(C_Address3),''))  END    --CS03 E
            , @c_City         = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(ISNULL(RTRIM(ST.City),'')) ELSE MAX(ISNULL(RTRIM(C_City),'')) END         --CS03
            , @d_DeliveryDate = MAX(ISNULL(RTRIM(DeliveryDate),''))
            , @c_Stop         = MAX(ISNULL(RTRIM(Stop),''))
      FROM ORDERS WITH (NOLOCK)
     --CS03 S
     LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
     --CS03 E 
      WHERE LoadKey = @c_LoadKey
     GROUP BY ORDERS.type

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
      -- SOS# 174296 (End)
   END
   
   SELECT PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,
                            C_Company,  C_Address2,  C_Address1,  C_Address3,  C_City,    --CS02c
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,   --WL03
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,
                            ShowField,ShowCRD,CRD, ExtraInfo               
                           ,TotalQtyPacked,RefNo, RefNo2, SITELoadkey
                           ,UserDefine10 , CASE WHEN ISNULL(@c_FUDF14,'') <> '' THEN OHNotes ELSE '' END  --WL01      --CS01  --CS01a

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