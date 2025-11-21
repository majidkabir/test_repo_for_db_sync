SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_ConReceive_Putaway                                 */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Putaway for receiving                                             */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 15-Apr-2015  Ung       1.0   SOS335126 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_ConReceive_Putaway]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT,           
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15), 
   @cType         NVARCHAR( 10), --SUGGEST/EXECUTE/CANCEL
   @cRefNo        NVARCHAR( 20), 
   @cColumnName   NVARCHAR( 20), 
   @cLOC          NVARCHAR( 10), 
   @cID           NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cReceiptKey   NVARCHAR( 10), 
   @cRDLineNo     NVARCHAR( 5), 
   @cFinalLOC     NVARCHAR( 10), 
   @cSuggToLOC    NVARCHAR( 10)  OUTPUT,
   @nPABookingKey INT            OUTPUT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess         INT
   DECLARE @nTranCount       INT
   DECLARE @cPickAndDropLOC  NVARCHAR(10)
   DECLARE @cFitCasesInAisle NVARCHAR(1)
   DECLARE @cSQL             NVARCHAR( MAX)
   DECLARE @cSQLParam        NVARCHAR( MAX)
   DECLARE @cLOT             NVARCHAR(10)
   DECLARE @cUserName        NVARCHAR(18)

   DECLARE @cFinalizeFlag    NVARCHAR( 1)
   DECLARE @cLottable01      NVARCHAR( 18)
   DECLARE @cLottable02      NVARCHAR( 18)
   DECLARE @cLottable03      NVARCHAR( 18)
   DECLARE @dLottable04      DATETIME
   DECLARE @dLottable05      DATETIME
   DECLARE @cLottable06      NVARCHAR( 30)
   DECLARE @cLottable07      NVARCHAR( 30)
   DECLARE @cLottable08      NVARCHAR( 30)
   DECLARE @cLottable09      NVARCHAR( 30)
   DECLARE @cLottable10      NVARCHAR( 30)
   DECLARE @cLottable11      NVARCHAR( 30)
   DECLARE @cLottable12      NVARCHAR( 30)
   DECLARE @dLottable13      DATETIME
   DECLARE @dLottable14      DATETIME
   DECLARE @dLottable15      DATETIME

   SET @nTranCount = @@TRANCOUNT
   SET @cUserName = SUSER_SNAME()

   -- Checking
   IF @cType = 'SUGGEST' OR @cType = 'EXECUTE'
   BEGIN
      -- Check ASN finalize
      IF NOT EXISTS( SELECT 1
         FROM ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey 
            AND ReceiptLineNumber = @cRDLineNo 
            AND FinalizeFlag = 'Y')
      IF @cFinalizeFlag <> 'Y'
      BEGIN
         SET @nErrNo = 55951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ASNNotFinalize
         GOTO Quit
      END
      
      -- Get LOT
      SET @cLOT = ''
      SELECT @cLOT = LOT FROM ITrn WITH (NOLOCK) WHERE TranType = 'DP' AND SourceKey = @cReceiptKey + @cRDLineNo
      
      -- Check LOT
      IF @cLOT = ''
      BEGIN
         SET @nErrNo = 55952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Blank LOT 
         GOTO Quit
      END

      -- Check stock to putaway
      IF NOT EXISTS( SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) 
         WHERE LOT = @cLOT 
            AND LOC = @cLOC 
            AND ID = @cID 
            AND QTY-QTYAllocated-QTYPicked >= @nQTY)
      BEGIN
         SET @nErrNo = 55953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPutawayStock
         GOTO Quit
      END
   END
   
   IF @cType = 'SUGGEST'
   BEGIN
      SET @cSuggToLOC = ''
      SET @cPickAndDropLOC  = ''
      SET @cFitCasesInAisle = ''
      SET @nPABookingKey = 0
      
      -- Get extended putaway
      DECLARE @cExtendedPutawaySP NVARCHAR(20)
      SET @cExtendedPutawaySP = rdt.rdtGetConfig( @nFunc, 'ExtendedPutawaySP', @cStorerKey)
      IF @cExtendedPutawaySP = '0'
         SET @cExtendedPutawaySP = ''  

      -- Extended putaway
      IF @cExtendedPutawaySP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, @nQTY, ' +
               ' @cRDLineNo, @cFinalLOC, @cSuggToLOC OUTPUT, @nPABookingKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile       INT,           ' + 
               ' @nFunc         INT,           ' + 
               ' @cLangCode     NVARCHAR( 3),  ' + 
               ' @nStep         INT,           ' + 
               ' @nInputKey     INT,           ' + 
               ' @cFacility     NVARCHAR( 5),  ' + 
               ' @cStorerKey    NVARCHAR( 15), ' + 
               ' @cType         NVARCHAR( 10), ' + 
               ' @cRefNo        NVARCHAR( 20), ' + 
               ' @cColumnName   NVARCHAR( 20), ' + 
               ' @cLOC          NVARCHAR( 10), ' + 
               ' @cID           NVARCHAR( 18), ' + 
               ' @cSKU          NVARCHAR( 20), ' + 
               ' @nQTY          INT,           ' + 
               ' @cRDLineNo     NVARCHAR(5),   ' + 
               ' @cFinalLOC     NVARCHAR( 10), ' + 
               ' @cSuggToLOC    NVARCHAR( 10)  OUTPUT, ' + 
               ' @nPABookingKey INT            OUTPUT, ' + 
               ' @nErrNo        INT            OUTPUT, ' + 
               ' @cErrMsg       NVARCHAR( 20)  OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, @nQTY, 
               @cRDLineNo, @cFinalLOC, @cSuggToLOC OUTPUT, @nPABookingKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      ELSE
         -- Suggest LOC
         EXEC @nErrNo = dbo.nspRDTPASTD
              @c_userid          = 'RDT'
            , @c_storerkey       = @cStorerKey
            , @c_lot             = @cLOT
            , @c_sku             = @cSKU
            , @c_id              = @cID
            , @c_fromloc         = @cLOC
            , @n_qty             = @nQTY
            , @c_uom             = '' -- not used
            , @c_packkey         = '' -- optional, if pass-in SKU
            , @n_putawaycapacity = 0
            , @c_final_toloc     = @cSuggToLOC        OUTPUT
            , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
            , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT

      -- Check suggest loc
      IF @cSuggToLOC = ''
      BEGIN
         SET @nErrNo = 55954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLOC
         GOTO Quit
      END

      -- Lock suggested location
      IF @cSuggToLOC <> '' 
      BEGIN
         -- Handling transaction
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_ConReceive_Putaway -- For rollback or commit only our own transaction
                  
         IF @cFitCasesInAisle <> 'Y'
         BEGIN
            EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
               ,@cLOC
               ,@cID
               ,@cSuggToLOC
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cSKU
               ,@nPutawayQTY = @nQTY
               ,@cFromLOT = @cLOT
               ,@nFunc = @nFunc
               ,@nPABookingKey = @nPABookingKey OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         -- Lock PND location
         IF @cPickAndDropLOC <> ''
         BEGIN
            EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
               ,@cLOC
               ,@cID
               ,@cPickAndDropLOC
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cSKU
               ,@nPutawayQTY = @nQTY
               ,@cFromLOT = @cLOT
               ,@nFunc = @nFunc
               ,@nPABookingKey = @nPABookingKey OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         COMMIT TRAN rdt_ConReceive_Putaway -- Only commit change made here
      END
   END
   
   IF @cType = 'EXECUTE'
   BEGIN
      -- Check blank
      IF @cFinalLOC = ''
      BEGIN
         SET @nErrNo = 55955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need FinalLOC
         GOTO Quit
      END

      -- Check different LOC
      IF @cSuggToLOC <> @cFinalLOC AND @cSuggToLOC <> ''
      BEGIN
         DECLARE @cOverrideSuggestLOC NVARCHAR( 1)
         SET @cOverrideSuggestLOC = rdt.RDTGetConfig( @nFunc, 'OverrideSuggestLOC', @cStorerKey)

         -- Check allow overwrite
         IF @cOverrideSuggestLOC <> '1'
         BEGIN
            SET @nErrNo = 55956
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC
            GOTO Quit
         END
      END

      -- Get LOC info
      DECLARE @cChkLOC NVARCHAR(10)
      DECLARE @cChkFacility NVARCHAR(5)
      SET @cChkLOC = ''
      SET @cChkFacility = ''
      SELECT
         @cChkLOC = LOC,
         @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cFinalLOC

      -- Check LOC valid
      IF @cChkLOC = ''
      BEGIN
         SET @nErrNo = 55957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Quit
      END

      -- Check facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 55958
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Quit
      END
      
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_ConReceive_Putaway -- For rollback or commit only our own transaction
      
      -- Execute putaway process
      EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility
         ,@cLOT
         ,@cLOC
         ,@cID
         ,@cStorerKey
         ,@cSKU
         ,@nQTY
         ,@cFinalLOC
         ,'' -- LabelType
         ,'' -- UCC            
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      IF @nPABookingKey <> 0
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --SuggestedLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
            
      COMMIT TRAN rdt_ConReceive_Putaway
   END
   
   IF @cType = 'CANCEL'
   BEGIN
      IF @nPABookingKey <> 0
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --SuggestedLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_ConReceive_Putaway -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO