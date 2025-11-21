SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593SKULabel05                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2019-01-03 1.0  James    WMS-7409 Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593SKULabel05] (
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
   DECLARE @cSPAZone       NVARCHAR( 10)
   DECLARE @cShort         NVARCHAR( 10)

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

      -- Get report info
   SELECT @cShort = RTRIM( ISNULL( Short, ''))
   FROM dbo.CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'RDTLBLRPT' 
   AND   Code = @cOption
   AND   StorerKey = @cStorerKey

   SET @nTranCount = @@TRANCOUNT

   -- Parameter mapping
   SET @cSPAZone = @cParam1Value
   SET @cLOC = @cParam2Value
   SET @cUPC = LEFT( @cParam3Value, 30)

   -- Check blank
   IF @cSPAZone = ''
   BEGIN
      SET @nErrNo = 133451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PAZone
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Zone
      GOTO Quit
   END

   -- Check blank
   IF @cLOC = ''
   BEGIN
      SET @nErrNo = 133452
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
      GOTO Quit
   END

   -- Get LOC info
   SELECT @cChkFacility = Facility FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC

   -- Check LOC valid
   IF @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 133453
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
      SET @cParam2Value = ''
      GOTO Quit
   END

   -- Check diff facility
   IF @cChkFacility <> @cFacility
   BEGIN
      SET @nErrNo = 133454
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
      SET @cParam2Value = ''
      GOTO Quit
   END

   -- Check blank
   IF @cUPC = ''
   BEGIN
      SET @nErrNo = 133455
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU/UPC
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU
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
      SET @nErrNo = 133456
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU
      SET @cParam3Value = ''
      GOTO Quit
   END

   -- Check multi SKU barcode
   IF @nSKUCnt > 1
   BEGIN
      SET @nErrNo = 133457
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarCod
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU
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
   
   SET @cSKU = @cUPC
   /*
   -- Only sku.itemclass <> FTW can proceed
   IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   SKU = @cSKU
               AND   Itemclass = 'FTW')
   BEGIN
      SET @nErrNo = 133458
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Is FTW
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU
      SET @cParam3Value = ''
      GOTO Quit
   END
   */
   -- Get QTY to putaway
   SELECT @nQTY = ISNULL( SUM( QTY), 0)
   FROM LOTxLOCxID LLI WITH (NOLOCK)
   WHERE LLI.LOC = @cLOC
   AND   StorerKey = @cStorerKey
   AND   SKU = @cSKU

   -- Check QTY to putaway
   IF @nQTY = 0
   BEGIN
      SET @nErrNo = 133459
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
      SET @nErrNo = 133460
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over scan
      GOTO Quit
   END

   -- Get LOT (LOTxLOCxID)
   INSERT INTO @tLLI (LOT, QTY)
   SELECT LOT, SUM( QTY)
   FROM LOTxLOCxID WITH (NOLOCK)
   WHERE LOC = @cLOC
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
      AND QTY > 0
   GROUP BY LOT

   -- Get LOT (RFPutaway)
   INSERT INTO @tRF (LOT, QTY)
   SELECT LOT, SUM( QTY)
   FROM RFPutaway WITH (NOLOCK)
   WHERE FromLOC = @cLOC
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

   SELECT TOP 1 @cID = ID 
   FROM dbo.LOTxLOCxID WITH (NOLOCK)
   WHERE LOT = @cLOT
   AND   LOC = @cLOC
   AND   StorerKey = @cStorerKey
   ORDER BY 1

   -- Get zone
   INSERT INTO @tPutawayZone (PutawayZone) 
   SELECT PutawayZone 
   FROM PutawayZone PZ WITH (NOLOCK) 
   WHERE PZ.PutawayZone LIKE 'SKE%'

   SET @cSuggLOC = ''

   -- Strategy
   -- 1. find friend in special pazone
   -- 2. find friend in non special pazone
   -- 3. find empty loc in special pazone

   -- Find LOC in special zone (qty or atyallocated or qtypicked or pendingmovein or qtyreplen <> '0') 
   SELECT TOP 1 @cSuggLOC = LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cSKU   -- Friend
   AND   LOC.Facility = @cFacility   
   AND   LOC.PutawayZone = @cSPAZone
   AND   LOC.LocationCategory = 'OTHER'
   AND   LOC.Locationflag <> 'HOLD'
   AND   LOC.Locationflag <> 'DAMAGE'
   AND   LOC.Status <> 'HOLD'
   GROUP BY LOC.LOC
   HAVING ISNULL( SUM( LLI.QTY + LLI.QTYPicked + LLI.QTYAllocated + LLI.PendingMoveIn + 
         (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) > 0
   ORDER BY LOC.LOC

   -- Find LOC not in special zone (qty or atyallocated or qtypicked or pendingmovein or qtyreplen <> '0') 
   IF ISNULL( @cSuggLOC, '') = ''
      SELECT TOP 1 @cSuggLOC = LOC.LOC
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      JOIN @tPutawayZone PAZONE ON ( LOC.Putawayzone = PAZone.PutawayZone)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU   -- Friend
      AND   LOC.Facility = @cFacility   
      AND   LOC.PutawayZone <> @cSPAZone
      AND   LOC.LocationCategory = 'OTHER'
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      GROUP BY LOC.LOC
      HAVING ISNULL( SUM( LLI.QTY + LLI.QTYPicked + LLI.QTYAllocated + LLI.PendingMoveIn + 
            (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) > 0
      ORDER BY LOC.LOC

   -- Find empty LOC in special zone 
   IF ISNULL( @cSuggLOC, '') = ''
      SELECT TOP 1 @cSuggLOC = LOC.LOC
      FROM dbo.LOC LOC WITH (NOLOCK) 
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility   
      AND   LOC.PutawayZone = @cSPAZone
      AND   LOC.LocationCategory = 'OTHER'
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      GROUP BY LOC.LOC
      -- Empty LOC
      HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn - 
            (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0
      ORDER BY LOC.LOC

   IF ISNULL( @cSuggLOC, '') = ''
   BEGIN
      SET @nErrNo = 133461
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No suggest Loc
      SET @cParam1Value = ''
      GOTO Quit
   END

   SET @cUserName = LEFT( SUSER_SNAME(), 18)
   EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
      ,@cLOC
      ,@cID
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

   DECLARE @cSKULabel NVARCHAR( 10)
   SET @cSKULabel = rdt.RDTGetConfig( @nFunc, 'NFTWSKULbl', @cStorerKey)
   IF @cSKULabel = '0'
      SET @cSKULabel = ''
         
   -- Common params
   DECLARE @tSKULabel AS VariableTable
   INSERT INTO @tSKULabel (Variable, Value) VALUES 
      ( '@cSKU',  @cSKU), 
      ( '@cSuggLOC', @cSuggLOC),
      ( '@cFromLOC', @cLOC)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
      @cSKULabel, -- Report type
      @tSKULabel, -- Report params
      'rdt_593SKULabel05', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit
   ELSE
   BEGIN
      DECLARE @cErrMsg01 NVARCHAR( 20), @cErrMsg02 NVARCHAR( 20)

      SET @cErrMsg01 = rdt.rdtgetmessage( 133462, @cLangCode, 'DSP') --Suggest Loc:
      SET @cErrMsg02 = @cSuggLOC

      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01, @cErrMsg02

      IF @nErrNo = 1 -- Success
         SET @nErrNo = 0

       -- Remain in current screen
      IF CHARINDEX('R', @cShort ) <> 0 OR @cShort <> ''
      BEGIN
         -- Set focus field
         IF CHARINDEX('1', @cShort ) = 0 
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 2 --Zone
            GOTO Quit
         END

         IF CHARINDEX('2', @cShort ) = 0 
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 4 --Loc
            GOTO Quit
         END

         IF CHARINDEX('3', @cShort ) = 0 
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU
            GOTO Quit
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_593SKULabel05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO