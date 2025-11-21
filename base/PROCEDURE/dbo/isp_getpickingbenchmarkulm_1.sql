SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Store Procedure: isp_GetPickingBenchmarkULM                          */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose: Picking Benchmark for Unilever                              */    
/*                                                                      */    
/* Called By: SQL Reporting Services                                    */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/* 03-11-2011   Audrey    1.0   SOS#229589 - fix date conversion (ang01)*/  
/* 14/10/2013   CSCHONG   2.0   SOS#288266  (CS01)                      */    
/* 21/10/2013   CSCHONG   3.0   Add in new parameter UOM (CS02)         */  
/* 30/10/2013   CSCHONG   4.0   For calculation formula  (CS03)         */  
/* 12/12/2013   CSCHONG   5.0   To display based on current time (CS04) */  
/* 08/01/2014   CSCHONG   6.0   After 12am not show all (CS05)          */  
/* 28/01/2014   CSCHONG   7.0   Filter by editdate(SOS301263) (CS06)    */  
/************************************************************************/    
    
CREATE PROC [dbo].[isp_GetPickingBenchmarkULM_1] (    
   @cStorerKey NVARCHAR(15),    
   @cListName  NVARCHAR(10),  
   @cFacility  NVARCHAR(250),  
   @cUOM       NVARCHAR(20),  
   @b_debug    char(10) = 0   
)    
AS    
BEGIN    
   SET NOCOUNT ON    
    
   DECLARE @nHour      INT,    
           @nPickedQty decimal(10,2)    
   /*CS04 Start*/  
   DECLARE @CurHour    INT,   
           @starthour  INT,  
           @endhour    INT,  
           @OStartHour INT,  
           @OEndHour   INT  
  
   set @starthour=11  
   SET @OStartHour = 0  
   SET @OEndHour = 0  
  
  /*CS04 END*/  
  
   IF OBJECT_ID('tempdb..#t_PickingBenchmark') IS NOT NULL    
      DROP TABLE #t_PickingBenchmark    
    
   CREATE TABLE #t_PickingBenchmark (    
      RowID INT IDENTITY(1,1),    
      Title      NVARCHAR(50),    
      FromHour   INT,    
      ToHour     INT,    
      PlanedQty  INT,    
      AccmPlnQty INT,    
      PickedQty  Decimal(10,2),    
      AccmPicked Decimal(10,2),    
      Percentage INT )    
  
       
   IF OBJECT_ID('tempdb..#t_PickingDetail') IS NOT NULL    
      DROP TABLE #t_PickingDetail    
  
   CREATE TABLE #t_PickingDetail (    
      RowID INT IDENTITY(1,1),    
      [Status]     NVARCHAR(2) NULL,    
      Storerkey    NVARCHAR(15) NULL,    
      Facility     NVARCHAR(5) NULL,  
      Editdate     DATETIME,    --CS06  
      Qty          INT NULL,    
      Qty_PCS      INT NULL,    
      Qty_CaseCnt  Decimal(10,2) NULL,    
      Qty_Pallet   Decimal(10,2) NULL)   
    
   IF NOT EXISTS(SELECT 1 FROM CODELKUP WITH (NOLOCK)    
                 WHERE LISTNAME = @cListName )    
   BEGIN    
      GOTO EXIT_PROC    
   END    
    
   IF EXISTS(SELECT 1 FROM  CODELKUP WITH (NOLOCK)    
             WHERE LISTNAME = @cListName    
             AND (ISNUMERIC(LEFT(Code,2)) <> 1 OR ISNUMERIC(Substring(Code,4,2)) <> 1 ))    
   BEGIN    
      GOTO EXIT_PROC    
   END    
      
   /*CS04 start*/  
   SELECT TOP 1 @CurHour = datepart(hour,getdate())  
   FROM CODELKUP WITH (NOLOCK)  
    
  
   IF @CurHour >= @starthour   
   BEGIN  
     SET @endhour = @CurHour  
   END  
   ELSE  
   BEGIN  
     SET @endhour=24  
     SET @Ostarthour = 1  
     SET @Oendhour = @CurHour  
   END  
  
   /*CS04 END*/  
  
   IF @cStorerKey <> 'Unilever'  
   BEGIN  
   INSERT INTO #t_PickingBenchmark    
          (Title, FromHour, ToHour, PlanedQty, AccmPlnQty, PickedQty, AccmPicked, Percentage)    
   SELECT [Description],    
          CAST(LEFT(Code,2) AS INT),    
          CAST(Substring(Code,4,2) AS INT),    
          CAST(Short AS INT), 0, 0, 0, 0    
   FROM  CODELKUP WITH (NOLOCK)    
   WHERE LISTNAME = @cListName  
   AND ISNULL(StorerKey,'') = ''  
   END  
   ELSE  
   BEGIN  
   INSERT INTO #t_PickingBenchmark    
          (Title, FromHour, ToHour, PlanedQty, AccmPlnQty, PickedQty, AccmPicked, Percentage)    
   SELECT [Description],    
          CAST(LEFT(Code,2) AS INT),    
          CAST(Substring(Code,4,2) AS INT),    
          CAST(Short AS INT), 0, 0, 0, 0    
   FROM  CODELKUP WITH (NOLOCK)    
   WHERE LISTNAME = @cListName  
   AND   ISNULL(StorerKey,'') = @cStorerKey  
   AND  (CAST(LEFT(Code,2) AS INT)between @starthour and @EndHour OR  
         CAST(LEFT(Code,2) AS INT)between @Ostarthour and @OEndHour)   --CS04   
   Order by editdate  
   END    
  
       If @b_debug = '1'  
       BEGIN  
         SELECT * FROM #t_PickingBenchmark (NOLOCK)  
         PRINT 'Facility ' + @cFacility   
       END  
    
      UPDATE #t_PickingBenchmark    
      SET ToHour = ToHour - 1    
    
      SET @nPickedQty = 0    
  
     INSERT INTO #t_PickingDetail  
     ([Status],Storerkey,Facility,Editdate,Qty,Qty_PCS,Qty_CaseCnt,Qty_Pallet)  
      SELECT PK.STATUS, PK.STORERKEY, S.FACILITY, PK.EditDATE, PK.QTY, SUM(PK.QTY/nullif(P.QTY,0)) ,  
      convert(decimal(10,4),SUM(ISNULL(PK.QTY/nullif(P.CASECNT,0),0))) , convert(decimal(10,4),SUM(ISNULL(PK.QTY/nullif(P.PALLET,0),0)))    
      FROM PICKDETAIL PK, SKU S, PACK P (NOLOCK)  
      WHERE PK.STORERKEY = S.STORERKEY  
      AND PK.SKU = S.SKU  
      AND S.PACKKEY = P.PACKKEY  
      AND PK.STATUS >= '5'  
      --AND PK.StorerKey = @cStorerKey  
      --AND CONVERT(VarChar(8), PK.AddDate, 112) = CONVERT(VarChar(8), GETDATE(), 112)    
      AND CONVERT(VarChar(8), PK.EditDate, 112) = CONVERT(VarChar(8), GETDATE(), 112)    --CS06  
      GROUP BY PK.STATUS, PK.STORERKEY, S.FACILITY, PK.EditDATE, PK.QTY  
      ORDER BY PK.EditDATE  
  
   IF @b_debug='1'  
   BEGIN  
     SELECT * FROM #t_PickingDetail  
   END  
    
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
  
 /*  IF @cStorerKey <> 'Unilever'  
   BEGIN  
   SELECT DATEPART(HOUR, EventDateTime) As PickHour, SUM(Qty) AS Qty    
   FROM rdt.V_RDT_EventLog_Picking WITH (NOLOCK)    
   WHERE StorerKey = @cStorerKey    
   AND ActionType = '3'    
   AND Facility = @cFacility  
   -- AND EventDateTime BETWEEN CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102))    
   --                       AND CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102) + ' 23:59:59')    
   AND CONVERT(VarChar(8), EventDateTime, 112) = CONVERT(VarChar(8), GETDATE()-28, 112) --SOS#229589    
   GROUP BY DATEPART(HOUR, EventDateTime)    
   END  
   ELSE  
   BEGIN  
     IF @cUOM = 'Pallet'   
     BEGIN  
     SELECT DATEPART(HOUR, EventDateTime) As PickHour, SUM( v.qty/pallet) AS Qty    
     FROM rdt.V_RDT_EventLog_Picking V WITH (NOLOCK) JOIN SKU S WITH (NOLOCK) ON S.SKU = V.SKU and s.storerkey=v.storerkey  
     JOIN Pack P (NOLOCK) ON P.Packkey=s.Packkey    
     WHERE StorerKey = @cStorerKey    
     AND ActionType = '3'    
     AND Facility = @cFacility  
     -- AND EventDateTime BETWEEN CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102))    
     --                       AND CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102) + ' 23:59:59')    
     AND CONVERT(VarChar(8), EventDateTime, 112) = CONVERT(VarChar(8), GETDATE()-28, 112) --SOS#229589    
     GROUP BY DATEPART(HOUR, EventDateTime)   
     END  
     ELSE IF @cUOM = 'CaseCnt'  
     BEGIN  
     SELECT DATEPART(HOUR, EventDateTime) As PickHour, SUM( v.qty/casecnt) AS Qty    
     FROM rdt.V_RDT_EventLog_Picking V WITH (NOLOCK) JOIN SKU S WITH (NOLOCK) ON S.SKU = V.SKU and s.storerkey=v.storerkey  
     JOIN Pack P (NOLOCK) ON P.Packkey=s.Packkey    
     WHERE StorerKey = @cStorerKey    
     AND ActionType = '3'    
     AND Facility = @cFacility  
     -- AND EventDateTime BETWEEN CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102))    
     --                       AND CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102) + ' 23:59:59')    
     AND CONVERT(VarChar(8), EventDateTime, 112) = CONVERT(VarChar(8), GETDATE()-28, 112) --SOS#229589    
     GROUP BY DATEPART(HOUR, EventDateTime)   
     END  
     ELSE IF @cUOM = 'Pcs'  
     BEGIN*/  
      
    /* SELECT DATEPART(HOUR, EventDateTime) As PickHour, CAST(SUM(v.qty/casecnt) AS Decimal(10,2)) AS Qty                                            --(CS03)  
     FROM rdt.V_RDT_EventLog_Picking V WITH (NOLOCK) JOIN SKU S WITH (NOLOCK) ON S.SKU = V.SKU and s.storerkey=v.storerkey  
     JOIN Pack P (NOLOCK) ON P.Packkey=s.Packkey    
     WHERE v.StorerKey = @cStorerKey    
     AND ActionType = '3'    
     --AND v.Facility = case when @cFacility = 'Select All' Then v.Facility ELSE @cFacility END  
     AND v.facility in (select colvalue FROM dbo.fnc_DelimSplit(',',@cFacility))  
     AND v.UOM = @cUOM  
     -- AND EventDateTime BETWEEN CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102))    
     --                       AND CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102) + ' 23:59:59')    
     AND CONVERT(VarChar(8), EventDateTime, 112) = CONVERT(VarChar(8), GETDATE(), 112) --SOS#229589    
     GROUP BY DATEPART(HOUR, EventDateTime) */  
  
      SELECT DATEPART(HOUR, PD.EditDate) As PickHour, (CASE WHEN @cUOM = 1 THEN SUM(Qty_Pallet)  
      WHEN  @cUOM = 2 THEN SUM(Qty_CaseCnt)   
      WHEN  @cUOM = 6 THEN SUM(Qty_Pcs)     
      ELSE SUM(Qty) END)                                       --(CS03)  
     FROM #t_PickingDetail PD WITH (NOLOCK)   
     WHERE PD.StorerKey = @cStorerKey       
     --AND status > '5'    
     --AND v.Facility = case when @cFacility = 'Select All' Then v.Facility ELSE @cFacility END  
     AND PD.facility in (select colvalue FROM dbo.fnc_DelimSplit(',',@cFacility))  
     --AND PD.UOM = @cUOM  
     -- AND EventDateTime BETWEEN CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102))    
     --                       AND CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102) + ' 23:59:59')    
     --AND CONVERT(VarChar(8), PD.AddDate, 112) = CONVERT(VarChar(8), GETDATE(), 112) --SOS#229589    
     GROUP BY DATEPART(HOUR, PD.EditDate)  
   
    /* SELECT DATEPART(HOUR, PD.AddDate) As PickHour, CAST(SUM(case when PD.uom=2 then PD.qty/casecnt  
     when PD.uom=1 then PD.qty/pallet ELSE PD.qty END) AS Decimal(10,2)) AS Qty                                            --(CS03)  
     FROM pickdetail PD WITH (NOLOCK) JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU and s.storerkey=PD.storerkey  
     JOIN Pack P (NOLOCK) ON P.Packkey=s.Packkey    
     WHERE PD.StorerKey = @cStorerKey    
     AND status > '5'    
     --AND v.Facility = case when @cFacility = 'Select All' Then v.Facility ELSE @cFacility END  
     AND S.facility in (select colvalue FROM dbo.fnc_DelimSplit(',',@cFacility))  
     AND PD.UOM = @cUOM  
     -- AND EventDateTime BETWEEN CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102))    
     --                       AND CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102) + ' 23:59:59')    
     AND CONVERT(VarChar(8), PD.AddDate, 112) = CONVERT(VarChar(8), GETDATE(), 112) --SOS#229589    
     GROUP BY DATEPART(HOUR, PD.AddDate)*/  
  
       
  
  -- END  
    
   OPEN CUR1    
    
   FETCH NEXT FROM CUR1 INTO @nHour, @nPickedQty    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
  
       If @b_debug = '1'  
       BEGIN  
         PRINT 'hour pick ' + convert(varchar(50),@nHour) + 'Pick qty : ' +  convert(varchar(50),@nPickedQty)  
       END  
  
      UPDATE #t_PickingBenchmark    
      SET PickedQty = PickedQty + @nPickedQty    
      WHERE @nHour BETWEEN FromHour AND ToHour    
  
       If @b_debug = '1'  
       BEGIN  
         SELECT 'Update Pick Qty'  
         SELECT *    
         FROM #t_PickingBenchmark   
       END  
    
   FETCH NEXT FROM CUR1 INTO @nHour, @nPickedQty    
   END    
   CLOSE CUR1    
   DEALLOCATE CUR1    
    
   DECLARE @nPlannedQty INT,    
           @nRowID      INT,    
           @nTotPlanQty INT,    
           @nTotPickQty Decimal(10,2)    
    
   SET @nTotPlanQty = 0    
   SET @nTotPickQty = 0    
    
   DECLARE CUR2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT RowID, PlanedQty, PickedQty    
   FROM #t_PickingBenchmark    
    
   OPEN CUR2    
    
   FETCH NEXT FROM CUR2 INTO @nRowID, @nPlannedQty, @nPickedQty    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
       If @b_debug = '1'  
       BEGIN  
         SELECT 'GET Plan & pick Qty'  
         SELECT *   
         FROM #t_PickingBenchmark   
       END  
      
       If @b_debug = '1'  
       BEGIN  
         PRINT 'Plan qty : ' +  convert(varchar(15),@nPlannedQty)   
         PRINT 'Pick qty : ' +  convert(varchar(15),@nPickedQty)  
       END  
       SET @nTotPlanQty = @nTotPlanQty + @nPlannedQty    
       SET @nTotPickQty = @nTotPickQty + @nPickedQty    
  
       If @b_debug = '1'  
       BEGIN  
         PRINT 'Sum Plan qty : ' +  convert(varchar(15),@nTotPlanQty)   
         PRINT 'Sum Pick qty : ' +  convert(varchar(15),@nTotPickQty)  
       END  
    
      UPDATE #t_PickingBenchmark    
      SET AccmPlnQty = @nTotPlanQty, AccmPicked = @nTotPickQty    
      WHERE RowID = @nRowID    
    
   FETCH NEXT FROM CUR2 INTO @nRowID, @nPlannedQty, @nPickedQty    
   END    
   CLOSE CUR2    
   DEALLOCATE CUR2    
    
   UPDATE #t_PickingBenchmark    
   SET Percentage = CEILING(((AccmPicked * 1.00) / AccmPlnQty) * 100)    
    
EXIT_PROC:    
   SET FMTONLY OFF    
   SELECT Title, PlanedQty, AccmPlnQty, PickedQty, AccmPicked, Percentage    
   FROM #t_PickingBenchmark    
END    

GO