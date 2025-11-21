SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_523ExtPA10                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 29-11-2017  1.0  ChewKP   WMS-3501 Created                           */
/* 30-01-2019  1.1  SPChin   INC0560405 - Enable Display Error Message  */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA10] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCC             NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cSuggestedLOC    NVARCHAR( 10)  OUTPUT,
   @nPABookingKey    INT            OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount  INT
   DECLARE @cSuggToLOC  NVARCHAR( 10)
          ,@cHostWHCode NVARCHAR( 10) 
          ,@dLottable04 DATETIME
          ,@cYearMonth  NVARCHAR(6) 
          ,@cLottable06 NVARCHAR(30) 
          ,@cPAType     NVARCHAR(1) 
          ,@cToID       NVARCHAR(18) 

          
   DECLARE @tSuggestedLoc TABLE
   (
      SKU NVARCHAR(20)
     ,Qty INT
     ,Loc NVARCHAR(10)
     ,ToID  NVARCHAR(18)
     ,LogicalLocation NVARCHAR(18) 
     ,LotAttribute NVARCHAR(10) -- YearMonth Of Date
     
   )
   
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN                 -- INC0560405
   SAVE TRAN rdt_523ExtPA10   -- INC0560405
   SET @cSuggToLOC = ''
   
--   SELECT @cDefaultFromLoc = UserDefine04
--   FROM dbo.Facility = @cFacility 
   
--   IF @cDefaultFromLoc = @cLoc -- RECEIVING Logic
--   BEGIN
--   
--      SELECT @cHostWHCode = CODE
--      FROM dbo.CODELKUP WITH (NOLOCK) 
--      WHERE LISTNAME ='HOSTWHCODE'
--      AND STORERKEY = @cStorerKey
--      AND UDF01 ='Y'
--
--      SELECT @dLottable04 = LA.Lottable04
--      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
--      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
--      WHERE LLI.StorerKey = @cStorerKey
--      AND LLI.SKU = @cSKU
--      AND LLI.ID  = @cID
--      AND LLI.Loc = @cLoc
--      AND LLI.Lot = @cLot 
--      
--      
--      
--      SET @cYearMonth =  CAST(Year(@dLottable04) AS NVARCHAR(4))  + CAST ( Month(@dLottable04)  AS NVARCHAR(2)) 
--      
--     
--      INSERT INTO @tSuggestedLoc ( SKU, Qty, Loc, LogicalLocation, LotAttribute )
--      SELECT LLI.SKU, SUM(LLI.Qty), LLI.Loc, LOC.LogicalLocation, CAST(Year(LA.Lottable04) AS NVARCHAR(4))  + CAST ( Month(LA.Lottable04)  AS NVARCHAR(2))
--      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
--      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
--      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot
--      WHERE LLI.StorerKey = @cStorerKey
--      AND LLI.SKU = @cSKU
--      AND LLI.ID <> @cID
--      AND Loc.Facility = @cFacility
--      AND Loc.LocationFlag <> 'HOLD' 
--      AND Loc.Loc <> @cLoc
--      AND Loc.HostWHCode = @cHostWHCode
--      GROUP BY LLI.SKU, LLI.Loc, LOC.LogicalLocation, CAST(Year(LA.Lottable04) AS NVARCHAR(4))  + CAST ( Month(LA.Lottable04)  AS NVARCHAR(2))
--      
--      SELECT TOP 1 @cSuggestedLOC = Loc 
--      FROM  @tSuggestedLoc
--      WHERE LotAttribute = @cYearMonth
--      AND SKU = @cSKU 
--      ORDER BY Qty, LogicalLocation 
--      
--   
--   END
--   ELSE IF EXISTS ( SELECT 1 FROM dbo.Codelkup (NOLOCK) 
--                    WHERE ListName = 'EATHWCODE'
--                    AND Short = @cLoc ) -- RETURN Logic
--   BEGIN
      
   SELECT @cLottable06 = LA.Lottable06
   FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
   WHERE LLI.StorerKey = @cStorerKey
   AND LLI.SKU = @cSKU
   AND LLI.ID  = @cID
   AND LLI.Loc = @cLoc
   AND LLI.Lot = @cLot 

   IF @cLottable06 = ''
      SET @cLottable06 = 'P'
   
   SELECT @cPAType = UDF01
         ,@cHostWHCode = Long
   FROM dbo.Codelkup WITH (NOLOCK) 
   WHERE ListName = 'EATHWCODE'
   AND StorerKey = @cStorerKey
   AND Code = @cLottable06
   
   SELECT @dLottable04 = LA.Lottable04
   FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
   WHERE LLI.StorerKey = @cStorerKey
   AND LLI.SKU = @cSKU
   AND LLI.ID  = @cID
   AND LLI.Loc = @cLoc
   AND LLI.Lot = @cLot 
   
   SET @cYearMonth =  CAST(Year(@dLottable04) AS NVARCHAR(4))  + CAST ( Month(@dLottable04)  AS NVARCHAR(2)) 
   
   

   IF @cPAType = '1'
   BEGIN
