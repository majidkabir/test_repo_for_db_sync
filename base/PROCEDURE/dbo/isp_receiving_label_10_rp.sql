SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: isp_Receiving_Label_10_RP                              */
/* Purpose: SKU label                                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2013-09-03 1.0  Ung      SOS288082 Created                              */
/* 2014-09-30 1.1  Ung      SOS317520 Add new field                        */
/* 2015-01-05 1.2  Ung      SOS328774 Add putaway criteria                 */
/* 2015-01-15 1.3  CSCHONG  New lottable 05 to 15 (CS01)                   */
/* 2015-11-23 1.4  Ung      SOS357530 Fix convert date                     */
/***************************************************************************/

CREATE PROC [dbo].[isp_Receiving_Label_10_RP] (
   @nMobile     INT, 
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @cStorerKey  NVARCHAR( 15), 
   @cByRef1     NVARCHAR( 20), 
   @cByRef2     NVARCHAR( 20), 
   @cByRef3     NVARCHAR( 20), 
   @cByRef4     NVARCHAR( 20), 
   @cByRef5     NVARCHAR( 20), 
   @cByRef6     NVARCHAR( 20), 
   @cByRef7     NVARCHAR( 20), 
   @cByRef8     NVARCHAR( 20), 
   @cByRef9     NVARCHAR( 20), 
   @cByRef10    NVARCHAR( 20), 
   @cPrintTemplate NVARCHAR( MAX), 
   @cPrintData  NVARCHAR( MAX) OUTPUT,
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount  INT
   DECLARE @bSuccess    INT
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cAltSKU     NVARCHAR( 20)
   DECLARE @cPickLOC    NVARCHAR( 10)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cLottable01 NVARCHAR( 18)
   DECLARE @cLottable02 NVARCHAR( 18)
   DECLARE @cLottable03 NVARCHAR( 18)
   DECLARE @dLottable04 DATETIME
   DECLARE @dLottable05 DATETIME
   DECLARE @cLottable06 NVARCHAR( 30)   --(CS01)
   DECLARE @cLottable07 NVARCHAR( 30)   --(CS01)
   DECLARE @cLottable08 NVARCHAR( 30)   --(CS01)
   DECLARE @cLottable09 NVARCHAR( 30)   --(CS01)
   DECLARE @cLottable10 NVARCHAR( 30)   --(CS01)
   DECLARE @cLottable11 NVARCHAR( 30)   --(CS01)
   DECLARE @cLottable12 NVARCHAR( 30)   --(CS01)
   DECLARE @dLottable13 DATETIME        --(CS01)
   DECLARE @dLottable14 DATETIME        --(CS01)
   DECLARE @dLottable15 DATETIME        --(CS01)
   DECLARE @cField03    NVARCHAR(30)
   DECLARE @cField08    NVARCHAR(2)
   DECLARE @cField07    NVARCHAR(20)
   DECLARE @cReceiptKey NVARCHAR( 10)
   DECLARE @cReceiptLineNumber NVARCHAR( 5)
   DECLARE @cPrintFlag  NVARCHAR( 10)
   DECLARE @cPutawayZone NVARCHAR(10)

   SET @nTranCount = @@TRANCOUNT
   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @cUserName = LEFT( SUSER_SNAME(), 18)
   SET @cPickLOC = ''
   
   SET @cReceiptKey        = @cByRef1
   SET @cReceiptLineNumber = @cByRef2
   SET @cPrintFlag         = @cByRef4

   -- Get Receipt info
   SELECT 
      @cStorerKey = StorerKey,
      @cFacility = Facility
   FROM Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey 
   
   IF @@ROWCOUNT = 0
      RETURN
   
   -- Get ReceiptDetail info
   /*CS01 start*/
   SELECT 
      @cSKU = SKU, 
      @cFromLOC = ToLOC, 
      @cFromID = ToID,
      @cLottable01 = Lottable01,
      @cLottable02 = Lottable02,
      @cLottable03 = Lottable03,
      @dLottable04 = Lottable04,
      @dLottable05 = Lottable05,
      @cLottable06 = Lottable06,
      @cLottable07 = Lottable07,
      @cLottable08 = Lottable08,
      @cLottable09 = Lottable09,
      @cLottable10 = Lottable10,
      @cLottable11 = Lottable11,
      @cLottable12 = Lottable12,
      @dLottable13 = Lottable13,
      @dLottable14 = Lottable14,
      @dLottable15 = Lottable15
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey 
      AND ReceiptLineNumber = @cReceiptLineNumber

   /*CS01 END*/
   IF @@ROWCOUNT = 0
      RETURN
   
   -- Get SKU info
   SELECT
      @cAltSKU = AltSKU, 
      @cPutawayZone = PutawayZone
   FROM SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Find a friend with actual stock
   IF @cPickLOC = ''
      SELECT TOP 1
         @cPickLOC = LOC.LOC
      FROM SKUxLOC SL WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOC.PutawayZone = @cPutawayZone
         AND LOC.LocationCategory = 'RESALE'
         AND LOC.LocationGroup <> 'HIGHVOLUME'
         AND SL.QTY - SL.QTYPicked > 0

   -- Find a friend with pending move in
   IF @cPickLOC = ''
      SELECT TOP 1
         @cPickLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOC.PutawayZone = @cPutawayZone
         AND LOC.LocationCategory = 'RESALE'
         AND LOC.LocationGroup <> 'HIGHVOLUME'
         AND LLI.PendingMoveIn > 0

   -- Find empty LOC
   IF @cPickLOC = ''
      SELECT TOP 1
         @cPickLOC = LOC.LOC
      FROM LOC WITH (NOLOCK) 
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         LEFT JOIN SKUxLOC SL WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.SKU = SL.SKU AND LLI.LOC = SL.LOC)
      WHERE LOC.Facility = @cFacility
         AND LOC.LocationCategory = 'RESALE'
         AND LOC.LocationGroup <> 'HIGHVOLUME'
         AND LOC.PutawayZone = @cPutawayZone
      GROUP BY LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
         
   /*-------------------------------------------------------------------------------
   
                              Create LOT if not yet receive

   -------------------------------------------------------------------------------*/
   IF @cPickLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN isp_Receiving_Label_10_RP -- For rollback or commit only our own transaction
      
      -- Stamp receiving date (to get LOT in below)
      IF @dLottable05 IS NULL
      BEGIN
         SET @dLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), GETDATE(), 120), 120)
         UPDATE ReceiptDetail SET
            Lottable05 = @dLottable05
         WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cReceiptLineNumber
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollbackTran
         END
      END
      
      -- LOT lookup
      SET @cLOT = ''
      EXECUTE dbo.nsp_LotLookUp
          @cStorerKey
        , @cSKU
        , @cLottable01
        , @cLottable02
        , @cLottable03
        , @dLottable04
        , @dLottable05
        , @cLottable06    --(CS01)
        , @cLottable07    --(CS01)
        , @cLottable08    --(CS01)
        , @cLottable09    --(CS01)
        , @cLottable10    --(CS01)
        , @cLottable11    --(CS01)
        , @cLottable12    --(CS01)
        , @dLottable13    --(CS01)
        , @dLottable14    --(CS01)
        , @dLottable15    --(CS01)
        , @cLOT      OUTPUT
        , @bSuccess  OUTPUT
        , @nErrNo    OUTPUT
        , @cErrMsg   OUTPUT

      -- Create LOT if not exist
      IF @cLOT IS NULL
      BEGIN
         EXECUTE dbo.nsp_LotGen
            @cStorerKey
          , @cSKU
          , @cLottable01
          , @cLottable02
          , @cLottable03
          , @dLottable04
          , @dLottable05
          , @cLottable06    --(CS01)
          , @cLottable07    --(CS01)
          , @cLottable08    --(CS01)
          , @cLottable09    --(CS01)
          , @cLottable10    --(CS01)
          , @cLottable11    --(CS01)
          , @cLottable12    --(CS01)
          , @dLottable13    --(CS01)
          , @dLottable14    --(CS01)
          , @dLottable15    --(CS01)
          , @cLOT     OUTPUT
          , @bSuccess OUTPUT
          , @nErrNo   OUTPUT
          , @cErrMsg  OUTPUT
         IF @bSuccess <> 1
            GOTO RollbackTran

         IF NOT EXISTS( SELECT 1 FROM LOT (NOLOCK) WHERE LOT = @cLOT)
         BEGIN
            INSERT INTO LOT (LOT, StorerKey, SKU) VALUES (@cLOT, @cStorerKey, @cSKU)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 83751
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOT Fail
               GOTO RollbackTran
            END
         END
      END

      -- Create ToID if not exist
      IF @cFromID <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cFromID)
         BEGIN
            INSERT INTO ID (ID) VALUES (@cFromID)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 83752
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ID Fail
               GOTO RollbackTran
            END
         END
      END

      -- Booking location
      IF @cPrintFlag <> 'REPRINT'
      BEGIN
         -- Book location in RFPutaway
         IF EXISTS( SELECT TOP 1 1 
            FROM RFPutaway WITH (NOLOCK) 
            WHERE LOT = @cLOT
               AND FromLOC = @cFromLOC
               AND FromID = @cFromID
               AND SuggestedLOC = @cPickLOC)
         BEGIN
            UPDATE RFPutaway SET
               QTY = QTY + 1
            WHERE LOT = @cLOT
               AND FromLOC = @cFromLOC
               AND FromID = @cFromID
               AND SuggestedLOC = @cPickLOC
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollbackTran
            END
         END
         ELSE
         BEGIN
            -- Update RFPutaway
            INSERT INTO RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID)
            VALUES (@cStorerKey, @cSKU, @cLOT, @cFromLOC, @cFromID, @cPickLOC, @cFromID, @cUserName, 1, '')
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollbackTran
            END
         END
         
         -- Book location in LOTxLOCxID
         IF EXISTS (SELECT 1 
            FROM dbo.LOTxLOCxID WITH (NOLOCK)
            WHERE LOT = @cLOT
               AND LOC = @cPickLOC
               AND ID = @cFromID)
         BEGIN
            UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET 
               PendingMoveIn = CASE WHEN PendingMoveIn >= 0 THEN PendingMoveIn + 1 ELSE 0 END
            WHERE LOT = @cLOT
               AND LOC = @cPickLOC
               AND ID  = @cFromID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 83753
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
               GOTO RollbackTran
            END
         END
         ELSE
         BEGIN
            INSERT dbo.LOTxLOCxID (LOT, LOC, ID, Storerkey, SKU, PendingMoveIn)
            VALUES (@cLOT, @cPickLOC, @cFromID, @cStorerKey, @cSKU, 1)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 83754
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LLI Fail
               GOTO RollbackTran
            END
         END            
      END
      
      COMMIT TRAN isp_Receiving_Label_10_RP
   END

   IF @cPickLOC = ''
      SET @cPickLOC = 'NO LOC'
      
   --SELECT @cSKU SKU, @cAltSKU AltSKU, @cPickLOC LOC, @cReceiptKey ReceiptKey, @cUserName
   
   --Replace Template Start 
   SET @cUserName = ''
   SELECT @cUserName = UserName 
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @cField03 = SUBSTRING( @cPickLOC, 1, 2) + '-' + SUBSTRING( @cPickLOC,3, 2) + '-' + SUBSTRING( @cPickLOC, 5, 3) + '-' + SUBSTRING( @cPickLOC, 8, 2) + '-' + SUBSTRING( @cPickLOC, 10, 1)
   SET @cField08 = SUBSTRING( @cPickLOC, 3, 2) 
   
   SET @cField07 = CONVERT(NVARCHAR, GETDATE(), 111) + ' ' + LEFT(CONVERT(NVARCHAR, GETDATE(), 114), 5)
   
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cSKU))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', RTRIM( @cAltSKU))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', RTRIM( @cField03))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', RTRIM( @cReceiptKey))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', RTRIM( @cUserName))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field06>', RTRIM( @cFromID))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field07>', RTRIM( @cField07))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field08>', RTRIM( @cField08)) 
   
   SET @cPrintData = @cPrintTemplate
   
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN isp_Receiving_Label_10_RP -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO