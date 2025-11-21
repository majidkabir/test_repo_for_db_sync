SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/  
/* Stored Procedure: isp_OrderStage_UA                                                    */  
/* Creation Date: 05-Jul-2023                                                             */  
/* Copyright: IDS                                                                         */  
/* Written by: KHLim                                                                      */  
/* Purpose: Staging shipment Orders and store in Summary table                            */  
/*          for Under Armour                                                              */  
/*  Cloned from isp_OrderStage                                                            */  
/* Called By:                                                                             */  
/*                                                                                        */  
/* PVCS Version: 1.0                                                                      */  
/*                                                                                        */  
/* Version: 5.4                                                                           */  
/*                                                                                        */  
/* Data Modifications:                                                                    */  
/*                                                                                        */  
/* Updates:                                                                               */  
/* Date          Author    Ver.  Purposes                                                 */  
/* 14-July-2023  ZiWei01         Clone from isp_OrderStage                                */    
/*                               WMS-22795 Exclude Orders.M_contact='EO' by Presale flag  */
/* 31-10-2023   kocy01     1.1   resume uncommentted BI.OrderStage insertion              */
/******************************************************************************************/  
CREATE   PROC  [dbo].[isp_OrderStage_UA]  
   @d_StartDate datetime  = NULL -- last Cut Off time  
  ,@d_Date  smalldatetime = NULL  
  ,@nDaysAgo smallint = 14  
  ,@b_debug  INT = 0  
  ,@FreqInterval smallint = 10  
AS  
BEGIN  
   SET NOCOUNT ON       ;   SET ANSI_NULLS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;  
   SET ANSI_WARNINGS OFF;  
  
   IF @d_StartDate IS NULL  
   BEGIN  
      SELECT TOP 1 @d_StartDate = DATEADD(minute, -20, SQLDate)  
      FROM   dbo.LogSQL WITH (NOLOCK)  
      WHERE SourceTable='BI.OrderSum'  
      ORDER BY SQLId DESC;  
  
      IF @@ROWCOUNT = 0 SET @d_StartDate = DATEADD(day, -2, CONVERT (date, GETDATE()));  
   END  
  
   IF @d_Date      IS NULL SET @d_Date      = GETDATE();  
   PRINT 'Last Cut Off: '+CAST(@d_StartDate AS VARCHAR(25));  
   DECLARE @GetDate DATETIME = GETDATE()  
         , @DB NVARCHAR(128) = DB_NAME()  
         , @Schema NVARCHAR(128) = OBJECT_SCHEMA_NAME(@@PROCID)  
         , @Proc   NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')  
         , @Id INT = ISNULL(TRY_CAST(SUBSTRING(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR,@d_StartDate,126),'-',''),'T',''),':',''),3,10) AS INT),0)  
         , @Duration INT, @DurationSP INT, @SQLId INT, @RowCnt INT = 0, @RowCntMain INT  
  
TRUNCATE TABLE BI.OrderStage;  
WITH O AS (  
   SELECT O.OrderKey, O.StorerKey, O.ExternOrderKey, DeliveryDate=CAST(O.DeliveryDate AS date), O.ConsigneeKey, C_City=ISNULL(O.C_City,'')  
   ,O.Status, O.Type, O.OrderGroup, AddDate=CAST(CONVERT(char(16),O.AddDate,121) AS smalldatetime), EditDate=CAST(O.EditDate AS smalldatetime)  
   ,MBOLKey=ISNULL(O.MBOLKey,''), LoadKey=ISNULL(O.LoadKey,''), O.Facility  
   ,ShipperKey=ISNULL(ShipperKey,''), DocType=ISNULL(DocType,''), TrackingNo=ISNULL(TrackingNo,''), ECOM_PRESALE_FLAG=ISNULL(O.ECOM_PRESALE_FLAG,''), ECOM_SINGLE_FLAG=ISNULL(O.ECOM_SINGLE_FLAG,'')  
   ,UserDefine01=ISNULL(O.UserDefine01,'') ,UserDefine02=ISNULL(O.UserDefine02,'') ,UserDefine03=ISNULL(O.UserDefine03,'')  
   ,m_contact1=ISNULL(m_contact1,'')  
   ,Lines     = COUNT(1)  
   ,OpenQty   = SUM(OD.OpenQty)  
   ,QtyAPS    = SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)  
   ,EnteredQTY= SUM(OD.EnteredQTY)  
   FROM dbo.ORDERS        O  WITH (NOLOCK)  
   JOIN dbo.OrderDetail   OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
  
   LEFT JOIN STORER   S WITH (NOLOCK) ON O.ShipperKey = S.StorerKey  
   WHERE O.EditDate >= CONVERT(NVARCHAR(23),@d_StartDate,121)  
   GROUP BY O.OrderKey, O.StorerKey, O.ExternOrderKey, CAST(O.DeliveryDate AS date), O.ConsigneeKey, ISNULL(O.C_City,'')  
   ,O.Status, O.Type, O.OrderGroup, CAST(CONVERT(char(16),O.AddDate,121) AS smalldatetime), CAST(O.EditDate AS smalldatetime)  
   ,ISNULL(O.MBOLKey,''), ISNULL(O.LoadKey,''), O.Facility  
   ,ISNULL(ShipperKey,''), ISNULL(DocType,''), ISNULL(TrackingNo,'') , ISNULL(O.ECOM_PRESALE_FLAG,''), ISNULL(O.ECOM_SINGLE_FLAG,'')  
   ,ISNULL(O.UserDefine01,'') ,ISNULL(O.UserDefine02,'') ,ISNULL(O.UserDefine03,''),ISNULL(O.m_contact1,'')  
) , H AS (  
   SELECT OrderKey,  
      Orders_Open=ISNULL([0],0), Orders_ALLOC=ISNULL([1],0)+ISNULL([2],0)+ISNULL([3],0), Orders_Pick_Packed=ISNULL([4],0)+ISNULL([5],0), Orders_Shipped=ISNULL([9],0), Orders_Cancelled=ISNULL(CANC,0)  
   FROM O  
   PIVOT (count(Status)  
   FOR Status IN ([0], [1], [2], [3], [4], [5], [9], CANC)  
   ) AS pvt  
)  
, Ln AS (  
   SELECT  OrderKey,  
      Lines_Open =ISNULL([0],0), Lines_ALLOC =ISNULL([1],0)+ISNULL([2],0)+ISNULL([3],0), Lines_Pick_Packed=ISNULL([4],0)+ISNULL([5],0), Lines_Shipped=ISNULL([9],0), Lines_Cancelled=ISNULL(CANC,0)  
   FROM O  
   PIVOT (SUM(Lines)  
   FOR Status IN ([0], [1], [2], [3], [4], [5], [9], CANC)  
   ) AS pvt  
), Uni AS (  
   SELECT  OrderKey,                 Units_ALLOC =ISNULL([1],0)+ISNULL([2],0)+ISNULL([3],0), Units_Pick_Packed=ISNULL([4],0)+ISNULL([5],0), Units_Shipped=ISNULL([9],0)  
   FROM O  
   PIVOT (SUM(QtyAPS)  
   FOR Status IN (     [1], [2], [3], [4], [5], [9]      )  
   ) AS pvt  
)  
INSERT BI.OrderStage (  OrderKey,   StorerKey,   ExternOrderKey,   DeliveryDate,   ConsigneeKey,   C_City  
   ,   Status,  Type,   OrderGroup,   AddDate,   EditDate  
   ,  MBOLKey,   LoadKey,   Facility,   ShipperKey,   DocType,   TrackingNo ,   ECOM_PRESALE_FLAG  
   , PreSale, ECOM_SINGLE_FLAG  
   ,UserDefine01 ,UserDefine02 ,UserDefine03  
   ,Lines  
   ,Units  
   ,PickDet_Lines  
   ,Orders_Open  
   ,Lines_Open  
   ,Units_Open  
   ,Orders_ALLOC  
   ,Lines_ALLOC  
   ,Units_ALLOC  
   ,Orders_Pick_Packed  
   ,Lines_Pick_Packed  
   ,Units_Pick_Packed  
   ,Orders_Shipped  
   ,Lines_Shipped  
   ,Units_Shipped  
   ,Orders_Cancelled  
   ,Lines_Cancelled  
   ,Units_Cancelled  
   ,PickDetails_Inserted ,Orders_OverRun ,Orders_PendBuildLoad, MBOL_NotValid  
   , CancDate )  