--      SELECT LLI.SKU, SUM(LLI.Qty), LLI.Loc, LOC.LogicalLocation, LLI.ID, CAST(Year(LA.Lottable04) AS NVARCHAR(4))  + CAST ( Month(LA.Lottable04)  AS NVARCHAR(2))
--      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
--      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
--      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot
--      WHERE LLI.StorerKey = @cStorerKey
--      AND LLI.SKU = @cSKU
--      AND LLI.ID <> @cID
--      AND Loc.Facility = @cFacility
--      AND Loc.LocationFlag <> 'HOLD' 
--      AND Loc.Loc <> @cLoc
--      AND Loc.HostWHCode = @cHostWHCode
--      GROUP BY LLI.SKU, LLI.Loc, LOC.LogicalLocation, LLI.ID, CAST(Year(LA.Lottable04) AS NVARCHAR(4))  + CAST ( Month(LA.Lottable04)  AS NVARCHAR(2))

      INSERT INTO @tSuggestedLoc ( SKU, Qty, Loc, ToID, LogicalLocation, LotAttribute )
      SELECT LLI.SKU, SUM(LLI.Qty), LLI.Loc, LLI.ID, LOC.LogicalLocation, CAST(Year(LA.Lottable04) AS NVARCHAR(4))  + CAST ( Month(LA.Lottable04)  AS NVARCHAR(2))
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot
      WHERE LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LLI.ID <> @cID
      AND Loc.Facility = @cFacility
      AND Loc.LocationFlag <> 'HOLD' 
      AND Loc.Loc <> @cLoc
      AND Loc.HostWHCode = @cHostWHCode
      GROUP BY LLI.SKU, LLI.Loc, LOC.LogicalLocation, LLI.ID, CAST(Year(LA.Lottable04) AS NVARCHAR(4))  + CAST ( Month(LA.Lottable04)  AS NVARCHAR(2))
      
      SELECT TOP 1 @cSuggestedLOC = Loc 
                  , @nQTY         = Qty
                  , @cToID        = ToID 
      FROM  @tSuggestedLoc
      WHERE LotAttribute = @cYearMonth
      AND SKU = @cSKU 
      ORDER BY Qty, LogicalLocation 
   END
   ELSE IF @cPAType = '2'
   BEGIN
      
      SELECT TOP 1 @cSuggestedLOC = LLI.Loc 
                  , @nQTY         = LLI.Qty
                  , @cToID        = LLI.ID 
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot
      WHERE LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LLI.ID <> @cID
      AND Loc.Facility = @cFacility
      AND Loc.LocationFlag <> 'HOLD' 
      AND Loc.Loc <> @cLoc
      AND LA.Lottable06 = @cLottable06
      AND Loc.HostWHCode = @cHostWHCode
      ORDER BY LLI.Qty, Loc.LogicalLocation
      
   END
   ELSE IF @cPAType = '3'
   BEGIN
      INSERT INTO @tSuggestedLoc ( SKU, Qty, Loc, ToID, LogicalLocation, LotAttribute )
      SELECT LLI.SKU, SUM(LLI.Qty), LLI.Loc, LLI.ID, LOC.LogicalLocation, CAST(Year(LA.Lottable04) AS NVARCHAR(4))  + CAST ( Month(LA.Lottable04)  AS NVARCHAR(2))
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot
      WHERE LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LLI.ID <> @cID
      AND Loc.Facility = @cFacility
      AND Loc.LocationFlag <> 'HOLD' 
      AND Loc.Loc <> @cLoc
      AND Loc.HostWHCode = @cHostWHCode
      AND LA.Lottable06 = @cLottable06
      GROUP BY LLI.SKU, LLI.Loc, LOC.LogicalLocation, LLI.ID, CAST(Year(LA.Lottable04) AS NVARCHAR(4))  + CAST ( Month(LA.Lottable04)  AS NVARCHAR(2))
      
      SELECT TOP 1 @cSuggestedLOC = Loc 
                  , @nQTY         = Qty
                  , @cToID        = ToID 
      FROM  @tSuggestedLoc
      WHERE LotAttribute = @cYearMonth
      AND SKU = @cSKU 
      ORDER BY Qty, LogicalLocation 
   END
      
--   END 

   

   IF ISNULL(@cSuggestedLOC,'')  = ''
   BEGIN
            SET @nErrNo = -1
            GOTO Quit
   END
   ELSE
   BEGIN
      
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@cFromLOT      = @cLOT
         ,@cUCCNo        = @cUCC
         ,@cToID         = @cToID
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA10 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO