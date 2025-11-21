SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/      
/* Stored Procedure: isp_nikecn_ConsoDespatchTkt5                       */      
/* Creation Date: 10-SEP-2013                                           */      
/* Copyright: LF                                                        */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: 288194-NIKE CN NIKE CRW Carton Label                        */      
/*                                                                      */      
/* Called By: r_dw_despatch_ticket_nikecn5                              */      
/*            modified from isp_nikecn_ConsoDespatchTkt                 */      
/*                          r_dw_despatch_ticket_nikecn3                */      
/* PVCS Version: 2.1                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Ver   Purposes                                  */      
/* 16-MAR-2015  CSCHONG 1.0   Change the logic to get the extorder(CS01)*/      
/* 14-JAN-2016  CSCHONG 1.1   SOS#360542  (CS02)                        */      
/* 31-MAY-2016  SPChin  1.2   TS00048233 - Bug Fixed                    */      
/* 29-Aug-2016  NJOW01  1.3   376073-Show extra info on label           */      
/* 23-Sep-2017  Wan04   1.4   WMS-942 - CN Nike CRW Carton Label CR     */      
/* 12-Apr-2017  CSCHONG 1.5   WMS-1604 - Change field mapping (CS03)    */      
/* 31-Dec-2017  JHTAN   1.6   Request to show only 10 char LabelNo(JH01)*/       
/* 15-JAN-2018  CSCHONG 1.7   WMS-3744-revised report logic (CS04)      */      
/* 10-APR-2018  JyhBin  1.7 Allow to print blank refno                  */      
/* 11-APR-2018  CSCHONG 1.8   WMS-4474 - add new field (CS05)           */      
/* 17-MAY-2018  CSCHONG 1.9   Fix cartonno >10 issue (CS06)             */      
/* 27-JUL-2018  CSCHONG 2.0   Scripts tunning (CS07)                    */      
/* 23-AUG-2018  CSCHONG 2.1   Performance tunning (CS08)                */      
/* 27-SEP-2018  CSCHONG 2.2   script tunning (CS09)                     */      
/* 29-OCT-2018  CSCHONG 2.3   Performance tunning (CS10)                */      
/* 15-NOV-2018  WLCHOOI 2.4   Change input parameters, add new          */    
/*                            logic(WL01)                               */  
/* 28-Jan-2019  TLTING_ext 1.5 enlarge externorderkey field length      */    
/* 05-Dec-2019  WLChooi 2.6   Performance Tunning (WL02)                */  
/* 02-Dec-2020  WLChooi 2.7   WMS-15802 - Show Full LabelNo (WL03)      */  
/* 20-Jan-2021  CSCHONG 2.8   WMS-16072 - add new field (CS11)          */
/* 04-FEB-2021  CSCHONG 2.8   WMS-16072 - revised new field logic(CS11a)*/
/* 09-APR-2021  CSCHONG 2.8   WMS-16072 - revised field logic(CS11b)    */
/* 06-SEP-2021  CSCHONG 2.9   WMS-17855 - revised field logic (CS12)    */
/* 25-OCT-2021  CSCHONG 3.0   Devops Scripts combine                    */
/* 25-OCT-2021  CSCHONG 3.1   WMS-17855 - revised field logic (CS12a)   */
/* 24-NOV-2021  CSCHONG 3.1   WMS-17855 - revised field logic (CS12b)   */
/* 25-JUL-2022  MINGLE  3.2   WMS-20315 - revised field logic (ML01)    */
/* 25-OCT-2022  CSCHONG 3.3   WMS-20997 - Revised field logic (CS13)    */
/* 05-DEC-2022  CSCHONG 3.4   WMS-20977 - Fix prefix issue (CS13a)      */
/************************************************************************/      
      
CREATE PROC [dbo].[isp_nikecn_ConsoDespatchTkt5]      
   --@c_pickslipno     NVARCHAR(10),        
   --@n_StartCartonNo  INT = 0,        
   --@n_EndCartonNo    INT = 0,        
   --@c_StartLabelNo   NVARCHAR(20) = '',        
   --@c_EndLabelNo     NVARCHAR(20) = '',        
   --@c_RefNo          NVARCHAR(20) = ''          --(CS04)        
    
   --WL01 START    
   @c_Wavekey        NVARCHAR(20),    
   @c_IntVechicle    NVARCHAR(60)='',    
   @c_VAS            NVARCHAR(250)='',    
   @c_PickZone       NVARCHAR(20)='',    
   @c_CaseID         NVARCHAR(20)=''    
   --WL01 END       
AS      
BEGIN      
      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @c_externOrderkey            NVARCHAR(50)     --tlting_ext  
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
          ,@c_Pickslipno                NVARCHAR(20)     
          ,@c_StartLabelNo              NVARCHAR(20) = ''      
          ,@c_EndLabelNo                NVARCHAR(20) = ''      
          ,@c_RefNo                     NVARCHAR(20) = ''    
          ,@c_showcartontype            NVARCHAR(1)   = 'N' --WL01    
          ,@c_Discrete                  NVARCHAR(1)  --WL01    
          ,@c_Conso                     NVARCHAR(1)  --WL01    
          ,@c_sku                       NVARCHAR(40) --WL01    
          ,@c_OrdOrdKey                 NVARCHAR(10) --WL01  
          ,@n_CtnOHNotes                INT          --CS11a  
          ,@c_FUDF14                    NVARCHAR(30) --CS11b    
          ,@c_CodeCityLdTime            NVARCHAR(30) = 'CityLdTime'   --CS11b
          ,@n_CtnSKUCategory            INT          --CS12
          ,@c_Ssusr4                    NVARCHAR(20) --CS12
          ,@c_busr4                     NVARCHAR(100) --CS12
          ,@c_busr7                     NVARCHAR(30)  --CS12    
          ,@c_Gbusr4                    NVARCHAR(100) --CS12   
          ,@c_Csusr4                    NVARCHAR(20)  --CS12
          ,@c_Dbusr7                    NVARCHAR(30)  --CS12 
          ,@c_ItemDESCR                 NVARCHAR(40)  --CS12

          
   SET @c_Storerkey = ''                     
   SET @c_ShowQty_Cfg = ''                   
   SET @c_ShowOrdType_Cfg = ''               
   SET @c_susr4 = ''                         
   SET @c_showfield = 'N'                    
   SET @c_showCRD = ''                       
   SET @c_ShippingFilterByRefNo = ''         
   SET @nExcludeCarton = 1        
   SET @c_Discrete = ''    
   SET @c_Conso = ''   

   SET @n_CtnOHNotes = 0        --CS11a  
      
   --SELECT @c_Orderkey = Orderkey       
   --      ,@c_Storerkey     = ISNULL(RTRIM(Storerkey) ,'')      
   --FROM   PACKHEADER(NOLOCK)      
   --WHERE  Pickslipno       = @c_Pickslipno     
       
   --WL01 START    
   SELECT @c_Storerkey = ISNULL(RTRIM(Orders.Storerkey) ,'')       
   from WAVEDETAIL (nolock)    
   JOIN Orders (nolock) on Orders.Orderkey = WAVEDETAIL.Orderkey    
   where WAVEDETAIL.Wavekey = @c_wavekey    
     
   CREATE TABLE #TMPPICKSLIPNO(    
          wavekey NVARCHAR(20)    
         ,pickslipno NVARCHAR(20)    
         ,orderkey NVARCHAR(10)    
         ,LoadKey NVARCHAR(10)    
         ,Discrete NVARCHAR(10)    
         ,Conso NVARCHAR(10)    
         ,OrdOrdKey NVARCHAR(10)    
         ,SKU NVARCHAR(20)    
         ,VAS NVARCHAR(1)    
   )  

    
   INSERT INTO #TMPPICKSLIPNO(wavekey,pickslipno,ORDERKEY,LoadKey,Discrete,Conso,OrdOrdKey,SKU,vas)    
   SELECT DISTINCT WAVEDETAIL.wavekey,Pickheader.Pickheaderkey,PACKHEADER.ORDERKEY,PackHeader.LoadKey    
         ,CASE WHEN ISNULL(PACKHEADER.ORDERKEY,'') <> '' AND ISNULL(PackHeader.LoadKey,'') <> '' --check discrete    
          THEN 'Y' ELSE 'N' END    
         ,CASE WHEN ISNULL(PACKHEADER.ORDERKEY,'') = '' AND ISNULL(PackHeader.LoadKey,'') <> '' --check conso    
          THEN 'Y' ELSE 'N' END    
         ,Orders.Orderkey    
         ,PACKDETAIL.SKU    
         ,CASE WHEN ISNULL(ODR.Orderkey,'') = '' THEN 'N' ELSE 'Y' END AS VAS --WL02 'N'    
   FROM Pickheader (NOLOCK)     
   --JOIN orders (NOLOCK) on (orders.loadkey = pickheader.externorderkey)  --WL02   
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON (LPD.Loadkey = pickheader.externorderkey) --WL02   
   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LPD.ORDERKEY  --WL02  
   JOIN wavedetail (NOLOCK) on (wavedetail.orderkey = orders.orderkey)    
   JOIN PACKHEADER (NOLOCK) ON (Pickheader.Pickheaderkey = PACKHEADER.PICKSLIPNO)    
   JOIN PACKDETAIL (NOLOCK) ON (PACKDETAIL.PICKSLIPNO = PACKHEADER.PICKSLIPNO)    
   LEFT JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.orderkey = ORDERS.OrderKey      
   LEFT JOIN LOC WITH (NOLOCK) ON LOC.loc=PICKDETAIL.Loc      
   LEFT JOIN ORDERDETAILREF ODR (NOLOCK) ON ODR.Orderkey = Orders.Orderkey AND ODR.PARENTSKU = PACKDETAIL.sku --WL02  
   WHERE  wavedetail.wavekey = @c_Wavekey AND ORDERS.INTERMODALVEHICLE = @c_IntVechicle     
   AND LOC.PICKZONE = @c_PickZone  AND Pickdetail.CaseID = CASE WHEN @c_caseid <> '' THEN @c_caseid ELSE Pickdetail.CaseID END--WL01    
   --WL02 Start  
 --  DECLARE cur_vas CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
 --SELECT pickslipno,OrdOrdKey,sku FROM #TMPPICKSLIPNO    
 --OPEN cur_vas    
       
 --  FETCH FROM cur_vas INTO @c_pickslipno,@c_orderkey,@c_sku     
 --  WHILE @@FETCH_STATUS = 0    
 --  BEGIN     
 -- IF EXISTS( SELECT 1 FROM ORDERDETAILREF (NOLOCK) WHERE ORDERKEY = @c_orderkey AND PARENTSKU = @c_sku)    
 -- BEGIN    
 --  UPDATE #TMPPICKSLIPNO    
 --  SET VAS = 'Y'    
 --  WHERE PICKSLIPNO = @c_pickslipno AND OrdOrdKey = @c_orderkey AND SKU = @c_sku    
 -- END    
 -- FETCH FROM cur_vas INTO @c_pickslipno,@c_orderkey,@c_sku     
 --  END    
 --  CLOSE cur_vas    
 --  DEALLOCATE cur_vas   
   --WL02 End   
    
   IF(@c_vas = 'Y')    
      DELETE FROM #TMPPICKSLIPNO WHERE VAS = 'N'   
      
   IF(@c_vas = 'N')    
      DELETE FROM #TMPPICKSLIPNO WHERE VAS = 'Y'    
      
  --SELECT * FROM #TMPPICKSLIPNO    
  --WL01 END    
    
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
   AND CLR.Long = 'r_dw_despatch_ticket_nikecn5' AND ISNULL(CLR.Short,'') <> 'N'      
         
   SELECT @c_ShippingFilterByRefNo = Code2      
   FROM dbo.CODELKUP (NOLOCK)       
   WHERE Listname = 'REPORTCFG'      
   AND code = 'ShippingFilterByRefNo'      
   AND Storerkey = @c_Storerkey      
        
   --WL01     
   SELECT @c_showcartontype = CASE WHEN ISNULL(CLR1.Short,'') <> '' THEN 'Y' ELSE 'N' END      
   FROM Codelkup CLR1 (NOLOCK)      
   WHERE CLR1.Storerkey = @c_storerkey    
   AND CLR1.Code = 'showcartontype'      
   AND CLR1.Listname = 'REPORTCFG'      
   AND CLR1.Long = 'r_dw_despatch_ticket_nikecn5' AND ISNULL(CLR1.Short,'') <> 'N'     

    --CS01 START
     SELECT @n_CtnOHNotes = COUNT (DISTINCT OH.notes)
     FROM  #TMPPICKSLIPNO TP
     JOIN  ORDERS OH WITH (NOLOCK) ON OH.loadkey = TP.LoadKey
     WHERE TP.Conso = 'Y'
     AND ISNULL(OH.notes,'') <> ''

    --CS01 END
    
   --NJOW01      
   CREATE TABLE #RESULT      
   (      
       ROWREF             INT NOT NULL IDENTITY(1 ,1) PRIMARY KEY      
      ,Wavekey     NVARCHAR(10) NULL    
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
      ,UserDefine10       NVARCHAR(20) NULL--WL01    
      ,ShowCartonType     NVARCHAR(1) NULL --WL01    
      ,CartonType         NVARCHAR(20) NULL--WL01    
      ,OHNotes            NVARCHAR(40) NULL --(CS11)
   )      
      
   CREATE INDEX IX_RESULT_01 on #RESULT ( LoadKey )      
   CREATE INDEX IX_RESULT_02 on #RESULT ( CartonNo )      
         
   /*CS04 Start*/      
   CREATE TABLE #CTNRESULT (    
      Wavekey    NVARCHAR(10) NULL,      
      PickSlipNo NVARCHAR(10) NULL,      
      RefNo      NVARCHAR(20) NULL,              
      RefNo2     NVARCHAR(30) NULL,             
      PCartonno  INT,      
      CtnSeq     INT,      
      MaxCtn     INT    )      
         
   /*CS04 END*/     


   /*CS13a Start*/      
   CREATE TABLE #CHKPREFIX (    
      TPWavekey    NVARCHAR(10) NULL,      
      TPPickSlipNo NVARCHAR(10) NULL,      
      TPloadkey    NVARCHAR(20) NULL,              
      cntRefno   INT    )      
         
   /*CS04 END*/    
    
   --INSERT INTO TraceInfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5) -- SOS# 174296      
   --VALUES ('isp_nikecn_ConsoDespatchTkt5: ' + RTRIM(SUSER_SNAME()), GETDATE()      
   --      , @c_pickslipno, @n_StartCartonNo, @n_EndCartonNo      
   --      , @c_StartLabelNo, @c_EndLabelNo)      
    
   --INSERT INTO TraceInfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5) -- SOS# 174296      
   --VALUES ('isp_nikecn_ConsoDespatchTkt5: ' + RTRIM(SUSER_SNAME()), GETDATE()      
   --      , @c_Wavekey, @c_IntVechicle, @c_VAS      
   --      , @c_PickZone, @c_caseid)      
  
   --WL01 Start  
   SET @n_cntRefno = 0   
   --CS13 S  
   --SELECT @n_cntRefno = COUNT(DISTINCT c.code)   
   --FROM CODELKUP C WITH (NOLOCK) where C.listname = 'ALLSorting'       
   --AND C.Storerkey=@c_storerkey AND C.code2=@c_PickZone   
  --CS13a S

   INSERT INTO #CHKPREFIX
   (
       TPWavekey,
       TPPickSlipNo,
       TPloadkey,
       cntRefno
   )
SELECT orders.userdefine09,PackHeader.PickSlipNo,orders.loadkey, COUNT(DISTINCT c.code)
      FROM PackDetail (NOLOCK)
      JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
      JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )  
      JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.Orderkey )                                    
      JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
      LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
      LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' 
           AND C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
WHERE orders.userdefine09= @c_Wavekey
GROUP BY orders.userdefine09,PackHeader.PickSlipNo,orders.loadkey
   --   SELECT @n_cntRefno = COUNT(DISTINCT c.code)
   --   FROM Pickheader (NOLOCK)     
   ----JOIN orders (NOLOCK) on (orders.loadkey = pickheader.externorderkey)  --WL02   
   --JOIN LOADPLANDETAIL LPD (NOLOCK) ON (LPD.Loadkey = pickheader.externorderkey) --WL02   
   --JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LPD.ORDERKEY  --WL02  
   --JOIN wavedetail (NOLOCK) on (wavedetail.orderkey = orders.orderkey)    
   --JOIN PACKHEADER (NOLOCK) ON (Pickheader.Pickheaderkey = PACKHEADER.PICKSLIPNO)    
   --JOIN PACKDETAIL (NOLOCK) ON (PACKDETAIL.PICKSLIPNO = PACKHEADER.PICKSLIPNO)    
   --LEFT JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.orderkey = ORDERS.OrderKey      
   --LEFT JOIN LOC WITH (NOLOCK) ON LOC.loc=PICKDETAIL.Loc      
   --LEFT JOIN ORDERDETAILREF ODR (NOLOCK) ON ODR.Orderkey = Orders.Orderkey AND ODR.PARENTSKU = PACKDETAIL.sku --WL02  
   --LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' 
   --        AND C.Storerkey=ORDERS.Storerkey AND C.code2=LOC.PickZone
   --WHERE  wavedetail.wavekey = @c_Wavekey AND ORDERS.INTERMODALVEHICLE = @c_IntVechicle     
   --AND LOC.PICKZONE = @c_PickZone  AND Pickdetail.CaseID = CASE WHEN @c_caseid <> '' THEN @c_caseid ELSE Pickdetail.CaseID END--WL01  