SELECT                O.OrderKey, O.StorerKey, O.ExternOrderKey, O.DeliveryDate, O.ConsigneeKey, O.C_City  
   ,O.Status, O.Type, O.OrderGroup, O.AddDate, O.EditDate  
   ,O.MBOLKey, O.LoadKey, O.Facility, O.ShipperKey, O.DocType, O.TrackingNo , O.ECOM_PRESALE_FLAG  
   , case   
        when O.ECOM_PRESALE_FLAG<>'' and O.m_contact1 ='EO' then 0       --ZiWei01  
        when O.ECOM_PRESALE_FLAG<>'' then 1   
                                     else 0   
     end, O.ECOM_SINGLE_FLAG  
   ,O.UserDefine01 ,O.UserDefine02 ,O.UserDefine03  
   ,Lines  = ISNULL(Lines_Open  ,0) + ISNULL(Lines_ALLOC  ,0) + ISNULL(Lines_Pick_Packed  ,0) + ISNULL(Lines_Shipped  ,0) + ISNULL(Lines_Cancelled  ,0)  
   ,Units  = ISNULL(CASE WHEN O.Status='0' THEN OpenQty ELSE 0 END  ,0) + ISNULL(Units_ALLOC  ,0) + ISNULL(Units_Pick_Packed  ,0) + ISNULL(Units_Shipped  ,0) + ISNULL(CASE WHEN O.Status='CANC' THEN EnteredQTY ELSE 0 END,0)  
   ,0 --default PickDet_Lines to 0 first  
   ,ISNULL(Orders_Open,0)  
   ,ISNULL(Lines_Open,0)  
   ,Units_Open=ISNULL(CASE WHEN O.Status='0' THEN OpenQty ELSE 0 END,0)  
   ,ISNULL(Orders_ALLOC      ,0)  
   ,ISNULL(Lines_ALLOC       ,0)  
   ,ISNULL(Units_ALLOC       ,0)  
   ,ISNULL(Orders_Pick_Packed,0)  
   ,ISNULL(Lines_Pick_Packed ,0)  
   ,ISNULL(Units_Pick_Packed ,0)  
   ,ISNULL(Orders_Shipped    ,0)  
   ,ISNULL(Lines_Shipped     ,0)  
   ,ISNULL(Units_Shipped     ,0)  
   ,ISNULL(Orders_Cancelled  ,0)  
   ,ISNULL(Lines_Cancelled   ,0)  
   ,Units_Cancelled=ISNULL(CASE WHEN O.Status='CANC' THEN EnteredQTY ELSE 0 END,0)  
   ,0 ,0 -- set PickDetail ,OverRun to 0 first  
   ,0 ,0   -- set MBOL_NotValid to 0 first  
   ,CancDate=CASE WHEN O.Status='CANC' THEN O.EditDate END  
FROM O  
LEFT JOIN H     WITH (NOLOCK) ON O.OrderKey = H.OrderKey  
LEFT JOIN Ln  L WITH (NOLOCK) ON O.OrderKey = L.OrderKey  
LEFT JOIN Uni U WITH (NOLOCK) ON O.OrderKey = U.OrderKey;  
  
   SET @RowCntMain = @@ROWCOUNT;  
   IF @b_debug=1 SELECT Ln=127, Spent=DATEDIFF(ms,@GetDate,GETDATE()), RowCnt = @@ROWCOUNT; SET @GetDate=GETDATE();  
  
WITH l AS (  
   SELECT  O.OrderKey, Orders_PendBuildLoad=SUM(CASE WHEN O.Status < '5' AND L.LoadKey IS NULL THEN 1 ELSE 0 END)  
   FROM BI.OrderStage AS O WITH (NOLOCK)  
   LEFT JOIN dbo.LoadPlan L WITH (NOLOCK)ON L.LoadKey = O.LoadKey  
   GROUP BY O.OrderKey  
)  
UPDATE O SET Orders_PendBuildLoad = ISNULL(l.Orders_PendBuildLoad,0)  
FROM BI.OrderStage AS O WITH (NOLOCK) JOIN l ON O.OrderKey = l.OrderKey;  
  
   IF @b_debug=1 SELECT 'Join LoadPlan', Spent=DATEDIFF(ms,@GetDate,GETDATE()), RowCnt = @@ROWCOUNT; SET @GetDate=GETDATE();  
  
WITH m AS (  
   SELECT o.Orderkey, ShipDate = CASE WHEN m.Status = '9' THEN CAST(MIN(m.ShipDate) AS smalldatetime) ELSE NULL END  
   ,MBOL_NotValid =ISNULL(SUM(CASE WHEN m.status = '5' AND m.ValidatedFlag = 'E' THEN 1 ELSE 0 END),0)  
   FROM BI.OrderStage AS O WITH (NOLOCK)  
   LEFT JOIN dbo.MBOLDETAIL d WITH (NOLOCK) ON O.OrderKey = d.OrderKey --AND O.Status='9'  
   LEFT JOIN dbo.MBOL       m WITH (NOLOCK) ON m.MbolKey  = d.MbolKey  
   GROUP BY O.OrderKey, m.Status  
)  
UPDATE O SET ShipDate = m.ShipDate  
      ,MBOL_NotValid = m.MBOL_NotValid  
