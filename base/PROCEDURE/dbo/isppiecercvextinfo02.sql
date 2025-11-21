SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPieceRcvExtInfo02                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 29-11-2013  1.0  ChewKP      SOS#292548. Created                     */
/* 22-09-2014  1.1  Chee        Bug Fix Lottable04 (Chee01)             */
/* 14-10-2014  1.2  ChewKP      Including Multiple PA Zone (ChewKP01)   */
/* 15-01-2015  1.3  CSCHONG     New lottable 05 to 15 (CS01)            */
/* 13-08-2015  1.4  Ung         SOS337296 Booking by QTY                */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPieceRcvExtInfo02]
   @c_ReceiptKey     NVARCHAR(10),
   @c_POKey          NVARCHAR(10),
   @c_ToLOC          NVARCHAR(10),
   @c_ToID           NVARCHAR(18),
   @c_Lottable01     NVARCHAR(18),
   @c_Lottable02     NVARCHAR(18),
   @c_Lottable03     NVARCHAR(18),
   @d_Lottable04     DATETIME,
   @c_StorerKey      NVARCHAR(15),
   @c_SKU            NVARCHAR(20),
   @c_oFieled01      NVARCHAR(20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE    @nErrNo         INT
            , @cErrMsg        NVARCHAR( 20)
            , @cLOT           NVARCHAR( 10)
            , @d_Lottable05   DATETIME
            , @bSuccess       INT
            , @c_UserName     NVARCHAR(18)
            , @cLangCode      NVARCHAR(3)
            , @nTranCount     INT
            , @c_SuggestedLOC NVARCHAR(10)
            , @cQty           INT

   DECLARE @cPutawayZone NVARCHAR(10)
   DECLARE @cFacility   NVARCHAR( 5)
          ,@cUDF01      NVARCHAR(10)
          ,@cUDF02      NVARCHAR(10)
          ,@cUDF03      NVARCHAR(10)

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   SET @c_oFieled01 = ''
   SET @c_SuggestedLOC = ''
   SET @cPutawayZone = ''
   SET @cFacility = ''
   SET @cUDF01 = ''
   SET @cUDF02 = ''
   SET @cUDF03 = ''

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN ispPieceRcvExtInfo02 -- For rollback or commit only our own transaction

   SELECT
      @cFacility = Facility
   FROM Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @c_ReceiptKey

   SELECT
      @cPutawayZone = PutawayZone
   FROM SKU WITH (NOLOCK)
   WHERE StorerKey = @c_StorerKey
      AND SKU = @c_SKU

   -- Stamp receiving date (to get LOT in below)
   SELECT @d_Lottable05 = CONVERT(NVARCHAR(20), getdate(),112)

   SELECT
        @c_Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN Lottable01 ELSE @c_Lottable01 END
      , @c_Lottable02 = CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN Lottable02 ELSE @c_Lottable02 END
      , @c_Lottable03 = CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN Lottable03 ELSE @c_Lottable03 END
      , @d_Lottable04 = Lottable04 --CASE WHEN ISNULL(RTRIM(@d_Lottable04),'') = '' THEN Lottable04 ELSE @d_Lottable04 END -- (Chee01)
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @c_ReceiptKey
   AND SKU          = @c_SKU
   AND StorerKey    = @c_StorerKey

   SET @c_UserName = suser_sname()

   SELECT   @cLangCode = Lang_Code
          , @cQty = I_Field05
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE UserName = @c_UserName
   Order by EditDate Desc

   IF ISNULL(@cQty,'' ) = ''
   BEGIN
      -- No Input of @cQty
      SET @c_oFieled01 = ''
      GOTO QUIT
   END

   -- LOT lookup
   SET @cLOT = ''
   EXECUTE dbo.nsp_LotLookUp
        @c_StorerKey
      , @c_SKU
      , @c_Lottable01
      , @c_Lottable02
      , @c_Lottable03
      , @d_Lottable04
      , @d_Lottable05
      , ''   --(CS01)
      , ''   --(CS01)
      , ''   --(CS01)
      , ''   --(CS01)
      , ''   --(CS01)
      , ''   --(CS01)
      , ''   --(CS01)
      , NULL   --(CS01)
      , NULL   --(CS01)
      , NULL   --(CS01)
      , @cLOT      OUTPUT
      , @bSuccess  OUTPUT
      , @nErrNo    OUTPUT
      , @cErrMsg   OUTPUT

   -- Create LOT if not exist
   IF @cLOT IS NULL
   BEGIN
      EXECUTE dbo.nsp_LotGen
           @c_StorerKey
         , @c_SKU
         , @c_Lottable01
         , @c_Lottable02
         , @c_Lottable03
         , @d_Lottable04
         , @d_Lottable05
         , ''   --(CS01)
         , ''   --(CS01)
         , ''   --(CS01)
         , ''   --(CS01)
         , ''   --(CS01)
         , ''   --(CS01)
         , ''   --(CS01)
         , NULL  --(CS01)
         , NULL   --(CS01)
         , NULL   --(CS01)
         , @cLOT     OUTPUT
         , @bSuccess OUTPUT
         , @nErrNo   OUTPUT
         , @cErrMsg  OUTPUT
      IF @bSuccess <> 1
         GOTO RollbackTran

      IF NOT EXISTS( SELECT 1 FROM LOT (NOLOCK) WHERE LOT = @cLOT)
      BEGIN
         INSERT INTO LOT (LOT, StorerKey, SKU) VALUES (@cLOT, @c_StorerKey, @c_SKU)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 83951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOT Fail
            GOTO RollbackTran
         END
      END
   END

   -- Create ToID if not exist
   IF @c_ToID <> ''
   BEGIN
      IF NOT EXISTS( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @c_ToID)
      BEGIN
         INSERT INTO ID (ID) VALUES (@c_ToID)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 83952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ID Fail
            GOTO RollbackTran
         END
      END
   END

   -- (ChewKP01)
   SELECT TOP 1 @cUDF01 = ISNULL(UDF01,'')
               ,@cUDF02 = ISNULL(UDF02,'')
               ,@cUDF03 = ISNULL(UDF03,'')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'Brand2Zone'
         AND Code = @cPutawayZone
         AND StorerKey = @c_StorerKey

   IF @c_SuggestedLOC = ''
      SELECT TOP 1
         @c_SuggestedLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
          JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
          JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT AND LA.SKU = LLI.SKU AND LA.StorerKey = LLI.StorerKey)
      WHERE LOC.Facility = @cFacility
         AND LLI.StorerKey = @c_StorerKey
         AND LLI.SKU = @c_SKU
         AND LOC.PutawayZone IN (  @cPutawayZone , @cUDF01 , @cUDF02 , @cUDF03 )
         AND LOC.LocationCategory = 'MEZZANINE'
         AND LA.Lottable03 = @c_Lottable03
      GROUP BY LOC.Facility, LLI.StorerKey, LLI.SKU, LOC.PutawayZone, LOC.LocationCategory, LA.Lottable03, Loc.Loc, Loc.PALogicalLoc
      HAVING  SUM(LLI.QTY) - SUM(LLI.QTYPicked) > 0
      ORDER BY Loc.PALogicalLoc, Loc.Loc

   -- Find a friend with pending move in
   IF @c_SuggestedLOC = ''
      SELECT TOP 1
         @c_SuggestedLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT AND LA.SKU = LLI.SKU AND LA.StorerKey = LLI.StorerKey)
      WHERE LOC.Facility = @cFacility
         AND LLI.StorerKey = @c_StorerKey
         AND LLI.SKU = @c_SKU
         AND LOC.PutawayZone IN (  @cPutawayZone , @cUDF01 , @cUDF02 , @cUDF03 )
         AND LOC.LocationCategory = 'MEZZANINE'
         AND LLI.PendingMoveIn > 0
         AND LA.Lottable03 = @c_Lottable03
       ORDER BY Loc.PALogicalLoc, Loc.Loc

   -- Find empty LOC
   IF @c_SuggestedLOC = ''
      SELECT TOP 1
         @c_SuggestedLOC = LOC.LOC
      FROM LOC WITH (NOLOCK)
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         LEFT JOIN SKUxLOC SL WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.SKU = SL.SKU AND LLI.LOC = SL.LOC)
      WHERE LOC.Facility = @cFacility
         AND LOC.LocationCategory = 'MEZZANINE'
         AND LOC.PutawayZone IN (  @cPutawayZone , @cUDF01 , @cUDF02 , @cUDF03 )
      GROUP BY LOC.LOC, Loc.PALogicalLoc
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
      ORDER BY Loc.PALogicalLoc, Loc.Loc

   -- Output suggested LOC
   SET @c_oFieled01 = 'FINAL LOC:' + @c_SuggestedLOC

   -- Booking
   IF @c_SuggestedLOC <> '' AND @c_SuggestedLOC <> 'SEE_SUPV'
   BEGIN
      -- Book location in RFPutaway
      IF EXISTS( SELECT TOP 1 1
         FROM RFPutaway WITH (NOLOCK)
         WHERE LOT = @cLOT
            AND FromLOC = @c_ToLOC
            AND FromID = @c_ToID
            AND SuggestedLOC = @c_SuggestedLOC)
      BEGIN
         UPDATE RFPutaway SET
            QTY = QTY + CAST( @cQty AS INT)
         WHERE LOT = @cLOT
            AND FromLOC = @c_ToLOC
            AND FromID = @c_ToID
            AND SuggestedLOC = @c_SuggestedLOC
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 83953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollbackTran
         END
      END
      ELSE
      BEGIN
         INSERT INTO RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID)
         VALUES (@c_StorerKey, @c_SKU, @cLOT, @c_ToLOC, @c_ToID, @c_SuggestedLOC, '', @c_UserName, @cQty, '')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 83953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSRFPAFail
            GOTO RollbackTran
         END
      END

      -- Book location in LOTxLOCxID
      IF EXISTS (SELECT 1
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE LOT = @cLOT
            AND LOC = @c_SuggestedLOC
            AND ID = '')
      BEGIN
         UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET
            PendingMoveIn = CASE WHEN PendingMoveIn >= 0 THEN PendingMoveIn + @cQty ELSE 0 END
         WHERE LOT = @cLOT
            AND LOC = @c_SuggestedLOC
            AND ID  = ''
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 83954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
            GOTO RollbackTran
         END
      END
      ELSE
      BEGIN
         INSERT dbo.LOTxLOCxID (LOT, LOC, ID, Storerkey, SKU, PendingMoveIn)
         VALUES (@cLOT, @c_SuggestedLOC, '', @c_StorerKey, @c_SKU, @cQty)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 83955
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LLI Fail
            GOTO RollbackTran
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN ispPieceRcvExtInfo02 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN ispPieceRcvExtInfo02

END

GO