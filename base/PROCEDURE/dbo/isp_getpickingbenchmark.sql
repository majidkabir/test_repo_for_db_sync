SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GetPickingBenchmark                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Picking Benchmark                                           */
/*                                                                      */
/* Called By: SQL Reporting Services                                   */
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
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickingBenchmark] (
   @cStorerKey NVARCHAR(15),
   @cListName  NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON

   DECLARE @nHour      INT,
           @nPickedQty INT

   IF OBJECT_ID('tempdb..#t_PickingBenchmark') IS NOT NULL
      DROP TABLE #t_PickingBenchmark

   CREATE TABLE #t_PickingBenchmark (
      RowID INT IDENTITY(1,1),
      Title      NVARCHAR(50),
      FromHour   INT,
      ToHour     INT,
      PlanedQty  INT,
      AccmPlnQty INT,
      PickedQty  INT,
      AccmPicked INT,
      Percentage INT )

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

   INSERT INTO #t_PickingBenchmark
          (Title, FromHour, ToHour, PlanedQty, AccmPlnQty, PickedQty, AccmPicked, Percentage)
   SELECT [Description],
          CAST(LEFT(Code,2) AS INT),
          CAST(Substring(Code,4,2) AS INT),
          CAST(Short AS INT), 0, 0, 0, 0
   FROM  CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = @cListName

   UPDATE #t_PickingBenchmark
      SET ToHour = ToHour - 1

   SET @nPickedQty = 0

   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DATEPART(HOUR, EventDateTime) As PickHour, SUM(Qty) AS Qty
   FROM rdt.V_RDT_EventLog_Picking WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND ActionType = '3'
   -- AND EventDateTime BETWEEN CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102))
   --                       AND CONVERT(datetime, CONVERT(VARCHAR(10), GETDATE(), 102) + ' 23:59:59')
   AND CONVERT(VarChar(8), EventDateTime, 112) = CONVERT(VarChar(8), GETDATE(), 112) --SOS#229589
   GROUP BY DATEPART(HOUR, EventDateTime)

   OPEN CUR1

   FETCH NEXT FROM CUR1 INTO @nHour, @nPickedQty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE #t_PickingBenchmark
      SET PickedQty = PickedQty + @nPickedQty
      WHERE @nHour BETWEEN FromHour AND ToHour

      FETCH NEXT FROM CUR1 INTO @nHour, @nPickedQty
   END
   CLOSE CUR1
   DEALLOCATE CUR1

   DECLARE @nPlannedQty INT,
           @nRowID      INT,
           @nTotPlanQty INT,
           @nTotPickQty INT

   SET @nTotPlanQty = 0
   SET @nTotPickQty = 0

   DECLARE CUR2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowID, PlanedQty, PickedQty
   FROM #t_PickingBenchmark

   OPEN CUR2

   FETCH NEXT FROM CUR2 INTO @nRowID, @nPlannedQty, @nPickedQty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @nTotPlanQty = @nTotPlanQty + @nPlannedQty
      SET @nTotPickQty = @nTotPickQty + @nPickedQty

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