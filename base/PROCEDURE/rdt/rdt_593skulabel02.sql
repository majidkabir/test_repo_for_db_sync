SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593SKULabel02                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2018-04-04 1.0  Ung      WMS-4456 Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593SKULabel02] (
   @nMobile       INT,          
   @nFunc         INT,          
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT,          
   @nInputKey     INT,          
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @cLabelPrinter NVARCHAR( 10),
   @cPaperPrinter NVARCHAR( 10),
   @cOption       NVARCHAR( 1), 
   @cParam1Label  NVARCHAR( 20) OUTPUT,
   @cParam2Label  NVARCHAR( 20) OUTPUT,
   @cParam3Label  NVARCHAR( 20) OUTPUT,
   @cParam4Label  NVARCHAR( 20) OUTPUT,
   @cParam5Label  NVARCHAR( 20) OUTPUT,
   @cParam1Value  NVARCHAR( 60) OUTPUT,
   @cParam2Value  NVARCHAR( 60) OUTPUT,
   @cParam3Value  NVARCHAR( 60) OUTPUT,
   @cParam4Value  NVARCHAR( 60) OUTPUT,
   @cParam5Value  NVARCHAR( 60) OUTPUT,
   @cFieldAttr02  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr04  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr06  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr08  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr10  NVARCHAR( 1)  OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success      INT
   DECLARE @nTranCount     INT
   DECLARE @cChkFacility   NVARCHAR( 5)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cErrMsg1       NVARCHAR( 20)
   
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cUPC           NVARCHAR( 30)
   DECLARE @nQTY           INT
   DECLARE @nPendingMoveIn INT
   DECLARE @nCaseCount     INT
   DECLARE @cSuggLOC       NVARCHAR( 10)
   DECLARE @cSuggID        NVARCHAR( 18)
   DECLARE @cStyle         NVARCHAR( 20)
   DECLARE @cItemClass     NVARCHAR( 10)
   DECLARE @nCase          INT
   DECLARE @nPiece         INT
   DECLARE @cPAType        NVARCHAR( 10)
   DECLARE @cCaseType      NVARCHAR( 10)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cAssignPickLOC NVARCHAR( 1)

   DECLARE @tLLI TABLE 
   (
      LOT NVARCHAR(10) NOT NULL, 
      QTY INT          NOT NULL
   )
   
   DECLARE @tRF TABLE 
   (
      LOT NVARCHAR(10) NOT NULL, 
      QTY INT          NOT NULL
   )

   DECLARE @tPutawayZone TABLE 
   (
      PutawayZone NVARCHAR(10) NOT NULL
   )

   SET @nTranCount = @@TRANCOUNT

   -- Parameter mapping
   SET @cLOC = @cParam1Value
   SET @cID = @cParam2Value
   SET @cUPC = LEFT( @cParam3Value, 30)

   -- Check blank
   IF @cLOC = ''
   BEGIN
      SET @nErrNo = 122501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
      GOTO Quit
   END

   -- Get LOC info
   SELECT @cChkFacility = Facility FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC

   -- Check LOC valid
   IF @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 122502
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
      SET @cParam1Value = ''
      GOTO Quit
   END

   -- Check diff facility
   IF @cChkFacility <> @cFacility
   BEGIN
      SET @nErrNo = 122503
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
      SET @cParam1Value = ''
      GOTO Quit
   END

   -- Check blank
   IF @cID = ''
   BEGIN
      SET @nErrNo = 122504
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- ID
      GOTO Quit
   END

   -- ID not in LOC
   IF NOT EXISTS( SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOC = @cLOC AND ID = @cID AND StorerKey = @cStorerKey)
   BEGIN
      SET @nErrNo = 122515
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID not in LOC
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- ID
      GOTO Quit
   END

   -- Check blank
   IF @cUPC = ''
   BEGIN
      SET @nErrNo = 122505
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU/UPC
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU
      GOTO Quit
   END

   -- Get SKU barcode count
   DECLARE @nSKUCnt INT
   EXEC rdt.rdt_GETSKUCNT
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cUPC
      ,@nSKUCnt     = @nSKUCnt       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @nErrNo        OUTPUT
      ,@cErrMsg     = @cErrMsg       OUTPUT

   -- Check SKU/UPC
   IF @nSKUCnt = 0
   BEGIN
      SET @nErrNo = 122506
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU
      SET @cParam3Value = ''
      GOTO Quit
   END

   -- Check multi SKU barcode
   IF @nSKUCnt > 1
   BEGIN
      SET @nErrNo = 122507
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarCod
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU
      SET @cParam3Value = ''
      GOTO Quit
   END

   -- Get SKU code
   EXEC rdt.rdt_GETSKU
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cUPC          OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @nErrNo        OUTPUT
      ,@cErrMsg     = @cErrMsg       OUTPUT
   
   IF @nErrNo <> 0 OR @b_Success <> 1
      GOTO Quit

   SET @cSKU = @cUPC

   -- Get SKU info
   SELECT 
      @nCaseCount = Pack.CaseCNT, 
      @cStyle = SKU.Style, 
      @cItemClass = ItemClass
   FROM SKU WITH (NOLOCK)
      JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Check case count
   IF @nCaseCount < 1
   BEGIN
      SET @nErrNo = 122508
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup CaseCNT
      SET @cParam3Value = ''
      GOTO Quit
   END

   -- Get QTY to putaway
   SELECT @nQTY = ISNULL( SUM( QTY), 0)
   FROM LOTxLOCxID LLI WITH (NOLOCK)
   WHERE LLI.LOC = @cLOC
      AND LLI.ID = @cID
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Check QTY to putaway
   IF @nQTY = 0
   BEGIN
      SET @nErrNo = 122509
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No QTY
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU
      SET @cParam3Value = ''
      GOTO Quit
   END

   -- Get total QTY
   SELECT @nQTY = ISNULL( SUM( QTY), 0)
   FROM LOTxLOCxID LLI WITH (NOLOCK)
   WHERE LLI.LOC = @cLOC
      -- AND LLI.ID = @cID
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Get booking info
   SELECT @nPendingMoveIn = ISNULL( SUM( QTY), 0)
   FROM RFPutaway WITH (NOLOCK)
   WHERE FromLOC = @cLOC
      -- AND FromID = @cID
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Check over scan
   IF @nPendingMoveIn >= @nQTY
   BEGIN
      SET @nErrNo = 122510
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over scan
      GOTO Quit
   END

   /*-------------------------------------------------------------------------------

                                       Putaway 

   -------------------------------------------------------------------------------*/
   SET @cSuggLOC = ''
   SET @cSuggID = ''

   IF @cItemClass = 'FTW' -- Footware
   BEGIN
      -- Calc cases and pieces
      SET @nCase = @nQTY / @nCaseCount
      SET @nPiece = @nQTY % @nCaseCount

      -- Determine current QTY is for case or piece
      IF (@nPendingMoveIn + 1) <= @nCase * @nCaseCount
      BEGIN
         SET @cPAType = 'CASE'
         IF (@nPendingMoveIn + 1) % @nCaseCount = 1 -- First piece in a case
            SET @cCaseType = 'NEWCASE'
         ELSE
            SET @cCaseType = 'EXISTCASE'
      END
      ELSE
         SET @cPAType = 'PIECE'
   END
   ELSE
   BEGIN
      SET @nPiece = @nQTY
      SET @cPAType = 'PIECE'
   END

   -- Get zone
   INSERT INTO @tPutawayZone (PutawayZone) 
   SELECT PutawayZone 
   FROM PutawayZone PZ WITH (NOLOCK) 
   WHERE PZ.PutawayZone LIKE 'SKE%'
   
   /*-------------------------------------------------------------------------------
                                    Putaway cases to bulk
   -------------------------------------------------------------------------------*/
   IF @cPAType = 'CASE'
   BEGIN
      IF @cCaseType = 'EXISTCASE'
      BEGIN
         -- Find a "partial" case in bulk to join
         SELECT TOP 1 
            @cSuggID = RF.FromID, 
            @cSuggLOC = RF.SuggestedLOC
         FROM RFPutaway RF WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (RF.SuggestedLOC = LOC.LOC)     
            JOIN @tPutawayZone PZ ON (LOC.PutawayZone = PZ.PutawayZone) 
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationType = 'OTHER'
            AND FromLOC = @cLOC
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
         GROUP BY FromID, SuggestedLOC
         HAVING SUM( QTY) % @nCaseCount <> 0
      END
      ELSE
      BEGIN
         -- Find a friend (same style) with QTY (at least 1 case) to fit
         SELECT TOP 1
            @cSuggID = LLI.ID, 
            @cSuggLOC = LOC.LOC
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN @tPutawayZone PZ ON (LOC.PutawayZone = PZ.PutawayZone) 
            JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationType = 'OTHER'
            AND SKU.StorerKey = @cStorerKey
            AND SKU.Style = @cStyle
         GROUP BY LOC.PALogicalLOC, LOC.LOC, LLI.ID, LOC.[Cube]
         HAVING SUM( LLI.QTY - LLI.QTYPicked + LLI.PendingMoveIn) + @nCaseCount <= LOC.Cube
         ORDER BY LOC.PALogicalLOC, LOC.LOC, LLI.ID
         
         -- Find a empty LOC (at least 1 case) to fit
         IF @cSuggLOC = ''
            SELECT TOP 1
               @cSuggLOC = LOC.LOC
            FROM LOC WITH (NOLOCK)
               JOIN @tPutawayZone PZ ON (LOC.PutawayZone = PZ.PutawayZone)
               LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LOC.LocationType = 'OTHER'
               AND LOC.Cube >= @nCaseCount 
            GROUP BY LOC.PALogicalLOC, LOC.LOC
            HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0 
               AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
            ORDER BY LOC.PALogicalLOC, LOC.LOC
      END
   END
            
   /*-------------------------------------------------------------------------------
                                 Putaway pieces to pick face
   -------------------------------------------------------------------------------*/
   IF @cPAType = 'PIECE'
   BEGIN
      -- Find a friend (same SKU)
      SELECT TOP 1
         @cSuggLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN @tPutawayZone PZ ON (LOC.PutawayZone = PZ.PutawayZone) 
         JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      WHERE LOC.Facility = @cFacility
         AND LOC.LocationType = 'PICK'
         AND SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU
         AND ((LLI.QTY - LLI.QTYPicked) > 0 OR LLI.PendingMoveIn > 0)
      ORDER BY LOC.PALogicalLOC, LOC.LOC
         
      -- Find assign pick loc
      IF @cSuggLOC = ''
         SELECT TOP 1
            @cSuggLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
            JOIN @tPutawayZone PZ ON (LOC.PutawayZone = PZ.PutawayZone)
            JOIN SKUxLOC SL WITH (NOLOCK) ON (SL.StorerKey = @cStorerKey AND SL.SKU = @cSKU AND SL.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationType = 'PICK'
            AND SL.LocationType = 'PICK'

      -- Find an empty LOC
      IF @cSuggLOC = ''
         SELECT TOP 1
            @cSuggLOC = LOC.LOC, 
            @cAssignPickLOC = 'Y'
         FROM LOC WITH (NOLOCK)
            JOIN @tPutawayZone PZ ON (LOC.PutawayZone = PZ.PutawayZone)
            LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationType = 'PICK'
            AND NOT EXISTS( SELECT TOP 1 1 FROM SKUxLOC SL WITH (NOLOCK) WHERE SL.LOC = LOC.LOC AND SL.LocationType IN ('PICK', 'CASE'))
         GROUP BY LOC.PALogicalLOC, LOC.LOC
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0 
            AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
         ORDER BY LOC.PALogicalLOC, LOC.LOC

      -- Get suggest ID
      SELECT TOP 1 
         @cSuggID = RF.FromID 
      FROM RFPutaway RF WITH (NOLOCK) 
         JOIN LOC WITH (NOLOCK) ON (RF.SuggestedLOC = LOC.LOC)
         JOIN @tPutawayZone PZ ON (LOC.PutawayZone = PZ.PutawayZone)
      WHERE RF.FromLOC = @cLOC
         AND LOC.LocationType = 'PICK'
         AND RF.StorerKey = @cStorerKey
   END

   -- No suggested LOC
   IF @cSuggLOC = ''
   BEGIN      
      SET @cSuggLOC = 'NO LOC'

      SET @cErrMsg1 = rdt.rdtgetmessage( 122516, @cLangCode ,'DSP') --NO LOC
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1 
      
      GOTO Quit     
   END

   /*-------------------------------------------------------------------------------
                                       Get ID and LOT
   -------------------------------------------------------------------------------*/
   -- Get new ID
   IF @cSuggID = ''
   BEGIN
      EXECUTE dbo.nspg_GetKey  
         'ID',  
         10,  
         @cSuggID   OUTPUT,  
         @b_Success OUTPUT,  
         @nErrNo    OUTPUT,  
         @cErrMsg   OUTPUT
         
      IF @nErrNo <> 0 OR @b_Success <> 1
      BEGIN
         SET @nErrNo = 122511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey fail
         GOTO Quit
      END
   END

   -- Get LOT (LOTxLOCxID)
   INSERT INTO @tLLI (LOT, QTY)
   SELECT LOT, SUM( QTY)
   FROM LOTxLOCxID WITH (NOLOCK)
   WHERE LOC = @cLOC
      AND ID = @cID
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
      AND QTY > 0
   GROUP BY LOT

   -- Get LOT (RFPutaway)
   INSERT INTO @tRF (LOT, QTY)
   SELECT LOT, SUM( QTY)
   FROM RFPutaway WITH (NOLOCK)
   WHERE FromLOC = @cLOC
      AND FromID = @cID
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
   GROUP BY LOT
   
   -- Get current piece's LOT
   SET @cLOT = ''
   SELECT @cLOT = LLI.LOT
   FROM @tLLI LLI
      LEFT JOIN @tRF RF ON (LLI.LOT = RF.LOT)
   WHERE RF.LOT IS NULL OR
      LLI.QTY > RF.QTY
   ORDER BY LLI.LOT    

   -- Check LOT
   IF @cLOT = ''
   BEGIN
      SET @nErrNo = 122512
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --LOT not found
      GOTO Quit
   END
   
/*
insert into a (field, value) values ('@cSuggLOC', @cSuggLOC)
insert into a (field, value) values ('@cSuggID', @cSuggID)
insert into a (field, value) values ('@cLOT', @cLOT)
goto quit
*/

   /*-------------------------------------------------------------------------------
                                 Move and book process
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_593SKULabel02 -- For rollback or commit only our own transaction   

   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,
      @cLangCode   = @cLangCode, 
      @nErrNo      = @nErrNo  OUTPUT,
      @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
      @cSourceType = 'rdt_593SKULabel02', 
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility, 
      @cFromLOC    = @cLOC, 
      @cToLOC      = @cLOC, 
      @cFromID     = @cID, 
      @cToID       = @cSuggID,
      @cSKU        = @cSKU, 
      @nQTY        = 1, 
      @cFromLOT    = @cLOT, 
      @nFunc       = @nFunc
   IF @nErrNo <> 0
      GOTO RollBackTran

   SET @cUserName = LEFT( SUSER_SNAME(), 18)
   EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
      ,@cLOC
      ,@cSuggID
      ,@cSuggLOC
      ,@cStorerKey
      ,@nErrNo  OUTPUT
      ,@cErrMsg OUTPUT
      ,@cSKU          = @cSKU
      ,@nPutawayQTY   = 1
      ,@cFromLOT      = @cLOT
   IF @nErrNo <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      GOTO RollBackTran
   END

   -- Auto assign pick face
   IF @cAssignPickLOC = 'Y'
   BEGIN
      INSERT INTO SKUxLOC (StorerKey, SKU, LOC, LocationType)
      VALUES (@cStorerKey, @cSKU, @cSuggLOC, 'PICK')
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   END

   COMMIT TRAN rdt_593SKULabel02
   
   /*-------------------------------------------------------------------------------

                                    Print SKU Label

   -------------------------------------------------------------------------------*/
   DECLARE @cSKULabel NVARCHAR( 10)
   SET @cSKULabel = rdt.RDTGetConfig( @nFunc, 'SKULabel', @cStorerKey)
   IF @cSKULabel = '0'
      SET @cSKULabel = ''

   -- Common params
   DECLARE @tSKULabel AS VariableTable
   INSERT INTO @tSKULabel (Variable, Value) VALUES 
      ( '@cLOC',  @cLOC), 
      ( '@cSKU',  @cSKU), 
      ( '@cSuggID',   @cSuggID), 
      ( '@cSuggLOC', @cSuggLOC)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
      @cSKULabel, -- Report type
      @tSKULabel, -- Report params
      'rdt_593SKULabel02', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

   /*-------------------------------------------------------------------------------
                                       Update counter
   -------------------------------------------------------------------------------*/
   -- Get inventory info
   SELECT @nQTY = ISNULL( SUM( QTY), 0)
   FROM LOTxLOCxID LLI WITH (NOLOCK)
   WHERE LLI.LOC = @cLOC
      -- AND LLI.ID = @cID
      AND StorerKey = @cStorerKey

   -- Get booking info
   SELECT @nPendingMoveIn = ISNULL( SUM( QTY), 0)
   FROM RFPutaway WITH (NOLOCK)
   WHERE FromLOC = @cLOC
      AND FromID <> @cID
      AND StorerKey = @cStorerKey

   -- Output suggest LOC
   DECLARE @cMsg NVARCHAR( 20)
   SET @cMsg = rdt.rdtgetmessage( 122513, @cLangCode, 'DSP') --LOC:
   SET @cParam4Value = RTRIM( @cMsg) + ' ' + @cSuggLOC
   
   -- Output counters
   SET @cMsg = rdt.rdtgetmessage( 122514, @cLangCode, 'DSP') --SCAN/TOTAL:
   SET @cParam5Label = RTRIM( @cMsg) + ' ' + CAST( @nPendingMoveIn AS NVARCHAR( 5)) + '/' + CAST( @nQTY AS NVARCHAR( 5))

   EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_593SKULabel02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO