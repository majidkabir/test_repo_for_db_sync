SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************/                
/* Stored Procedure: isp_GetLCIOrderStatusReport_Data                            */                
/* Creation Date: 07-Mar-2012                                                    */                
/* Copyright: IDS                                                                */                
/* Written by: Shong                                                             */                
/*                                                                               */                
/* Purpose:  LCI Storer# 11388358 Order Status Report - Cutoff Extraction        */                
/*                                                                               */                
/* Called By:  From Data Mart Schedule Job - Running Daily 3am (CA Time 12am)    */                
/*                                                                               */                
/* PVCS Version: 10                                                              */                
/*                                                                               */                
/* Data Modifications:                                                           */                
/*                                                                               */                
/* Updates:                                                                      */                
/* Date           Author      Ver.  Purposes                                     */                
/* 2012-04-04     AAY001      1.1   GAPs between Report and Actual               */      
/* 2012-06-07     Shong       1.2   Get Qty Allocated from OD.EnteredQty         */      
/* 2012-06-20     TLTING      1.3   MBOL.Shipdate as markship date               */    
/* 2012-07-16     TLTING01    1.4   Replace MBOL.Shipdate filter to DepartureDate*/  
/* 2012-07-19     Shong       1.5   The departure date is entered in local time. */  
/*                                  There should not be any plus/minus by 3 hr   */ 
/* 2012-08-21     James       1.6   Bug fix (james01)                            */ 
/* 2012-10-03     James       1.7   Bug fix (james02)                            */ 
/* 2012-11-01     James       1.8   SOS260614 - For QtyAllocated, use            */
/*                                  EffectiveDate as selected date (james03)     */ 
/*********************************************************************************/                
      
CREATE PROC [dbo].[isp_GetLCIOrderStatusReport_Data]       
   (      
    @cStorerKey     NVARCHAR(15),      
    @cFacility      NVARCHAR(5),       
    @dDateSpecified DATETIME = NULL         
 )       
AS      
SET NOCOUNT ON      
SET ANSI_DEFAULTS OFF        
SET QUOTED_IDENTIFIER OFF      
SET CONCAT_NULL_YIELDS_NULL OFF     
      
DECLARE @d_StartDate DATETIME,      
        @d_EndDate   DATETIME,  
        @d_LocalStartDate DATETIME,      
        @d_LocalEndDate   DATETIME       
              
DECLARE @nQtyAllocated INT,      
        @nQtyPicked    INT,      
        @nQtyPacked    INT,      
        @nQtyShipped   INT,      
        @nShippable    INT,       
        @nFacility_BackLog  INT,      
        @nTot_PackAndHold   INT,       
        @nPicking_BackLog   INT,      
        @nPacking_BackLog   INT,      
        @nUnits_Stages      INT,      
        @nLoggedNotUploaded INT,      
        @nPickAndHold_Cplt  INT,      
        @nPacking_BackLog_ORD   INT, --AAY001      
        @nPacking_BackLog_LOC   INT, --AAY001      
        @nWCS_QtyPicked         INT,      
        @nWCS_QtyPacked         INT,      
        @nWCS_FCQtyPacked       INT  --james02
              
      
SET @nQtyAllocated     = 0      
SET @nQtyPicked         = 0      
SET @nQtyPacked         = 0      
SET @nQtyShipped        = 0      
SET @nShippable         = 0       
SET @nFacility_BackLog  = 0      
SET @nTot_PackAndHold   = 0       
SET @nPicking_BackLog   = 0      
SET @nPacking_BackLog   = 0      
SET @nUnits_Stages      = 0      
SET @nLoggedNotUploaded = 0          
SET @nPickAndHold_Cplt  = 0      
SET @nPacking_BackLog_ORD   = 0 --AAY001      
SET @nPacking_BackLog_LOC   = 0 --AAY001            
SET @nWCS_FCQtyPacked   = 0     --james02
      
IF @dDateSpecified IS NULL       
   SET @dDateSpecified = GETDATE()      
                