FROM BI.OrderStage AS O WITH (NOLOCK) JOIN m ON O.OrderKey = m.OrderKey;  
  
   IF @b_debug=1 SELECT 'Join MBOL', Spent=DATEDIFF(ms,@GetDate,GETDATE()), RowCnt = @@ROWCOUNT; SET @GetDate=GETDATE();  
  
WITH D AS (  
   SELECT o.Orderkey, D.TransDate  
   FROM BI.OrderStage AS O WITH (NOLOCK)  
   JOIN dbo.DocStatusTrack AS D WITH (NOLOCK) ON D.TableName='STSORDERS' AND D.DocumentNo = O.OrderKey AND D.Key1 = '' AND D.DocStatus = O.[Status]  
   WHERE O.[Status] IN ('3', '5')  
)  
UPDATE O SET PickDate = CAST(D.TransDate AS smalldatetime)  
FROM BI.OrderStage AS O WITH (NOLOCK) JOIN D ON O.OrderKey = D.OrderKey;  
  
   IF @b_debug=1 SELECT 'Join DocStatusTrack', Spent=DATEDIFF(ms,@GetDate,GETDATE()), RowCnt = @@ROWCOUNT; SET @GetDate=GETDATE();  
  
WITH p AS (  
   SELECT o.Orderkey, PickDet_Lines=COUNT(1), AllocDate=CAST(MIN(P.AddDate) AS smalldatetime)  
   , Orders_OverRun=SUM(CASE WHEN (P.ShipFlag <> 'Y' OR P.Status <> '9') AND P.AddDate < DATEADD(HOUR,-                      8 ,@d_Date) THEN 1 ELSE 0 END)--Alloc until MarkShip  
   , PickDetails_Inserted=SUM(CASE WHEN P.EditDate >= DATEADD(minute,-@FreqInterval,@d_Date) THEN 1 ELSE 0 END)  
   FROM BI.OrderStage AS O WITH (NOLOCK)  
   JOIN dbo.ORDERS   AS r WITH (NOLOCK) on O.OrderKey = R.OrderKey  
   JOIN dbo.PICKDETAIL   P WITH (NOLOCK) ON P.OrderKey = O.OrderKey  
  
   GROUP BY O.OrderKey  
)  
UPDATE O SET PickDet_Lines = p.PickDet_Lines  
      ,AllocDate               = p.AllocDate  
      ,Orders_OverRun      = p.Orders_OverRun  
      ,PickDetails_Inserted= p.PickDetails_Inserted  
FROM BI.OrderStage AS O JOIN p ON O.OrderKey = p.OrderKey;  
  
   IF @b_debug=1 SELECT 'Join PickDetail', Spent=DATEDIFF(ms,@GetDate,GETDATE()), RowCnt = @@ROWCOUNT; SET @GetDate=GETDATE();  
  
DECLARE @SummaryOfChanges TABLE(Change VARCHAR(20));  
  
MERGE BI.OrderSum AS t  
USING BI.OrderStage AS s ON t.OrderKey = s.OrderKey  
WHEN MATCHED --AND t.Status NOT IN ('9','CANC')  
THEN  
   UPDATE SET ModifyDate=GETDATE() ,StorerKey=s.StorerKey, ExternOrderKey=s.ExternOrderKey,DeliveryDate=s.DeliveryDate,ConsigneeKey=s.ConsigneeKey,C_City=s.C_City  
   , Status=s.Status, Type=s.Type, OrderGroup=s.OrderGroup, AddDate=s.AddDate, EditDate=s.EditDate  
   ,MBOLKey=s.MBOLKey,LoadKey=s.LoadKey, Facility=s.Facility, ShipperKey=s.ShipperKey, DocType=s.DocType, TrackingNo=s.TrackingNo ,ECOM_PRESALE_FLAG=s.ECOM_PRESALE_FLAG  
   ,PreSale=s.PreSale, ECOM_SINGLE_FLAG=s.ECOM_SINGLE_FLAG  
   ,UserDefine01=s.UserDefine01 ,UserDefine02=s.UserDefine02 ,UserDefine03=s.UserDefine03  
   ,Lines=s.Lines ,Units=s.Units  
   ,PickDet_Lines=s.PickDet_Lines ,Orders_Open=s.Orders_Open ,Lines_Open=s.Lines_Open ,Units_Open=s.Units_Open  
   ,Orders_ALLOC=s.Orders_ALLOC ,Lines_ALLOC=s.Lines_ALLOC ,Units_ALLOC=s.Units_ALLOC  
   ,Orders_Pick_Packed=s.Orders_Pick_Packed ,Lines_Pick_Packed=s.Lines_Pick_Packed ,Units_Pick_Packed=s.Units_Pick_Packed  
   ,Orders_Shipped=s.Orders_Shipped ,Lines_Shipped=s.Lines_Shipped ,Units_Shipped=s.Units_Shipped  
   ,Orders_Cancelled=s.Orders_Cancelled ,Lines_Cancelled=s.Lines_Cancelled ,Units_Cancelled=s.Units_Cancelled  
   ,PickDetails_Inserted=s.PickDetails_Inserted ,Orders_OverRun=s.Orders_OverRun ,Orders_PendBuildLoad=s.Orders_PendBuildLoad  
   ,MBOL_NotValid=s.MBOL_NotValid  
   ,AllocDate=CASE WHEN t.AllocDate IS NULL THEN s.AllocDate ELSE t.AllocDate END  
   ,PickDate =CASE WHEN t.PickDate  IS NULL THEN s.PickDate  ELSE t.PickDate END  
   ,ShipDate=s.ShipDate  
   ,CancDate=s.CancDate  