--SELECT distinct c.code
--     FROM Pickheader (NOLOCK)     
--   --JOIN orders (NOLOCK) on (orders.loadkey = pickheader.externorderkey)  --WL02   
--   JOIN LOADPLANDETAIL LPD (NOLOCK) ON (LPD.Loadkey = pickheader.externorderkey) --WL02   
--   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LPD.ORDERKEY  --WL02  
--   JOIN wavedetail (NOLOCK) on (wavedetail.orderkey = orders.orderkey)    
--   JOIN PACKHEADER (NOLOCK) ON (Pickheader.Pickheaderkey = PACKHEADER.PICKSLIPNO)    
--   JOIN PACKDETAIL (NOLOCK) ON (PACKDETAIL.PICKSLIPNO = PACKHEADER.PICKSLIPNO)    
--   LEFT JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.orderkey = ORDERS.OrderKey      
--   LEFT JOIN LOC WITH (NOLOCK) ON LOC.loc=PICKDETAIL.Loc      
--   LEFT JOIN ORDERDETAILREF ODR (NOLOCK) ON ODR.Orderkey = Orders.Orderkey AND ODR.PARENTSKU = PACKDETAIL.sku --WL02  
--   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' 
--           AND C.Storerkey=ORDERS.Storerkey AND C.code2=LOC.PickZone
--   WHERE  wavedetail.wavekey = @c_Wavekey AND ORDERS.INTERMODALVEHICLE = @c_IntVechicle     
--   AND LOC.PICKZONE = @c_PickZone  AND Pickdetail.CaseID = CASE WHEN @c_caseid <> '' THEN @c_caseid ELSE Pickdetail.CaseID END--WL01  
-- CS13a E
 -- SELECT * FROM  #TMPPICKSLIPNO 
 -- SELECT @n_cntRefno '@n_cntRefno'

   --CS13 E

   --WL02 START  
   --DECLARE cur_pickslipno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   --SELECT PICKSLIPNO,Discrete,Conso,OrdOrdKey,sku FROM #TMPPICKSLIPNO    
   --OPEN cur_pickslipno    
         
   --  FETCH FROM cur_pickslipno INTO @c_pickslipno,@c_Discrete,@c_Conso,@c_OrdOrdKey,@c_sku     
   --  WHILE @@FETCH_STATUS = 0    
   --  BEGIN     
   --  IF (@c_Conso = 'Y' and @c_Discrete = 'N')   --Conso    
   --  BEGIN      
        /*CS 05 start*/      
   
         
   --   SELECT @n_cntRefno = COUNT(DISTINCT c.code)      
   --   FROM PackDetail (NOLOCK)      
   --   JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )      
   --  -- JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )                   --CS10      
   --   JOIN ORDERS (NOLOCK) ON ( Orders.loadkey = PackHeader.loadkey )                                     --CS10      
   --   JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )      
   --   LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey      
   --  -- LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc      
   --   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting'       
   --        AND C.Storerkey=@c_storerkey AND C.code2=@c_PickZone    
   --   WHERE PackHeader.PickSlipNo = @c_pickslipno      
   --   --AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND      
   --   --                                CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END      
   --AND PACKDETAIL.SKU = @c_sku    
  
   --SELECT @n_cntRefno  
    
    /*CS05 End*/   
    --WL02 End  
  
    --Conso  
   INSERT INTO #RESULT   ( Wavekey, PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,      
                           C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,      
                           xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,      
                           ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,      
                           ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,      
                           MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,         
                           ShowField,ShowCRD,CRD, ExtraInfo ,TotalQtyPacked                                          
                           , RefNo, RefNo2,SITELoadkey    
                           ,UserDefine10, ShowCartonType, CartonType,OHNotes             --WL01    --CS11            
   )      
      
   SELECT   @c_wavekey,    
            PackHeader.PickSlipNo,      
            PackHeader.LoadKey,      
            PackHeader.Route,      
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(orders.B_company) ELSE MAX(ORDERS.Consigneekey) END as ConsigneeKey,     --CS13    
            MAX(Orders.DeliveryDate) as DeliveryDate,      
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.company) ELSE 
                      CASE WHEN orders.type in ('ZS05','ZS06') THEN MAX(Orders.M_Company) ELSE MAX(Orders.C_Company) END END AS C_Company,   --ML01      
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.Address2) ELSE MAX(Orders.C_Address2) END as C_Address1,     --CS13
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.Address1) ELSE MAX(Orders.C_Address1) END AS C_Address2,
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.Address3) ELSE MAX(Orders.C_Address3) END AS C_Address3,     --CS13 E     
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.city) ELSE MAX(Orders.C_City) END AS C_City,                 --CS13
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
        --CS12 START
         --, ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
         --             AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),111),'/',''),8))    --Cs03 --CS11b     
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
                      AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),121))      
                      <  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121))) THEN           
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
           , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS12a
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END AS ExtraInfo        
         --CS12 END       
        /*CS03 End*/              
         ,  TotalQtyPacked = (SELECT ISNULL(SUM(PD.Qty),0)                       --(Wan04)      
                              FROM PACKDETAIL PD WITH (NOLOCK)                   --(Wan04)      
                              WHERE PD.PickSlipNo = PACKHEADER.PickSlipNo        --(Wan04)          
                              AND PD.CartonNo = PACKDETAIL.CartonNo              --(Wan04)      
         )      
         , Packdetail.RefNo, PackDetail.RefNo2                                   --(CS04)      
         , CASE WHEN @n_cntRefno >1 THEN Packdetail.RefNo + '-' +PackHeader.PickSlipNo ELSE PackHeader.PickSlipNo END SITELoadkey   --(CS05)    --(CS13)  
         , Orders.UserDefine10--WL01    
         , @c_showcartontype --WL01    
         , ISNULL(max(CartonList.Cartontype),'')--WL01   
         , ''--,CASE WHEN @n_CtnOHNotes > 1 THEN 'MIX' ELSE MAX(SUBSTRING(Orders.Notes,1,40)) END as OHNotes              --CS11a    --CS12
   FROM Orders Orders WITH (NOLOCK)      
   JOIN OrderDetail OrderDetail WITH (NOLOCK) ON Orders.OrderKey = OrderDetail.OrderKey      
     -- JOIN LoadPlanDetail LoadPlanDetail WITH (NOLOCK) ON (Orders.OrderKey = LoadplanDetail.OrderKey)                       --(CS10)      
   JOIN Packheader Packheader WITH (NOLOCK) ON (Orders.LoadKey = Packheader.LoadKey)                                       --(CS10)      
   JOIN Packdetail Packdetail WITH (NOLOCK) ON (Packheader.Pickslipno = Packdetail.pickslipno AND OrderDetail.SKU = PackDetail.SKU)      
   LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = Orders.consigneekey)                                                      --(CS02)      
   LEFT JOIN Pickdetail (NOLOCK) ON (Pickdetail.CaseID = Packdetail.labelno AND Pickdetail.sku = Packdetail.sku) --WL01      --(CS12) 
   LEFT JOIN CartonListDetail (NOLOCK) ON CartonListDetail.PickDetailKey = Pickdetail.PickDetailKey --WL01    
   LEFT JOIN CartonList (NOLOCK) ON CartonList.CartonKey = CartonListDetail.CartonKey --WL01    
   LEFT JOIN LOC WITH (NOLOCK) ON LOC.loc=PICKDETAIL.Loc  --WL01   
   JOIN #TMPPICKSLIPNO t ON (PACKHEADER.Pickslipno = t.Pickslipno AND t.Conso = 'Y' AND t.Discrete = 'N'   
                            AND t.OrdOrdKey = ORDERS.OrderKey AND t.SKU = Packdetail.SKU) --WL02
     --CS11b START
   LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND   
                                                CLC.Description = ORDERS.c_City AND  
                                                CLC.ListName = @c_CodeCityLdTime AND CLC.Storerkey=ORDERS.StorerKey)   
     --CS11b END    
     --CS13 S
     LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
     --CS13 E 
   --WL02 Start  
   WHERE ORDERS.INTERMODALVEHICLE = @c_IntVechicle --WL01    
   AND LOC.PICKZONE = @c_PickZone  --WL01     
   --WL02 End  
   AND Pickdetail.CaseID = CASE WHEN @c_caseid <> '' THEN @c_caseid ELSE Pickdetail.CaseID END--WL01    
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
       --CS12 START  
           , CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
                      AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),121))      
                      <   CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121))) THEN           
                      'Y' ELSE 'N' END          
           , CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                               
                   CONVERT(NVARCHAR(10),Orders.DeliveryDate,121)  ELSE '' END     
        --   ,  CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
        --  AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),111),'/',''),8))  --CS03  --CS11b    
        --  <  LEFT(ORDERS.ExternPOKey,8))) THEN      
        --  CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN      
        --  'Y' ELSE 'N' END      
        --  ELSE 'N' END    --TS00048233      
        --   ,  CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN      
        --  CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                            --CS03      
        --  CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))                  --CS03      
        --  THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.ExternPOKey,4),'-','')) + 1))) + '-'+ substring(ORDERS.ExternPOKey,5,2)      
        --+ '-' + substring(ORDERS.ExternPOKey,7,2) ELSE      
        --  CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.ExternPOKey,4),'-',''))))) + '-'+ substring(ORDERS.ExternPOKey,5,2)      
        --  + '-' + substring(ORDERS.ExternPOKey,7,2) END      
        --  ELSE '' END      
        --  ELSE '' END   --TS00048233      
           ,  STORER.SUSR1                                                                        --(CS02)      
         --, CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'      
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'      
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'      
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'      
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''      
           --, CASE WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'      
           --       WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'      
           --       ELSE '' END             
           , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS12a
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END 
         --CS12 END
            , Packdetail.RefNo, PackDetail.RefNo2                                                     --(CS04)      
            , Orders.UserDefine10 --WL01        
          --  , ISNULL(CartonList.Cartontype,'') --WL01   
          , ORDERS.TYPE --ML01
          , ISNULL(ST.storerkey,'')              --CS13
    
  --Discrete  
  --WL02 Start              
   --END      
   --ELSE      
   --IF (@c_Conso = 'N' and @c_Discrete = 'Y')   --DISCRETE    
   --BEGIN  --NJOW01      
     -- SET @n_cntRefno = 0      
            
    --  SELECT @n_cntRefno = COUNT(DISTINCT c.code)      
    --      FROM ORDERS (NOLOCK)      
    --      JOIN PackDetail (NOLOCK) ON ( ORDERS.StorerKey = PackDetail.StorerKey )      
    --      JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo      
    --                                AND Packheader.Orderkey = Orders.Orderkey      
    --                                AND Packheader.Loadkey = Orders.Loadkey      
    --                                AND Packheader.Consigneekey = Orders.Consigneekey )      
    --      LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey      
    --      LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc      
    --      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND      
    --      C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone      
    --      WHERE PackHeader.PickSlipNo = @c_pickslipno      
    --      --AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND      
    --      --                            CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END    
    --AND PACKDETAIL.SKU = @c_sku   --WL01      
   
    --select @n_cntRefno = COUNT(DISTINCT c.code)   
    --from CODELKUP C WITH (NOLOCK) where C.listname = 'ALLSorting'       
    --AND C.Storerkey=@c_storerkey AND C.code2=@c_PickZone     
                                                                     
      --CS05 END      
      INSERT INTO #RESULT  ( Wavekey, PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,      
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,      
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,      
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,      
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,      
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,         
                            ShowField,ShowCRD,CRD, ExtraInfo                        
                           ,TotalQtyPacked                                          
                           ,RefNo, RefNo2,SITELoadkey       
                           ,UserDefine10, ShowCartonType, CartonType, OHNotes      --WL01    --CS11                 
                          )      
      SELECT @c_wavekey,    
            A.PickSlipNo,      
            Orders.LoadKey,      
            A.Route,      
             CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN (orders.B_company) ELSE ORDERS.Consigneekey END,        --CS13      
            Orders.DeliveryDate,      
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.company ELSE 
                      CASE WHEN orders.type in ('ZS05','ZS06') THEN Orders.M_Company ELSE Orders.C_Company END END,  --ML01   --CS13      
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address2 ELSE Orders.C_Address2 END as C_Address1,     --CS13 S
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address1 ELSE Orders.C_Address1 END AS C_Address2,
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address3 ELSE Orders.C_Address3 END AS C_Address3,      --CS13 E 
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.city ELSE Orders.C_City END,                       --CS13      
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
        --CS12 START
         --, ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
         --             AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),111),'/',''),8)) --Cs03    --CS11b  
         --             <  LEFT(ORDERS.ExternPOKey,8))) THEN      
         --             CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4))=1 THEN      
         --             'Y' ELSE 'N' END      
         --             ELSE 'N' END      
         --,   CRD = CASE WHEN ISNUMERIC(LEFT(ORDERS.ExternPOKey,4)) = 1 THEN      
         --          CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                   --CS03      
         --          CASE WHEN CONVERT(INT,LEFT(ORDERS.ExternPOKey,4)) < CONVERT(INT,REPLACE(substring(ORDERS.Userdefine10,6,5),'-',''))            --CS03      
         --          THEN CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) + 1))) + '-'+ LEFT(ORDERS.ExternPOKey,2)   --CS03      
         --          + '-' + substring(ORDERS.ExternPOKey,3,2) ELSE      
         --          CONVERT(NVARCHAR(4),((CONVERT(INT,REPLACE(LEFT(ORDERS.Userdefine10,4),'-',''))))) + '-'+ LEFT(ORDERS.ExternPOKey,2)             --CS03      
         --          + '-' + substring(ORDERS.ExternPOKey,3,2) END      
         --          ELSE '' END      
         --          ELSE '' END      
        , ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
                      AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),121))      
                      <   CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121))) THEN           
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
            , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS12a
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END AS ExtraInfo 
         --CS12 END       
         , TotalQtyPacked = (SELECT ISNULL(SUM(PD.Qty),0)                
                     FROM PACKDETAIL PD WITH (NOLOCK)             
         WHERE PD.PickSlipNo = A.PickSlipNo                 
                     AND PD.CartonNo = PACKDETAIL.CartonNo               
                     )                                                   
        , Packdetail.RefNo, PackDetail.RefNo2                            
        , CASE WHEN @n_cntRefno > 1 THEN Packdetail.RefNo + '-' + A.PickSlipNo ELSE A.PickSlipNo END AS Siteloadkey    --CS13
        , Orders.UserDefine10 --WL01        
        , @c_showcartontype --WL01    
        , ISNULL(CartonList.Cartontype,'')      --WL01    
        , '' --, SUBSTRING(Orders.Notes,1,40)          --CS11       --CS12
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
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = Orders.consigneekey)                                                       --(CS02)      
      LEFT JOIN Pickdetail (NOLOCK) ON (Pickdetail.CaseID = Packdetail.labelno) --WL01    
      LEFT JOIN CartonListDetail (NOLOCK) ON CartonListDetail.PickDetailKey = Pickdetail.PickDetailKey --WL01    
      LEFT JOIN CartonList (NOLOCK) ON CartonList.CartonKey = CartonListDetail.CartonKey --WL01    
      LEFT JOIN LOC WITH (NOLOCK) ON LOC.loc=PICKDETAIL.Loc  --WL01    
      JOIN #TMPPICKSLIPNO t ON (A.Pickslipno = t.Pickslipno AND t.Conso = 'N' AND t.Discrete = 'Y'   
                                 AND t.OrdOrdKey = ORDERS.OrderKey AND t.SKU = Packdetail.SKU) --WL02  
       --CS11b START
      LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND   
                                                CLC.Description = ORDERS.c_City AND  
                                                CLC.ListName = @c_CodeCityLdTime )   
     --CS11b END 
     --CS13 S
     LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
     --CS13 E
     
      WHERE-- A.PickSlipNo = @c_pickslipno      
      --AND PackDetail.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND      
      --                                CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END    
  -- AND   
      ORDERS.INTERMODALVEHICLE = @c_IntVechicle --WL01        
      AND LOC.PICKZONE = @c_PickZone  --WL01      
      --AND ORDERS.OrderKey = @c_OrdOrdKey      
      --AND PACKDETAIL.SKU = @c_sku    --WL01      
      AND Pickdetail.CaseID = CASE WHEN @c_caseid <> '' THEN @c_caseid ELSE Pickdetail.CaseID END--WL01      
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
               ORDERS.Consigneekey,      
               Orders.DeliveryDate,      
               Orders.C_Company,      
               Orders.M_Company, --ML01
               Orders.B_Company, --CS13 S
               ST.Company,
               ISNULL(ST.storerkey,''),  
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address2 ELSE Orders.C_Address2 END,    
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address1 ELSE Orders.C_Address1 END,
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.Address3 ELSE Orders.C_Address3 END,      --CS13 E      
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.city ELSE Orders.C_City END,              --CS13      
               Orders.Storerkey,      
               Orders.xDockFlag,      
               Orders.LoadKey,      
               CASE WHEN @c_ShowOrdType_Cfg = '1' THEN Orders.Type ELSE '' END,      
               Orders.Stop,      
         --CS12 START        
                     
          --     CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
          --AND (LEFT(REPLACE(CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),111),'/',''),8))   --CS11b     
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
             CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD'      
                      AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.Userdefine10) + CAST(CLC.Short AS INT)),121))      
                      <   CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121))) THEN           
                      'Y' ELSE 'N' END ,         
             CASE WHEN ISNUMERIC(REPLACE(LEFT(ORDERS.Userdefine10,4),'-','')) = 1 THEN                                                               
                   CONVERT(NVARCHAR(10),Orders.DeliveryDate,121)  ELSE '' END ,            
               STORER.SUSR1                                                                              
         --, CASE WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'L' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'      
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'F' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'      
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'Q' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'L/QS'      
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'A' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN '1111'      
         --       WHEN SUBSTRING(ORDERS.ExternPokey,9,1) = 'N' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN ''      
           --, CASE  WHEN Orders.UserDefine05 = 'LI' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'LI'      
           --        WHEN Orders.UserDefine05 = 'RP' AND ISNULL(STORER.Susr2,'') = 'CRW' THEN 'RP'      
           --        ELSE '' END        
            , CASE WHEN Orders.UserDefine05 = 'NIKECN' THEN ''      --CS12a
                  WHEN ISNULL(STORER.Susr2,'') <> 'CRW' THEN ''      
                  ELSE Orders.UserDefine05 END          
     /*CS03 End*/                 
     --CS12 END
               , Packdetail.RefNo, PackDetail.RefNo2    
               , Orders.UserDefine10 --WL01        
               , ISNULL(CartonList.Cartontype,'') --WL01
               , ORDERS.TYPE  --ML01
               --, SUBSTRING(Orders.Notes,1,40)     --CS11        --CS12
   --WL02 End  
         
   --WL02 Start  
    --WL01    
 --   DECLARE cur_pickslipno1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
 --SELECT PICKSLIPNO,Discrete,Conso FROM #TMPPICKSLIPNO    
 --OPEN cur_pickslipno1    
       
 --FETCH FROM cur_pickslipno1 INTO @c_pickslipno,@c_Discrete,@c_Conso     
 --WHILE @@FETCH_STATUS = 0    
 --BEGIN    
 --   IF (@c_Conso = 'Y' and @c_Discrete = 'N')   --Conso     
 --  --IF ISNULL(@c_Orderkey,'') = ''      
 --     DECLARE Ext_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
 --     SELECT O.ExternOrderkey, O.Loadkey, Ph.Pickslipno      
 --     FROM   ORDERS O (NOLOCK)      
 --     JOIN   LoadPlanDetail Ld (NOLOCK) ON O.Loadkey = Ld.Loadkey AND O.Orderkey = Ld.Orderkey      
 --     JOIN   PackHeader Ph (NOLOCK) ON Ph.Loadkey = Ld.Loadkey    
 --  JOIN   WAVEDETAIL (NOLOCK) on (WAVEDETAIL.orderkey = O.orderkey)      
 --     WHERE  Ph.Pickslipno = @c_PickSlipNo      
 -- -- WHERE WAVEDETAIL.Wavekey = @c_wavekey    
 --     ORDER BY O.ExternOrderkey            
 --  ELSE  --NJOW01      
 --     DECLARE Ext_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
 --     SELECT O.ExternOrderkey, O.Loadkey,Ph.Pickslipno      
 --     FROM   ORDERS O (NOLOCK)      
 --     JOIN   PackHeader Ph (NOLOCK) ON O.Orderkey = Ph.Orderkey    
 --  JOIN   WAVEDETAIL (NOLOCK) on (WAVEDETAIL.orderkey = O.orderkey)        
 --     WHERE  Ph.Pickslipno = @c_PickSlipNo      
 -- -- WHERE WAVEDETAIL.Wavekey = @c_wavekey    
 --     ORDER BY O.ExternOrderkey      
  

 --Conso  
   DECLARE Ext_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT DISTINCT O.ExternOrderkey, O.Loadkey, Ph.Pickslipno      
   FROM   ORDERS O (NOLOCK)      
   JOIN   LoadPlanDetail Ld (NOLOCK) ON O.Loadkey = Ld.Loadkey AND O.Orderkey = Ld.Orderkey      
   JOIN   PackHeader Ph (NOLOCK) ON Ph.Loadkey = Ld.Loadkey  
   JOIN   #TMPPICKSLIPNO t ON t.pickslipno = PH.PickSlipNo AND t.Conso = 'Y' AND t.Discrete = 'N'  
   JOIN   WAVEDETAIL (NOLOCK) on (WAVEDETAIL.orderkey = O.orderkey)      
   ORDER BY O.ExternOrderkey   
      
   OPEN Ext_cur      
      
   SELECT @i_ExtCnt  = 1      
   SELECT @i_LineCnt = 0      
      
   FETCH NEXT FROM Ext_cur INTO @c_externOrderkey, @c_LoadKey, @c_pickslipno      
      
   WHILE @@FETCH_STATUS = 0      
   BEGIN      
      IF @i_ExtCnt = 10  -- SOS147156, Change from 11 to 10      
      BREAK      
            
      SELECT @i_ExtCnt  = @i_ExtCnt + 1      
      SELECT @i_LineCnt = @i_LineCnt + 1      
      SELECT @SQL = "UPDATE #RESULT SET ExtOrder" + RTRIM(LTRIM(@i_LineCnt)) + " = '" + RTRIM(LTRIM(@c_externOrderkey)) + "' "      
                    + "WHERE Pickslipno = '" + RTRIM(@c_pickslipno) + "' AND WAVEKEY = '" + RTRIM(@c_wavekey)    
                    + "' AND Loadkey = '" + RTRIM(@c_LoadKey) + "' "     
    
      EXEC (@SQL)      
      
      FETCH NEXT FROM Ext_cur INTO @c_externOrderkey, @c_LoadKey,@c_pickslipno      
   END      
   CLOSE Ext_cur      
   DEALLOCATE Ext_cur   
     
   --Discrete  
   DECLARE Ext_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT O.ExternOrderkey, O.Loadkey,Ph.Pickslipno      
   FROM   ORDERS O (NOLOCK)      
   JOIN   PackHeader Ph (NOLOCK) ON O.Orderkey = Ph.Orderkey       
   JOIN   #TMPPICKSLIPNO t ON t.pickslipno = PH.PickSlipNo AND t.Conso = 'Y' AND t.Discrete = 'N'  
   JOIN   WAVEDETAIL (NOLOCK) on (WAVEDETAIL.orderkey = O.orderkey)    
   ORDER BY O.ExternOrderkey   
      
   OPEN Ext_cur      
      
   SELECT @i_ExtCnt  = 1      
   SELECT @i_LineCnt = 0      
      
   FETCH NEXT FROM Ext_cur INTO @c_externOrderkey, @c_LoadKey, @c_pickslipno      
      
   WHILE @@FETCH_STATUS = 0      
   BEGIN      
      IF @i_ExtCnt = 10  -- SOS147156, Change from 11 to 10      
      BREAK      
            
      SELECT @i_ExtCnt  = @i_ExtCnt + 1      
      SELECT @i_LineCnt = @i_LineCnt + 1      
      SELECT @SQL = "UPDATE #RESULT SET ExtOrder" + RTRIM(LTRIM(@i_LineCnt)) + " = '" + RTRIM(LTRIM(@c_externOrderkey)) + "' "      
                    + "WHERE Pickslipno = '" + RTRIM(@c_pickslipno) + "' AND WAVEKEY = '" + RTRIM(@c_wavekey)    
                    + "' AND Loadkey = '" + RTRIM(@c_LoadKey) + "' "     
    
      EXEC (@SQL)      
      
      FETCH NEXT FROM Ext_cur INTO @c_externOrderkey, @c_LoadKey,@c_pickslipno      
   END      
   CLOSE Ext_cur      
   DEALLOCATE Ext_cur     
   --WL01 End  
      
   SET @nSumPackQty = 0      
   SET @nSumPickQty = 0      
   SET @nExcludeCarton = 1      
      
   DECLARE CUR_CTNRESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
   SELECT DISTINCT PICKSLIPNO FROM #TMPPICKSLIPNO        
   WHERE VAS = @c_VAS        
   OPEN CUR_CTNRESULT    
     
   FETCH FROM CUR_CTNRESULT INTO @c_PickSlipNo    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
       /*CS04 start*/      
       INSERT INTO #CTNRESULT ( Wavekey,PickSlipNo, RefNo, RefNo2, PCartonno, CtnSeq, MaxCtn )      
       SELECT DISTINCT @c_wavekey,PickSlipNo,RefNo,refno2,cartonno,Row_number() OVER (PARTITION BY PickSlipNo,RefNo ORDER BY cartonno),0      
       FROM packdetail (NOLOCK)      
       WHERE PickSlipNo=@c_PickSlipNo       
       GROUP BY  PickSlipNo,RefNo,refno2,cartonno      
       ORDER BY CartonNo     
       FETCH NEXT FROM CUR_CTNRESULT INTO @c_PickSlipNo    
   END    
   CLOSE CUR_CTNRESULT      
   --DEALLOCATE cur_pickslipno     
     
    SET @c_pickslipno = ''    
    
    OPEN CUR_CTNRESULT     
    FETCH FROM CUR_CTNRESULT INTO @c_PickSlipNo    
    
    WHILE @@FETCH_STATUS = 0    
    BEGIN    
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
      -- WHERE Pickslipno = @c_pickslipno     
      WHERE Wavekey = @c_wavekey    
        
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
      CLOSE CUR_SITE      
      DEALLOCATE CUR_SITE     
   END    
   FETCH FROM CUR_CTNRESULT INTO @c_PickSlipNo    
   END          
   CLOSE CUR_CTNRESULT      
   DEALLOCATE CUR_CTNRESULT     
       
   DECLARE CTN_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT CASE WHEN @c_ShippingFilterByRefNo <> '' and RefNo2 <> '' THEN CONVERT(INT,RefNo2)                         
   ELSE CartonNo  END,       
   ROWREF,refno, PickSlipNo      
   FROM #RESULT WITH (NOLOCK)      
   --WHERE PickSlipNo = @c_PickSlipNo      
   WHERE Wavekey = @c_Wavekey    
   AND 1 = CASE WHEN @c_RefNo <> '' AND RefNo = @c_RefNo THEN 1      
                WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' AND RefNo <> @c_ShippingFilterByRefNo THEN 1      
                WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo <> '' and Refno = '' AND RefNo <> @c_ShippingFilterByRefNo THEN  1      
                WHEN @c_RefNo = '' AND @c_ShippingFilterByRefNo = '' THEN 1 ELSE 0 END      
   ORDER BY 1                      
                                                                    
   OPEN CTN_CUR      
   FETCH NEXT FROM CTN_CUR INTO @nCartonNo , @nRowRef ,@c_site, @c_PickSlipNo      
      
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

      --CS12 START

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
   

      --WL01 START    --CS12 Move up from IF  @n_GetCartonNo = @n_GetMaxCarton      
         --IF ISNULL(@c_Orderkey,'') = ''      
   SELECT @c_Conso = CONSO    
         ,@c_Discrete = Discrete     
   FROM #TMPPICKSLIPNO WHERE PickSlipNo = @c_PickSlipNo --AND VAS = @c_VAS    
    
   IF (@c_conso = 'Y' AND @c_Discrete = 'N')    
         BEGIN      
            SELECT @c_LoadKey = LoadKey       
            FROM PackHeader WITH (NOLOCK)      
            WHERE PickSlipNo = @c_PickSlipNo      
   --WL01 END    
    --CS08 start      
    SET @c_facility = ''      
      
    SELECT @c_facility = Facility      
    FROM LOADPLAN WITH (NOLOCK)      
    WHERE loadkey = @c_LoadKey      
      
    --CS08 End      

   --CS11b START
   SET @c_FUDF14 = ''

   SELECT @c_FUDF14 = ISNULL(UserDefine14,'')
   FROM FACILITY WITH (NOLOCK)
   WHERE facility =  @c_facility
  --CS11b End
      --CS12 END     
       
      IF  @n_GetCartonNo = @n_GetMaxCarton      
      BEGIN      
         SET @nSumPackQty = 0      
         SET @nSumPickQty = 0      
               
      
         SELECT @nSumPackQty = SUM(expQTY) FROM PackDetail WITH (NOLOCK)      
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
                            ,OHNotes = @c_ItemDESCR                                       --CS12   
            WHERE ROWREF = @nRowRef       
         END      
         ELSE      
         BEGIN      
            UPDATE #RESULT SET MaxCarton = @n_GetCartonNo    
                                ,OHNotes = @c_ItemDESCR                                    --CS12
            WHERE ROWREF = @nRowRef       
         END      
      END      
      ELSE      
      BEGIN     

         UPDATE #RESULT SET MaxCarton = @n_GetCartonNo    
                            ,OHNotes = @c_ItemDESCR                                         --CS12
         WHERE ROWREF = @nRowRef                                     
      END      
      FETCH NEXT FROM CTN_CUR INTO @nCartonNo, @nRowRef  ,@c_site , @c_PickSlipNo        
   END      
   CLOSE CTN_CUR      
   DEALLOCATE CTN_CUR     
     
   -- SELECT distinct PICKSLIPNO,Loadkey,Discrete,Conso FROM #TMPPICKSLIPNO   
  
  --WL01 START    
  DECLARE cur_pickslipno2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
  SELECT distinct PICKSLIPNO,Discrete,Conso FROM #TMPPICKSLIPNO    
 -- WHERE VAS = @c_VAS    
  OPEN cur_pickslipno2    
      
  FETCH FROM cur_pickslipno2 INTO @c_pickslipno,@c_Discrete,@c_Conso     
  WHILE @@FETCH_STATUS = 0    
  BEGIN    
   --IF ISNULL(@c_Orderkey,'') = ''    
   IF (@c_Conso = 'Y' and @c_Discrete = 'N')   --Conso       
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
    
   DECLARE CUR_LOADKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
    
   SELECT DISTINCT PICKSLIPNO, LOADKEY    
   FROM #TMPPICKSLIPNO    
   --WHERE VAS = @c_VAS    
    
   OPEN CUR_LOADKEY    
    
   FETCH FROM CUR_LOADKEY INTO @c_pickslipno, @c_loadkey    
   WHILE @@FETCH_STATUS = 0        
  BEGIN    
    SELECT @c_ConsigneeKey = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(orders.B_company) ELSE MAX(ISNULL(RTRIM(orders.ConsigneeKey),''))  END --as ConsigneeKey,     --CS13     
         , @c_Company      =     CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(ST.company) ELSE 
                                     CASE WHEN ORDERS.type in ('ZS05','ZS06') THEN MAX(orders.M_Company) ELSE MAX(orders.C_Company) END END   --ML01       --CS13
         , @c_Address1     = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(ISNULL(RTRIM(ST.Address2),'')) ELSE MAX(ISNULL(RTRIM(C_Address2),''))  END    --CS13 S
         , @c_Address2     = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(ISNULL(RTRIM(ST.Address1),'')) ELSE MAX(ISNULL(RTRIM(C_Address1),''))  END    
         , @c_Address3     = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(ISNULL(RTRIM(ST.Address3),'')) ELSE MAX(ISNULL(RTRIM(C_Address3),''))  END    --CS13 E
         , @c_City         = CASE WHEN MAX(ISNULL(ST.storerkey,'')) <> '' THEN MAX(ISNULL(RTRIM(ST.City),'')) ELSE MAX(ISNULL(RTRIM(C_City),''))  END            --CS13    
         , @d_DeliveryDate = MAX(ISNULL(RTRIM(DeliveryDate),''))      
         , @c_Stop         = MAX(ISNULL(RTRIM(Stop),''))      
    FROM ORDERS WITH (NOLOCK)  
    --CS13 S
     LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
     --CS13 E    
    WHERE LoadKey = @c_LoadKey 
    GROUP BY ORDERS.TYPE --ML01 
      
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
  FETCH NEXT FROM CUR_LOADKEY INTO @c_pickslipno, @c_loadkey    
  END    
  CLOSE CUR_LOADKEY      
  DEALLOCATE CUR_LOADKEY    
  END    
  --WL01 END    
   FETCH NEXT FROM cur_pickslipno2 INTO @c_pickslipno,@c_Discrete,@c_Conso     
   END      
   CLOSE cur_pickslipno2      
   DEALLOCATE cur_pickslipno2    
         
   SELECT DISTINCT PickSlipNo, LoadKey, Route, ConsigneeKey, DeliveryDate,      
                            C_Company,  C_Address1,  C_Address2,  C_Address3,  C_City,      
                            xDockLane,  LabelNo,  CartonNo,  ExtOrder1,  ExtOrder2,   --WL03      
                            ExtOrder3,  ExtOrder4, ExtOrder5,  ExtOrder6,  ExtOrder7,      
                            ExtOrder8,  ExtOrder9, ExtOrder10, TotalSku,   TotalPcs,      
                            MaxCarton,  ShowQtyCfg, OrderType, SUSR4, Stop,      
                            ShowField,ShowCRD,CRD, ExtraInfo                     
                           ,TotalQtyPacked,RefNo, RefNo2, CASE WHEN TPX.cntRefno> 1 THEN RefNo + '-' + SITELoadkey ELSE SITELoadkey END SITELoadkey     
                           ,SUBSTRING(USERDEFINE10,6,2) AS [MONTH] --WL01    
                           ,SUBSTRING(USERDEFINE10,9,2) AS [DAY],CartonType   --WL01     
                           ,ShowCartonType,CASE WHEN ISNULL(@c_FUDF14,'') <> '' THEN OHNotes ELSE '' END   --WL01    --CS11 --CS11b
                           --,TPX.cntRefno
   FROM #RESULT   TR
  JOIN #CHKPREFIX TPX ON TPX.TPWavekey=TR.Wavekey AND TPX.TPPickSlipNo=TR.PickSlipNo AND TPX.TPloadkey=TR.LoadKey   
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
   DROP TABLE #CHKPREFIX    --CS13a
END     

GO