SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
        
/******************************************************************************************/
/* Store procedure: rdt_1819ExtPASP52_1                                                     */
/*                                                                                        */
/* Modifications log:                                                                     */
/*                                                                                        */
/* Date         Rev  Author   Purposes                                                    */
/* 2024-06-03   1.0  NLT013   FCR-267. Created. Putaway a pallet with                     */
/*                            multiple UCC, need book the final locations for each UCC    */
/*                            and the PND location                                        */
/******************************************************************************************/
        
CREATE    PROC [RDT].[rdt_1819ExtPASP52_1] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10) = ''  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
           
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cPutawayZone   NVARCHAR(10)
   DECLARE @nUCCCartonQty  INT
   DECLARE @nTranCount     INT
   DECLARE @nRowCount      INT
   DECLARE @nLoopIndex     INT
   DECLARE @nLoopIndex1    INT
   DECLARE @cLoopAisle     NVARCHAR(10)
   DECLARE @cLoopLoc       NVARCHAR(10)
   DECLARE @cLoopPNDLoc    NVARCHAR(10)
   DECLARE @nLoopAvailableSpace    INT
   DECLARE @nLoopLocQty    INT
   DECLARE @nSuggestLocQty    INT
   DECLARE @cSuggestAisle   NVARCHAR(10)
   DECLARE @cLoopUCCNo      NVARCHAR(18)
   DECLARE @cLoopUCCQty     NVARCHAR(18)
   DECLARE @nSuitAisleLocQty INT
   DECLARE @nSuitAislePltQty INT
   DECLARE @bDebug           BIT
   DECLARE @cDebugMsg        NVARCHAR(500)
   DECLARE @cSQL			NVARCHAR(MAX)
   DECLARE @tPNDAisle TABLE
   (
      id INT IDENTITY(1,1),
      Aisle          NVARCHAR(10),
      PNDLoc         NVARCHAR(10)
   )
   DECLARE @tLocData       TABLE
   (
      id INT IDENTITY(1,1),
      Aisle          NVARCHAR(10),
      Loc            NVARCHAR(10),
      AvailableSpace         INT
   )
   DECLARE @tUCCData TABLE
   (
      id INT IDENTITY(1,1),
      UCCNo          NVARCHAR(20),
      Qty            INT
   )

    DECLARE @tLocData1 TABLE
   (
      t1_aisle NVARCHAR(30),
      t1_id INT,
      t1_AvailableSpace INT,
      t2_aisle NVARCHAR(30),
      t2_id INT,
      t2_AvailableSpace INT
   )
   DECLARE @tLocData2 TABLE
   (
      aisle NVARCHAR(30),
      id INT,
      aisle_AvailableSpace_sum INT
   )
   DECLARE @tLocData3 TABLE
   (
      aisle NVARCHAR(30),
      id INT,
      aisle_AvailableSpace_sum INT,
      rank INT
   )

   DECLARE @NICKMSG NVARCHAR(400)

   SET @bDebug = 0
   IF @cUserName = 'TEST1'
      SET @bDebug = 1

   SET @nTranCount = @@TRANCOUNT

   SELECT @nRowCount = COUNT(DISTINCT sku.PutawayZone)
   FROM SKU sku WITH(NOLOCK)
   INNER JOIN LOTXLOCXID sto WITH(NOLOCK) ON sku.Sku = sto.Sku AND sku.StorerKey = sto.StorerKey
   WHERE sto.StorerKey = @cStorerKey
      AND sto.Id = @cID

   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 216551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

      IF @bDebug = 1
      BEGIN
         SET @cDebugMsg = 'Error: ' + ' Multiple Putaway Zone';
         PRINT @cDebugMsg
      END
      GOTO Fail
   END

   SELECT TOP 1
      @cPutawayZone = sku.PutawayZone,
      @cSKU = sku.Sku
   FROM SKU sku WITH(NOLOCK)
   INNER JOIN LOTXLOCXID sto WITH(NOLOCK) ON sku.Sku = sto.Sku AND sku.StorerKey = sto.StorerKey
   WHERE sto.StorerKey = @cStorerKey
      AND sto.Id = @cID

   SELECT @nRowCount = @@ROWCOUNT

   SET @NICKMSG = CONCAT_WS(',' , 'N-1', CONVERT(NVARCHAR(30), GETDATE(), 121) )
   PRINT @NICKMSG

   IF @nRowCount = 0 OR ISNULL(@cPutawayZone, '') = ''
   BEGIN
      SET @nErrNo = 216552
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPutawayZone

      IF @bDebug = 1
      BEGIN
         SET @cDebugMsg = 'Error: ' + ' No Putaway Zone';
         PRINT @cDebugMsg
      END
      GOTO Fail
   END

   IF @bDebug = 1
   BEGIN
      SET @cDebugMsg = 'Info: ' + 'Get Putaway Zone: ' + @cPutawayZone
      PRINT @cDebugMsg
   END 

   SELECT @nUCCCartonQty = COUNT(1)
   FROM
      (SELECT UCC.UCCNo, ROW_NUMBER()OVER(PARTITION BY UCC.UCCNo ORDER BY UCC.UCCNo) AS row#
      FROM LOTxLOCxID LLI WITH(NOLOCK)
      INNER JOIN dbo.UCC WITH (NOLOCK) ON LLI.StorerKey = UCC.StorerKey AND LLI.LOT = UCC.LOT AND LLI.LOC = UCC.LOC AND LLI.ID = UCC.ID
      WHERE LLI.StorerKey = @cStorerKey
         AND LLI.Id = @cID
         AND LLI.Loc = @cFromLOC
         AND LLI.QTY - LLI.QTYPicked > 0 
         AND LLI.PendingMoveIn = 0) AS t
   WHERE t.row# = 1

   SELECT @nRowCount = @@ROWCOUNT

    SET @NICKMSG = CONCAT_WS(',' , 'N-2', CONVERT(NVARCHAR(30), GETDATE(), 121) )
   PRINT @NICKMSG

   IF @nRowCount = 0 OR ISNULL(@nUCCCartonQty , 0) = 0
   BEGIN
      SET @nErrNo = 216553
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoUCC

      IF @bDebug = 1
      BEGIN
         SET @cDebugMsg = 'Error: ' + ' No UCC';
         PRINT @cDebugMsg
      END
      GOTO Fail
   END

   IF @cSKU IS NOT NULL AND TRIM(@cSKU) <> '' AND @cPutawayZone IS NOT NULL AND TRIM(@cPutawayZone) <> '' AND @nUCCCartonQty > 0
   BEGIN
	 SET @NICKMSG = CONCAT_WS(',' , 'N-3', CONVERT(NVARCHAR(30), GETDATE(), 121) )
   PRINT @NICKMSG

      INSERT INTO @tPNDAisle (Aisle, PNDLoc)
      SELECT loc.LocAisle, loc.Loc
      FROM dbo.LOC loc WITH(NOLOCK) 
      LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (loc.LOC = LLI.LOC AND (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0) AND LLI.StorerKey = @cStorerKey)
      WHERE loc.PutawayZone = @cPutawayZone
         AND loc.Facility = @cFacility
         AND loc.LocationType IN ( 'PND', 'PNDIN', 'PNDOUT' )
         AND ISNULL(loc.Status, '') = 'OK'
         AND ISNULL(loc.LocAisle, '') <> ''
      GROUP BY loc.LocAisle, loc.Loc, IIF(loc.MaxPallet = 0, 9999, MaxPallet)
      HAVING IIF(loc.MaxPallet = 0, 9999, loc.MaxPallet) - COUNT(DISTINCT LLI.ID) > 0

      SELECT @nRowCount = @@ROWCOUNT

	   SET @NICKMSG = CONCAT_WS(',' , 'N-4', CONVERT(NVARCHAR(30), GETDATE(), 121) )
   PRINT @NICKMSG

      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 216559
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoAisleFound

         IF @bDebug = 1
         BEGIN
            SET @cDebugMsg = 'Error: ' + ' No Asile was found';
            PRINT @cDebugMsg
         END
         GOTO Fail
      END

      INSERT INTO @tLocData (Aisle, Loc, AvailableSpace)
      SELECT loc.LocAisle, loc.Loc, 
         IIF(loc.MaxCarton = 0, 9999, loc.MaxCarton) - COUNT(DISTINCT UCCSTO.UCCNo) - COUNT(rp.RowRef)
      FROM dbo.LOC loc WITH(NOLOCK) 
      LEFT JOIN ( SELECT LLI.Loc, UCC.UCCNo 
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                  INNER JOIN dbo.UCC WITH (NOLOCK) ON LLI.StorerKey = UCC.StorerKey AND LLI.LOT = UCC.LOT AND LLI.LOC = UCC.LOC 
                  WHERE LLI.StorerKey = @cStorerKey
                     AND LLI.QTY - LLI.QTYPicked > 0 ) AS UCCSTO
         ON loc.Loc = UCCSTO.Loc
      LEFT JOIN dbo.RFPUTAWAY rp WITH(NOLOCK)
         ON loc.Loc = rp.SuggestedLoc
         AND rp.StorerKey = @cStorerKey
      WHERE loc.PutawayZone = @cPutawayZone
         AND loc.Facility = @cFacility
         AND loc.LocationType = 'CASE'
         AND ISNULL(loc.Status, '') = 'OK'
         AND ISNULL(loc.LocAisle, '') <> ''
         AND EXISTS (SELECT 1 FROM @tPNDAisle AS al WHERE loc.LocAisle = al.Aisle)
      GROUP BY loc.LocAisle, loc.Loc, IIF(loc.MaxCarton = 0, 9999, MaxCarton)
      HAVING IIF(loc.MaxCarton = 0, 9999, loc.MaxCarton) - COUNT(DISTINCT UCCSTO.UCCNo) - COUNT(rp.RowRef) > 0
      ORDER BY loc.LocAisle, IIF(loc.MaxCarton = 0, 9999, MaxCarton) - COUNT(DISTINCT UCCSTO.UCCNo) - COUNT(rp.RowRef) DESC, loc.Loc

      SELECT @nRowCount = @@ROWCOUNT
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 216560
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLocFound

         IF @bDebug = 1
         BEGIN
            SET @cDebugMsg = 'Error: ' + ' No storage loc was found';
            PRINT @cDebugMsg
         END
         GOTO Fail
      END

	   SET @NICKMSG = CONCAT_WS(',' , 'N-5', CONVERT(NVARCHAR(30), GETDATE(), 121) )
   PRINT @NICKMSG



      INSERT INTO @tLocData1 (t1_aisle, t1_id, t1_AvailableSpace, t2_aisle, t2_id, t2_AvailableSpace )
      SELECT t1.aisle AS t1_aisle, t1.id AS t1_id, t1.AvailableSpace AS t1_AvailableSpace, t2.aisle AS t2_aisle, t2.id AS t2_id, t2.AvailableSpace AS t2_AvailableSpace
      FROM @tLocData t1
      INNER JOIN @tLocData t2 ON t1.Aisle = t2.Aisle AND t1.id >= t2.id
	  WHERE t1.id <= @nUCCCartonQty

	  select * from  @tLocData1

	  SET @NICKMSG = CONCAT_WS(',' , 'N-5-1', CONVERT(NVARCHAR(30), GETDATE(), 121) )
   PRINT @NICKMSG

      INSERT INTO @tLocData2 (aisle, id, aisle_AvailableSpace_sum)
      SELECT t1_aisle, t1_id, aisle_AvailableSpace_sum
         FROM 
            (SELECT t1_aisle, t1_id, 
                  SUM(t2_AvailableSpace)OVER(PARTITION BY t1_aisle, t1_id ORDER BY t1_aisle, t1_id ) AS aisle_AvailableSpace_sum,
                  ROW_NUMBER()OVER(PARTITION BY t1_aisle, t1_id ORDER BY t1_aisle, t1_id) AS row#
            FROM @tLocData1) AS t1
         WHERE t1.row# = 1

		 SET @NICKMSG = CONCAT_WS(',' , 'N-6', CONVERT(NVARCHAR(30), GETDATE(), 121) )
   PRINT @NICKMSG
   select * from  @tLocData2

      INSERT INTO @tLocData3 (aisle, id, aisle_AvailableSpace_sum, rank)
      (
         SELECT aisle, id, aisle_AvailableSpace_sum,
            ROW_NUMBER()OVER(PARTITION BY aisle ORDER BY aisle, id) AS rank
         FROM @tLocData2
      )

	   SET @NICKMSG = CONCAT_WS(',' , 'N-7', CONVERT(NVARCHAR(30), GETDATE(), 121) )
   PRINT @NICKMSG

      SELECT TOP 1 @cSuggestAisle = aisle, @nSuitAisleLocQty = rank, @nSuitAislePltQty = min_Sum
      FROM
         (SELECT aisle, id, rank, MIN( aisle_AvailableSpace_sum ) OVER(PARTITION BY aisle ORDER BY aisle) AS min_Sum,
            ROW_NUMBER()OVER(PARTITION BY aisle ORDER BY aisle, id) AS row#
         FROM 
            @tLocData3 AS t2
         WHERE t2.aisle_AvailableSpace_sum >= @nUCCCartonQty) AS t2
      WHERE t2.row# = 1
      ORDER BY rank, aisle

      SELECT @nRowCount = @@ROWCOUNT
      IF @nRowCount = 0 OR ISNULL(@cSuggestAisle, '') = ''
      BEGIN
         SET @nErrNo = 216554
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoAisleFound

         IF @bDebug = 1
         BEGIN
            SET @cDebugMsg = 'Error: ' + ' No Aisle was Found';
            PRINT @cDebugMsg
         END
         GOTO Fail
      END

      IF @bDebug = 1
      BEGIN
         SET @cDebugMsg = 'Info: ' + ' Find Aisle ' + @cSuggestAisle;
         PRINT @cDebugMsg
      END

	   SET @NICKMSG = CONCAT_WS(',' , 'N-8', CONVERT(NVARCHAR(30), GETDATE(), 121) )
   PRINT @NICKMSG

      SELECT TOP 1 @cPickAndDropLOC = PNDLoc FROM @tPNDAisle WHERE Aisle = @cSuggestAisle ORDER BY PNDLoc

      SELECT @nRowCount = @@ROWCOUNT
      IF @nRowCount = 0 OR ISNULL(@cPickAndDropLOC, '') = ''
      BEGIN
         SET @nErrNo = 216557
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPNDFound

         IF @bDebug = 1
         BEGIN
            SET @cDebugMsg = 'Error: ' + ' No PND was Found';
            PRINT @cDebugMsg
         END
         GOTO Fail
      END

      IF @bDebug = 1
      BEGIN
         SET @cDebugMsg = 'Info: ' + ' Find PND LOC ' + @cPickAndDropLOC;
         PRINT @cDebugMsg
      END

      INSERT INTO @tUCCData( UCCNo, Qty )
      SELECT UCCNo, qty FROM dbo.UCC WITH(NOLOCK) WHERE Id = @cID AND StorerKey = @cStorerKey

      SELECT @nRowCount = @@ROWCOUNT
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 216555
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoUCC

         IF @bDebug = 1
         BEGIN
            SET @cDebugMsg = 'Error: ' + ' No UCC was Found';
            PRINT @cDebugMsg
         END
         GOTO Fail
      END
   END

    SET @NICKMSG = CONCAT_WS(',' , 'N-9', CONVERT(NVARCHAR(30), GETDATE(), 121) )
   PRINT @NICKMSG

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1819ExtPASP52_1 -- For rollback or commit only our own transaction

   IF ISNULL( @cSuggestAisle, '') <> '' AND ISNULL(@cPickAndDropLOC , '') <> ''
   BEGIN
      SET @nPABookingKey = ''
      --Lock PND location
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLOC
         ,@cID
         ,@cPickAndDropLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
      BEGIN
         IF @bDebug = 1
         BEGIN
            SET @cDebugMsg = 'Error: ' + ' Book PND Loc fail. Details: ' + CAST(ISNULL(@nErrNo, 0) AS NVARCHAR(10) ) + '-' + ISNULL(@cErrMsg, '');
            PRINT @cDebugMsg
         END

         SET @nErrNo = 216556
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BookPNDFail
         GOTO RollBackTran
      END

      IF @bDebug = 1
      BEGIN
         SET @cDebugMsg = 'Info: ' + ' Book PND Loc success. PND: ' + ISNULL(@cPickAndDropLOC, '');
         PRINT @cDebugMsg
      END

      --Lock final location for each UCC
      SET @nLoopIndex = -1
      SET @nLoopAvailableSpace = 0
      WHILE 1 = 1
      BEGIN
         SELECT TOP 1
            @nLoopIndex = id,
            @cLoopLoc = Loc,
            @nLoopAvailableSpace = AvailableSpace
         FROM @tLocData
         WHERE Aisle = @cSuggestAisle
            AND id > @nLoopIndex
         ORDER BY id

         SELECT @nRowCount = @@ROWCOUNT
         IF @nRowCount = 0
            BREAK

         IF @bDebug = 1
         BEGIN
            SET @cDebugMsg = 'Info: ' + ' Loop Aisle: ' + @cSuggestAisle + ', Loc: ' + @cLoopLoc + ', Available Space: ' + CAST(@nLoopAvailableSpace AS NVARCHAR(5))
            PRINT @cDebugMsg
         END

         WHILE @nLoopAvailableSpace > 0
         BEGIN
            SELECT TOP 1 
               @cLoopUCCNo = UCCNo,
               @cLoopUCCQty = Qty
            FROM @tUCCData
            ORDER BY id

            SELECT @nRowCount = @@ROWCOUNT
            IF @nRowCount = 0
               GOTO Commit_Tran

            IF @bDebug = 1
            BEGIN
               SET @cDebugMsg = 'Info: ' + ' Loop UCC, book loc for UCC ' + @cLoopUCCNo + ' with qty ' + CAST(@cLoopUCCQty AS NVARCHAR(5))
               PRINT @cDebugMsg
            END

            SET @nPABookingKey = ''
            --Lock final location
            EXEC rdt.rdt_Putaway_PendingMoveIn 
               @cUserName = @cUserName
               ,@cType = 'LOCK'
               ,@cFromLOC = @cFromLOC
               ,@cFromID = @cID
               ,@cSuggestedLOC = @cLoopLoc
               ,@cStorerKey = @cStorerKey
               ,@nErrNo = @nErrNo  OUTPUT
               ,@cErrMsg = @cErrMsg OUTPUT
               ,@nPABookingKey = @nPABookingKey OUTPUT
               ,@cToID = ''
               ,@cUCCNo = @cLoopUCCNo
               ,@nPutawayQty = @cLoopUCCQty

            IF @nErrNo <> 0
            BEGIN
               IF @bDebug = 1
               BEGIN
                  SET @cDebugMsg = 'Error: ' + ' Loop UCC, fail to book loc for ' + @cLoopUCCNo + '. Details: ' + CAST(ISNULL(@nErrNo, 0) AS NVARCHAR(10) ) + '-' + ISNULL(@cErrMsg, '');
                  PRINT @cDebugMsg
               END

               SET @nErrNo = 216558
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BookUCCFail
               GOTO RollBackTran
            END

            UPDATE dbo.RFPUTAWAY SET FromLoc = @cPickAndDropLOC WHERE Id = @cID AND ISNULL(CASEID, '') = @cLoopUCCNo

            DELETE FROM @tUCCData WHERE UCCNo = @cLoopUCCNo

            SET @nLoopAvailableSpace = @nLoopAvailableSpace - 1
         END
      END

   Commit_Tran:
      COMMIT TRAN rdt_1819ExtPASP52_1
      GOTO Quit
   END

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP52_1 -- Only rollback change made here
Fail:
   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END 


GO