WHEN NOT MATCHED THEN  
   INSERT (  OrderKey , StorerKey, ExternOrderKey,   DeliveryDate,   ConsigneeKey,   C_City  
   ,   Status,  Type,   OrderGroup,   AddDate,   EditDate  
   ,  MBOLKey,   LoadKey,   Facility,   ShipperKey,   DocType,   TrackingNo ,   ECOM_PRESALE_FLAG  
   , PreSale, ECOM_SINGLE_FLAG  
   ,UserDefine01 ,UserDefine02 ,UserDefine03  
   ,  Lines,  Units  
   ,  PickDet_Lines,  Orders_Open,  Lines_Open,  Units_Open  
   ,  Orders_ALLOC,  Lines_ALLOC,  Units_ALLOC  
   ,  Orders_Pick_Packed,  Lines_Pick_Packed,  Units_Pick_Packed  
   ,  Orders_Shipped,  Lines_Shipped,  Units_Shipped  
   ,  Orders_Cancelled,  Lines_Cancelled,  Units_Cancelled  
   ,  PickDetails_Inserted,  Orders_OverRun,  Orders_PendBuildLoad  
   ,  MBOL_NotValid,  AllocDate,  PickDate,  ShipDate,  CancDate )  
   VALUES (s.OrderKey, s.StorerKey, s.ExternOrderKey, s.DeliveryDate, s.ConsigneeKey, s.C_City  
   , s.Status,s.Type,s.OrderGroup,s.AddDate,s.EditDate  
   ,s.MBOLKey,s.LoadKey,s.Facility,s.ShipperKey,s.DocType,s.TrackingNo ,s.ECOM_PRESALE_FLAG  
   ,s.PreSale, s.ECOM_SINGLE_FLAG  
   ,s.UserDefine01 ,s.UserDefine02 ,s.UserDefine03  
   ,s.Lines,s.Units  
   ,s.PickDet_Lines,s.Orders_Open,s.Lines_Open,s.Units_Open  
   ,s.Orders_ALLOC,s.Lines_ALLOC,s.Units_ALLOC  
   ,s.Orders_Pick_Packed,s.Lines_Pick_Packed,s.Units_Pick_Packed  
   ,s.Orders_Shipped,s.Lines_Shipped,s.Units_Shipped  
   ,s.Orders_Cancelled,s.Lines_Cancelled,s.Units_Cancelled  
   ,s.PickDetails_Inserted,s.Orders_OverRun,s.Orders_PendBuildLoad  
   ,s.MBOL_NotValid  
   ,s.AllocDate  
   ,s.PickDate  
   ,s.ShipDate  
   ,s.CancDate )  
OUTPUT $action INTO @SummaryOfChanges;  
  
   SELECT @DurationSP = DATEDIFF(s,@GetDate,GETDATE()), @RowCnt = @@ROWCOUNT;  
   EXEC dbo.ispLogQuery @DB, @Schema, @Proc, @Id, 'WITH O AS... MERGE...', @DurationSP, @RowCntMain, 'BI.OrderSum', @SQLId OUTPUT;  
   IF @b_debug=1 SELECT 'MERGE UPSERT', Spent=DATEDIFF(ms,@GetDate,GETDATE()), RowCnt=@RowCnt;  
  
-- Query the results of the table variable.  
IF @b_debug = 1  
BEGIN  
   SELECT Change, COUNT(*) AS CountPerChange  
   FROM @SummaryOfChanges  
   GROUP BY Change;  
END  
  
END

GO