SET @d_StartDate = CONVERT(NVARCHAR(10), DATEADD(DAY, -1, @dDateSpecified), 112) + ' 03:00:00:000'      
SET @d_EndDate = CONVERT(NVARCHAR(10), @dDateSpecified, 112) + ' 02:59:59:998'     
  
  
SET @d_LocalStartDate = CONVERT(NVARCHAR(10), DATEADD(DAY, -1, @dDateSpecified), 112) + ' 00:00:00:000'      
SET @d_LocalEndDate   = CONVERT(NVARCHAR(10), DATEADD(DAY, -1, @dDateSpecified), 112) + ' 23:59:59:998'    
      
--SELECT @d_StartDate '@d_StartDate', @d_EndDate '@d_EndDate'      
      
IF OBJECT_ID('tempdb..#t_OrderStatus') IS NOT NULL      
   DROP TABLE #t_OrderStatus      
      
IF OBJECT_ID('tempdb..#t_Allocate') IS NOT NULL      
   DROP TABLE #t_Allocate      
         
SELECT 
   P.OrderKey, 
   ISNULL(SUM(EnteredQty),0) As Qty, 
--   MIN(O.AddDate) AS AddDate      
   MIN(O.EffectiveDate) AS AddDate        -- (james03)
INTO #t_Allocate      
FROM ORDERDETAIL p WITH (NOLOCK) --AAY001      
INNER JOIN ORDERS o WITH (NOLOCK) on o.OrderKey=p.OrderKey --AAY001      
WHERE O.StorerKey = @cStorerKey      
AND   O.Facility=@cFacility --AAY001      
--AND   O.AddDate >= @d_StartDate       
--AND   O.AddDate <= @d_EndDate      
AND   O.EffectiveDate >= @d_StartDate     -- (james03)
AND   O.EffectiveDate <= @d_EndDate     -- (james03)
GROUP BY P.OrderKey      
      
SELECT @nQtyAllocated  = ISNULL(SUM(Qty),0)        
FROM   #t_Allocate T      
WHERE  T.AddDate BETWEEN @d_StartDate AND @d_EndDate       
      
SELECT @nQtyPicked  = ISNULL(SUM(Qty),0)        
FROM RDT.rdtSTDEventLog rsl (NOLOCK)      
WHERE rsl.ActionType = '3'       
AND Facility = @cFacility      
AND rsl.FunctionID =950       
AND StorerKey = @cStorerKey       
AND rsl.EventDateTime BETWEEN @d_StartDate AND @d_EndDate       
      
-- Getting WCS Loose Pick      
SET @nWCS_QtyPicked = 0       
SELECT @nWCS_QtyPicked  = ISNULL(SUM(Qty_Actual),0)        
FROM V_TCP_WCS_BULK_PICK_IN twbpi      
WHERE twbpi.[Status] = '9'      
AND StorerKey = @cStorerKey      
AND twbpi.AddDate BETWEEN @d_StartDate AND @d_EndDate       
      
-- SET @nQtyPicked = @nQtyPicked + @nWCS_QtyPicked      
      
-- Getting WCS Full Case Pick       
-- Full Case Pick is a packing process; not picking process (james02)
--SET @nWCS_QtyPicked = 0       
SET @nWCS_FCQtyPacked = 0       
SELECT @nWCS_FCQtyPacked  = ISNULL(SUM(twfii.Qty_Actual),0)        
FROM V_TCP_WCS_FC_INDUCTION_IN twfii      
WHERE twfii.[Status] = '9'      
AND twfii.StorerKey = @cStorerKey      
AND twfii.AddDate BETWEEN @d_StartDate AND @d_EndDate       
      
--SET @nQtyPicked = @nQtyPicked + @nWCS_QtyPicked       
      
SELECT @nQtyPacked = ISNULL(ISNULL(SUM(Qty),0),0)        
FROM RDT.rdtSTDEventLog rsl (NOLOCK)      
WHERE rsl.ActionType = '4'       
AND Facility = @cFacility      
AND rsl.FunctionID =519       
AND StorerKey = @cStorerKey       
AND rsl.EventDateTime BETWEEN @d_StartDate AND @d_EndDate       

-- Getting CartonClose       
SET @nWCS_QtyPacked = 0       
SELECT @nWCS_QtyPacked = ISNULL(ISNULL(SUM(Qty),0),0)      
FROM dbo.fnc_GetTCPCartonCloseDetail(0) fgtcd       
WHERE fgtcd.[Status] = '9'      
AND fgtcd.AddDate BETWEEN @d_StartDate AND @d_EndDate       
      
SET @nQtyPacked = @nQtyPacked + @nWCS_QtyPacked + @nWCS_FCQtyPacked

/* Full Case Pick is a packing process; not picking process (james02)
-- Getting WCS Full Case Pick       
SET @nWCS_QtyPicked = 0       
SELECT @nWCS_QtyPicked  = ISNULL(SUM(twfii.Qty_Actual),0)        
FROM V_TCP_WCS_FC_INDUCTION_IN twfii      
WHERE twfii.[Status] = '9'      
AND twfii.StorerKey = @cStorerKey      
AND twfii.AddDate BETWEEN @d_StartDate AND @d_EndDate       
*/

-- SET @nQtyPacked = @nQtyPacked + @nWCS_QtyPacked       
SET @nQtyPicked = @nQtyPicked + @nWCS_QtyPicked          -- (james01)
      
SEt @nQtyShipped = 0       
SELECT @nQtyShipped = ISNULL(SUM(Qty),0)        
FROM PICKDETAIL PD WITH (NOLOCK)       
JOIN MBOLDETAIL MD WITH (NOLOCK) ON MD.OrderKey = PD.OrderKey       
JOIN MBOL M WITH (NOLOCK) ON MD.MbolKey = M.MbolKey       
--WHERE M.EditDate BETWEEN @d_StartDate AND @d_EndDate        
--WHERE M.ShipDate BETWEEN @d_StartDate AND @d_EndDate        
WHERE M.DepartureDate BETWEEN @d_LocalStartDate AND @d_LocalEndDate  -- tlting01 & Shong 19-07-2012  
AND PD.StorerKey = @cStorerKey       
AND M.[Status] = '9'      
            
/* --AAY001 START      
SELECT @nFacility_BackLog = SUM(O.OpenQty)        
FROM ORDERS O WITH (NOLOCK)      
WHERE O.StorerKey = @cStorerKey      
AND O.[Status] NOT IN ('9','CANC')      
*/      
      
SELECT       
@nFacility_BackLog =       
SUM(      
   CASE  O.[STATUS] WHEN '0'       
     THEN OD.OriginalQty      
     ELSE OD.QTYALLOCATED+OD.QTYPICKED      
     END      
)      
FROM ORDERS O WITH (NOLOCK)      
JOIN ORDERDETAIL OD WITH(NOLOCK) on O.OrderKey=OD.OrderKey      
WHERE O.StorerKey = @cStorerKey      
AND O.[Status] NOT IN ('9','CANC')      
AND O.Facility= @cFacility      
--AAY001 END      
      
      
/*--AAY001      
SELECT @nTot_PackAndHold = SUM(P.Qty)       
FROM PackDetail P WITH (NOLOCK)       
JOIN(      
SELECT PH.PickSlipno, OD.ConsoOrderKey, MAX(O.OrderDate) AS OrderDate        
FROM ORDERDETAIL OD WITH (NOLOCK)       
JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey       
JOIN PackHeader PH WITH (NOLOCK) ON PH.ConsoOrderKey = OD.ConsoOrderKey      
WHERE O.StorerKey = @cStorerKey      
AND   O.[Status] NOT IN ('CANC', '9')       
AND   PH.[Status] = '9'       
AND   OD.ConsoOrderKey <> '' AND OD.ConsoOrderKey IS NOT NULL      
GROUP BY PH.PickSlipno, OD.ConsoOrderKey) AS PackedOrder ON PackedOrder.PickSlipno = P.PickSlipno      
--WHERE PackedOrder.OrderDate > @d_EndDate      
*/      
      
SELECT @nTot_PackAndHold =       
SUM(      
    CASE  O.[STATUS] WHEN '0'       
     THEN OD.OriginalQty      
     ELSE OD.QTYALLOCATED+OD.QTYPICKED      
     END)      
FROM ORDERS O WITH (NOLOCK)      
JOIN ORDERDETAIL OD WITH(NOLOCK) on O.OrderKey=OD.OrderKey      
WHERE       
O.StorerKey = @cStorerKey      
AND O.[Status] NOT IN ('9','CANC')      
AND O.Facility= @cFacility      
and O.OrderDate > @d_EndDate      
      
      
      
/*      
SELECT @nPicking_BackLog = SUM(Qty)        
FROM PICKDETAIL P WITH (NOLOCK)      
WHERE P.Storerkey = @cStorerKey       
AND P.[Status] < '5'       
AND P.AddDate < @d_EndDate      
*/      
--AAY001      
      
SELECT @nPicking_BackLog =       
SUM(      
    CASE  O.[STATUS] WHEN '0'       
     THEN OD.OriginalQty      
     ELSE OD.QTYALLOCATED      
     END)      
FROM ORDERS O WITH (NOLOCK)      
JOIN ORDERDETAIL OD WITH(NOLOCK) on O.OrderKey=OD.OrderKey      
WHERE       
O.StorerKey = @cStorerKey      
AND O.[Status] < '5'      
AND O.Facility= @cFacility      
      
      
DECLARE @nTotQtyPicked INT,      
        @nTotQtyPacked INT      
      
SELECT @nTotQtyPicked = SUM(Qty)        
FROM PICKDETAIL P WITH (NOLOCK)      
WHERE P.Storerkey = @cStorerKey       
AND P.[Status] = '5'       
--AND P.AddDate < @d_EndDate      
              
/* --AAY001 START      
SELECT @nTotQtyPacked = SUM(P.Qty)        
FROM PackDetail P WITH (NOLOCK)       
JOIN(      
SELECT PH.PickSlipno, OD.ConsoOrderKey, MAX(O.OrderDate) AS OrderDate        
FROM ORDERDETAIL OD WITH (NOLOCK)       
JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey       
JOIN PackHeader PH WITH (NOLOCK) ON PH.ConsoOrderKey = OD.ConsoOrderKey      
WHERE O.StorerKey = @cStorerKey      
AND   O.[Status] NOT IN ('CANC', '9')       
AND   PH.[Status] = '9'       
AND   OD.ConsoOrderKey <> '' AND OD.ConsoOrderKey IS NOT NULL      
GROUP BY PH.PickSlipno, OD.ConsoOrderKey) AS PackedOrder ON PackedOrder.PickSlipno = P.PickSlipno      
*/ --AAY001      
      
SELECT @nTotQtyPacked = sum(P.Qty)       
FROM PackDetail P WITH (NOLOCK)       
WHERE P.PickSlipno in (      
SELECT PickSlipno       
FROM PackHeader PH WITH (NOLOCK)       
where StorerKey= @cStorerKey )      
AND P.ADDDATE BETWEEN @d_StartDate AND @d_EndDate      
      
      
--SELECT @nTotQtyPicked '@nTotQtyPicked', @nTotQtyPacked '@nTotQtyPacked'      
      
/*      
IF @nTotQtyPicked > @nTotQtyPacked      
   SELECT @nPacking_BackLog = (@nTotQtyPicked - @nTotQtyPacked)      
ELSE         
   SET @nPacking_BackLog = 0       
*/      
      
      
--AAY001 START      
SELECT  @nPacking_BackLog_ORD = SUM(QTYPICKED)      
FROM ORDERDETAIL OD WITH (NOLOCK)       
JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey       
JOIN PackHeader PH WITH (NOLOCK) ON PH.ConsoOrderKey = OD.ConsoOrderKey      
WHERE O.StorerKey = @cStorerKey      
AND   O.Facility = @cFacility      
AND   O.[Status] NOT IN ('CANC', '9')      
AND   PH.[Status] < '9'       
AND   OD.ConsoOrderKey <> '' AND OD.ConsoOrderKey IS NOT NULL      
GROUP BY PH.PickSlipno, OD.ConsoOrderKey      
      
      
SELECT @nPacking_BackLog_LOC = SUM(LLI.QTY)      
FROM LOTXLOCXID LLI WITH (NOLOCK)       
JOIN LOC L WITH (NOLOCK) ON LLI.LOC=L.LOC      
WHERE LLI.STORERKEY = @cStorerKey      
AND L.Facility= @cFacility      
AND L.LocationCategory = 'PACK&HOLD'      
      
