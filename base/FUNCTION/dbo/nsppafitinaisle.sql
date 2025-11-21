SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: nspPAFitInAisle                                     */
/* Copyright: IDS                                                       */
/* Purpose: Fit UCC on pallet in an aisle                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-11-28   Ung       1.0   SOS257227 Fit by aisle                  */
/* 2016-06-06   Ung       1.1   IN00057923 Cater UCC.Status=3           */
/* 2017-06-05   ChewKP    1.1   WMS-1956 Fit by Aisle Multi Case Count  */
/*                              (ChewKP01)                              */
/************************************************************************/

CREATE FUNCTION [dbo].[nspPAFitInAisle](
   @c_PAStrategyKey     NVARCHAR(10),
   @c_PAStrategyLineNo  NVARCHAR(5),
   @c_NextPnDAisle      NVARCHAR(10), 
   @c_StorerKey         NVARCHAR(15),
   @c_Facility          NVARCHAR(5), 
   @c_FromLOC           NVARCHAR(10), 
   @cpa_DimensionRestriction01 NVARCHAR(5),
   @cpa_DimensionRestriction02 NVARCHAR(5),
   @cpa_DimensionRestriction03 NVARCHAR(5),
   @cpa_DimensionRestriction04 NVARCHAR(5),
   @cpa_DimensionRestriction05 NVARCHAR(5),
   @cpa_DimensionRestriction06 NVARCHAR(5),
   @c_ID                NVARCHAR(18)
   
) RETURNS INT AS
BEGIN
   DECLARE @tLOCPendingMoveIn TABLE 
   (
         LOC                NVARCHAR( 10) NOT NULL, 
         PendingMoveInIDCnt INT           NOT NULL
   )

   DECLARE @tUCCPendingMoveIn TABLE
   (
      LOC    NVARCHAR( 10) NOT NULL, 
      UCCNo  NVARCHAR( 20) NOT NULL, 
      SKU    NVARCHAR( 20) NOT NULL, 
      QTY    INT           NOT NULL
   )

   DECLARE @cLOC     NVARCHAR( 10)
   DECLARE @cUCC     NVARCHAR( 20)
   DECLARE @cUCCSKU  NVARCHAR( 20)
   DECLARE @nUCCQTY  INT
   DECLARE @nFitInAisle INT

   DECLARE @cpa_LocationCategoryInclude01  NVARCHAR(10)
   DECLARE @cpa_LocationCategoryInclude02  NVARCHAR(10)
   DECLARE @cpa_LocationCategoryInclude03  NVARCHAR(10)
   DECLARE @cpa_LocationHandlingInclude01  NVARCHAR(10)
   DECLARE @cpa_LocationHandlingInclude02  NVARCHAR(10)
   DECLARE @cpa_LocationHandlingInclude03  NVARCHAR(10)

   SELECT 
      @cpa_LocationCategoryInclude01 = LocationCategoryInclude01,
      @cpa_LocationCategoryInclude02 = LocationCategoryInclude02,
      @cpa_LocationCategoryInclude03 = LocationCategoryInclude03,
      @cpa_LocationHandlingInclude01 = LocationHandlingInclude01,
      @cpa_LocationHandlingInclude02 = LocationHandlingInclude02,
      @cpa_LocationHandlingInclude03 = LocationHandlingInclude03
   FROM dbo.PutawayStrategyDetail WITH (NOLOCK)
   WHERE PutAwayStrategyKey = @c_PAStrategyKey 
       AND PutawayStrategyLineNumber = @c_PAStrategyLineNo

   DECLARE @curUCC CURSOR
   SET @curUCC = CURSOR FOR
      SELECT DISTINCT UCCNo 
      FROM dbo.UCC WITH (NOLOCK)
      WHERE LOC = @c_FromLOC
         AND ID = @c_ID
         AND Status = '1'
   OPEN @curUCC
   FETCH NEXT FROM @curUCC INTO @cUCC
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get UCC info
      SET @cUCCSKU = ''
      SET @nUCCQTY =  0
      SELECT 
         @cUCCSKU = SKU, 
         @nUCCQTY = QTY
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey
         AND UCCNo = @cUCC
      
      IF '18' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,  
                              @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)  
      BEGIN
      -- Find LOC in an aisle that fit the UCC count (LOC.MaxPallet)
         SET @cLOC = ''
            SELECT TOP 1 
               @cLOC = LOC.LOC
            FROM dbo.LOC WITH (NOLOCK)
               LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC AND (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0))
               LEFT JOIN UCC WITH (NOLOCK) ON (LLI.LOT = UCC.LOT AND LLI.LOC = UCC.LOC AND LLI.ID = UCC.ID AND UCC.Status IN ('1', '3'))
               LEFT JOIN @tLOCPendingMoveIn t ON (t.LOC = LOC.LOC)
            WHERE LOC.Facility = @c_Facility
               AND LOC.LOCAisle = @c_NextPnDAisle
               AND NOT EXISTS( 
                   SELECT 1 
                   FROM dbo.UCC WITH (NOLOCK)
                   WHERE StorerKey = @c_StorerKey
                      AND SKU = @cUCCSKU
                      AND QTY <> @nUCCQTY
                      AND Status IN ('1', '3')
                      AND LOC = LOC.LOC)
               AND NOT EXISTS( 
                   SELECT 1 
                   FROM @tUCCPendingMoveIn 
                   WHERE SKU = @cUCCSKU 
                      AND QTY <> @nUCCQTY
                      AND LOC = LOC.LOC)
               AND LOC.LocationCategory IN (
                  CASE WHEN @cpa_LocationCategoryInclude01 = '' AND @cpa_LocationCategoryInclude02 = '' AND @cpa_LocationCategoryInclude03 = '' 
                  THEN LOC.LocationCategory
                  ELSE ( 
                     SELECT @cpa_LocationCategoryInclude01 WHERE @cpa_LocationCategoryInclude01 <> '' UNION 
                     SELECT @cpa_LocationCategoryInclude02 WHERE @cpa_LocationCategoryInclude02 <> '' UNION 
                     SELECT @cpa_LocationCategoryInclude03 WHERE @cpa_LocationCategoryInclude03 <> '' )
                  END)
               AND LOC.LocationHandling IN (
                  CASE WHEN @cpa_LocationHandlingInclude01 = '' AND @cpa_LocationHandlingInclude02 = '' AND @cpa_LocationHandlingInclude03 = '' 
                  THEN LOC.LocationHandling
                  ELSE (
                     SELECT @cpa_LocationHandlingInclude01 WHERE @cpa_LocationHandlingInclude01 <> '' UNION 
                     SELECT @cpa_LocationHandlingInclude02 WHERE @cpa_LocationHandlingInclude02 <> '' UNION 
                     SELECT @cpa_LocationHandlingInclude03 WHERE @cpa_LocationHandlingInclude03 <> '' )
                  END)
            GROUP BY LOC.LogicalLocation, LOC.LOC, LOC.MaxPallet, t.PendingMoveInIDCnt
            HAVING ISNULL( COUNT( DISTINCT 
               CASE WHEN UCC.UCCNo IS NOT NULL THEN UCC.UCCNO 
                    WHEN LLI.ID    IS NOT NULL THEN LLI.ID 
                    ELSE NULL 
               END), 0)
               + ISNULL( t.PendingMoveInIDCnt, 0) + 1 <= LOC.MaxPallet  --LOC ID Cnt + PendingMoveInIDCnt + UCC (1)
            ORDER BY LOC.LogicalLocation, LOC.LOC
      END
      ELSE
      IF '19' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,  
                              @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)  
      BEGIN
      -- Find LOC in an aisle that fit the UCC count (LOC.MaxPallet)
         SET @cLOC = ''
            SELECT TOP 1 
               @cLOC = LOC.LOC
            FROM dbo.LOC WITH (NOLOCK)
               LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC AND (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0))
               LEFT JOIN UCC WITH (NOLOCK) ON (LLI.LOT = UCC.LOT AND LLI.LOC = UCC.LOC AND LLI.ID = UCC.ID AND UCC.Status IN ('1', '3'))
               LEFT JOIN @tLOCPendingMoveIn t ON (t.LOC = LOC.LOC)
            WHERE LOC.Facility = @c_Facility
               AND LOC.LOCAisle = @c_NextPnDAisle
               AND LOC.LocationCategory IN (
                  CASE WHEN @cpa_LocationCategoryInclude01 = '' AND @cpa_LocationCategoryInclude02 = '' AND @cpa_LocationCategoryInclude03 = '' 
                  THEN LOC.LocationCategory
                  ELSE ( 
                     SELECT @cpa_LocationCategoryInclude01 WHERE @cpa_LocationCategoryInclude01 <> '' UNION 
                     SELECT @cpa_LocationCategoryInclude02 WHERE @cpa_LocationCategoryInclude02 <> '' UNION 
                     SELECT @cpa_LocationCategoryInclude03 WHERE @cpa_LocationCategoryInclude03 <> '' )
                  END)
               AND LOC.LocationHandling IN (
                  CASE WHEN @cpa_LocationHandlingInclude01 = '' AND @cpa_LocationHandlingInclude02 = '' AND @cpa_LocationHandlingInclude03 = '' 
                  THEN LOC.LocationHandling
                  ELSE (
                     SELECT @cpa_LocationHandlingInclude01 WHERE @cpa_LocationHandlingInclude01 <> '' UNION 
                     SELECT @cpa_LocationHandlingInclude02 WHERE @cpa_LocationHandlingInclude02 <> '' UNION 
                     SELECT @cpa_LocationHandlingInclude03 WHERE @cpa_LocationHandlingInclude03 <> '' )
                  END)
            GROUP BY LOC.LogicalLocation, LOC.LOC, LOC.MaxPallet, t.PendingMoveInIDCnt
            HAVING ISNULL( COUNT( DISTINCT 
               CASE WHEN UCC.UCCNo IS NOT NULL THEN UCC.UCCNO 
                    WHEN LLI.ID    IS NOT NULL THEN LLI.ID 
                    ELSE NULL 
               END), 0)
               + ISNULL( t.PendingMoveInIDCnt, 0) + 1 <= LOC.MaxPallet  --LOC ID Cnt + PendingMoveInIDCnt + UCC (1)
            ORDER BY LOC.LogicalLocation, LOC.LOC
      END
      
      -- Save
      IF @cLOC <> ''
      BEGIN
         -- Insert UCC PendingMoveIn
         INSERT INTO @tUCCPendingMoveIn (LOC, UCCNo, SKU, QTY) VALUES (@cLOC, @cUCC, @cUCCSKU, @nUCCQTY)

         -- Update LOC PendingMoveIn
         IF NOT EXISTS( SELECT 1 FROM @tLOCPendingMoveIn WHERE LOC = @cLOC)
            INSERT INTO @tLOCPendingMoveIn (LOC, PendingMoveInIDCnt) VALUES (@cLOC, 1)
         ELSE
            UPDATE @tLOCPendingMoveIn SET 
               PendingMoveInIDCnt = PendingMoveInIDCnt + 1 
            WHERE LOC = @cLOC

         SET @nFitInAisle = 1 --TRUE
      END
      ELSE
      BEGIN
         SET @nFitInAisle = 0 --FALSE
         BREAK
      END
      FETCH NEXT FROM @curUCC INTO @cUCC
   END
   RETURN @nFitInAisle
END

GO