SELECT @nPacking_BackLog = @nPacking_BackLog_ORD +  @nPacking_BackLog_LOC      
--AAY001 END      
      
      
         
SELECT @nShippable = @nFacility_BackLog - @nTot_PackAndHold      
      
/*      
SELECT @nUnits_Stages = @nTotQtyPacked       
*/      
SELECT @nUnits_Stages = SUM(qty)   
FROM PackDetail PD (NOLOCK)      
INNER JOIN PACKHEADER PH (NOLOCK) ON PH.PickSlipno=PD.PickSlipno      
WHERE PH.StorerKey = @cStorerKey   
  AND EXISTS   
   ( SELECT 1   
     FROM OrderDetail OD (NOLOCK)   
     JOIN Orders OH (NOLOCK) ON OD.OrderKey = OH.OrderKey   
     WHERE OH.Storerkey= @cStorerKey   
       AND OH.Status BETWEEN '4' AND '8'   
       AND OH.Facility=@cFacility  
       AND OD.ConsoOrderKey = PH.ConsoOrderKey )  
     
SET @nLoggedNotUploaded = 0       
SELECT @nLoggedNotUploaded = ISNULL(SUM(RD.QtyExpected),0)        
FROM RECEIPT (NOLOCK)       
JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.ReceiptKey = RECEIPT.ReceiptKey       
WHERE RECEIPT.Facility = @cFacility       
AND RECEIPT.StorerKey = @cStorerKey       
AND RECEIPT.ASNStatus <> '9'        
AND RD.FinalizeFlag <> 'Y'       
AND EXISTS( SELECT 1   
            FROM rdt.rdtSTDEventLog rsl WITH (NOLOCK)      
            WHERE rsl.FunctionID = 853      
            AND rsl.ActionType=13   
            AND RefNo1 = RECEIPT.USERDEFINE01 )        
--AND RECEIPT.AddDate > @d_EndDate  --AAY001      
      
SELECT @nPickAndHold_Cplt = SUM(P.Qty)       
FROM PackDetail P WITH (NOLOCK)       
JOIN(      
SELECT PH.PickSlipno, OD.ConsoOrderKey, MAX(O.OrderDate) AS OrderDate        
FROM ORDERDETAIL OD WITH (NOLOCK)       
JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey       
JOIN PackHeader PH WITH (NOLOCK) ON PH.ConsoOrderKey = OD.ConsoOrderKey      
WHERE O.StorerKey = @cStorerKey      
AND   O.[Status] NOT IN ('CANC', '9')      
AND   PH.[Status] = '9'       
AND   OD.ConsoOrderKey <> '' AND OD.ConsoOrderKey IS NOT NULL      
GROUP BY PH.PickSlipno, OD.ConsoOrderKey) AS PackedOrder ON PackedOrder.PickSlipno = P.PickSlipno      
WHERE PackedOrder.OrderDate > @d_EndDate      
      
SELECT CONVERT(NVARCHAR(12), @d_StartDate, 101) AS [RunDate],      
       CASE DATEPART(dw, @d_StartDate)      
      WHEN 1 THEN 'Sunday'       
         WHEN 2 THEN 'Monday'       
         WHEN 3 THEN 'Tuesday'       
         WHEN 4 THEN 'Wednesday'       
         WHEN 5 THEN 'Thursday'       
         WHEN 6 THEN 'Friday'       
         WHEN 7 THEN 'Saturday'       
       END AS [DayName],       
       @nQtyAllocated     'QtyAllocated', --OK      
       @nFacility_BackLog 'Facility_BackLog',  --OK      
       @nTot_PackAndHold  'Tot_PackAndHold', --OK      
       @nPicking_BackLog  'Picking_BackLog', --OK      
       @nPacking_BackLog  'Packing_BackLog', --OK      
       @nShippable    'Shippable', --OK      
       @nQtyPicked    'QtyPicked', --No Change      
       @nQtyPacked    'QtyPacked', --Maybe      
       @nQtyShipped   'QtyShipped', --OK      
       @nUnits_Stages 'Units_Stages', --OK      
       @nPickAndHold_Cplt  'PickAndHold_Completed', --No Change      
       @nLoggedNotUploaded 'LoggedNotUploaded' --OK

GO