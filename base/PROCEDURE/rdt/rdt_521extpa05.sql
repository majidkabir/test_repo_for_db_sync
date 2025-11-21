SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA05                                      */
/*                                                                      */
/* Purpose: Use RDT config to get suggested loc else return blank loc   */
/*                                                                      */
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2020-03-09   1.0  James    WMS-12060. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_521ExtPA05] (
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
   @nQty             INT,          
   @cSuggestedLOC    NVARCHAR( 10) = '' OUTPUT,  
   @cPickAndDropLoc  NVARCHAR( 10)      OUTPUT,  
   @nPABookingKey    INT                OUTPUT,  
   @nErrNo           INT                OUTPUT, 
   @cErrMsg          NVARCHAR( 20)      OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nUCCQty        INT
   DECLARE @nTranCount     INT
   DECLARE @cUCC_SKU       NVARCHAR( 20)
   DECLARE @cSUSR1         NVARCHAR( 18)
   DECLARE @cUdf06         NVARCHAR( 30)
   DECLARE @cUdf07         NVARCHAR( 30)
   DECLARE @cUdf08         NVARCHAR( 30)
   DECLARE @cUdf09         NVARCHAR( 30)
   DECLARE @cUdf10         NVARCHAR( 30)
   DECLARE @cCode          NVARCHAR( 3)
   DECLARE @cUCC_ID        NVARCHAR( 18)
   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cReceiptKey    NVARCHAR( 10)
   DECLARE @cPAStrategyKey NVARCHAR( 10)
   DECLARE @cProductCategory  NVARCHAR( 30)
   DECLARE @cSKUPutawayZone   NVARCHAR( 10)
   DECLARE @cFitCasesInAisle  NVARCHAR( 1)
   DECLARE @cPltMaxCnt        NVARCHAR( 5)
   DECLARE @nPltCtnCount      INT
   DECLARE @nFullPlt          INT
   DECLARE @cPA_Zone       NVARCHAR( 10)
   
   SET @cSuggestedLOC = ''
   SET @cFitCasesInAisle = ''
   SET @cPickAndDropLoc = ''

   SELECT TOP 1 @cUCC_ID = Id, 
                @cUCC_SKU = SKU,
                @cReceiptKey = Receiptkey
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cUCC
   AND   [Status] = '1'
   ORDER BY 1

   -- Check if this ucc from loose pallet
   -- If the pallet id is from non-reserved loc then it is consider loose pallet
   SET @cPosition = ''
   SELECT @cPosition = Position
   FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
   WHERE Receiptkey = @cReceiptKey
   AND   ID = @cUCC_ID
   AND   UCCNo = @cUCC
   AND   SKU = @cUCC_SKU

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_521ExtPA05 -- For rollback or commit only our own transaction
                               --    
   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
               WHERE LISTNAME = 'PreRcvLane'
               AND   Code = @cPosition
               AND   Short <> 'R')
   BEGIN
      SET @cProductCategory = ''
      SET @cSKUPutawayZone = ''
      SET @cCode = ''

      SELECT @cProductCategory = BUSR7, 
             @cSKUPutawayZone = PutawayZone
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND Sku = @cUCC_SKU

      -- Get pallet can store how many carton
      SELECT @cPltMaxCnt = Short
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'PAPltMxCnt'
      AND   Code = @cProductCategory
      AND   Storerkey = @cStorerKey
   
      -- Get total carton on pallet
      SELECT @nPltCtnCount = COUNT( DISTINCT UCCNo)
      FROM dbo.UCC UCC WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( UCC.Loc = LOC.Loc)
      WHERE UCC.Storerkey = @cStorerKey
      AND   UCC.LOC = @cLOC
      AND   UCC.ID = @cID
      AND   UCC.Status = '1'
      AND   LOC.Facility = @cFacility

      -- Define full or loose pallet
      IF @nPltCtnCount < @cPltMaxCnt
      BEGIN
         SET @nFullPlt = 0
      END
      ELSE
      BEGIN
         SET @nFullPlt = 1
         SET @nErrNo = 150451  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NotLoosePallet  
         GOTO Quit  
      END
   
      SET @cCode = RTRIM( @cProductCategory) + CAST( @nFullPlt AS NVARCHAR( 1))
      SELECT @cPAStrategyKey = ISNULL( Short, '')
      FROM dbo.CodeLkup WITH (NOLOCK)
      WHERE ListName = 'NKRDTExtPA'
      AND   Code = @cCode
      AND   StorerKey = @cStorerKey
      AND   code2 = @cSKUPutawayZone

      -- Check blank putaway strategy
      IF @cPAStrategyKey = ''
      BEGIN
         SET @nErrNo = 150452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet
         GOTO RollBackTran
      END
   
      -- Check putaway strategy valid
      IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)
      BEGIN
         SET @nErrNo = 150453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BadStrategyKey
         GOTO RollBackTran
      END
      
      DECLARE @cur_Zone    CURSOR
      SET @cur_Zone = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT Zone 
      FROM dbo.PutawayStrategyDetail WITH (NOLOCK) 
      WHERE PutawayStrategyKey = @cPAStrategyKey
      AND   PAType = '18'
      ORDER BY PutawayStrategyLineNumber
      OPEN @cur_Zone
      FETCH NEXT FROM @cur_Zone INTO @cPA_Zone
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Find loc that can fit maxcarton criteria
         SELECT TOP 1 @cSuggestedLOC = LOC.Loc
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC LOC WITH (NOLOCK) ON LLI.loc = LOC.loc
         WHERE LLI.Qty > 0 
         AND   LOC.putawayzone = @cPA_Zone 
         AND   LOC.Facility = @cFacility
         AND ( SELECT COUNT( DISTINCT UCC.UCCNo) + 1
         FROM UCC UCC WITH (NOLOCK)  
         WHERE LLI.Loc = UCC.Loc 
         AND  (LLI.QTY > 0 OR LLI.PendingMoveIN > 0)) <= LOC.MaxCarton  
         ORDER BY LOC.PALogicalLoc, LOC.LOC
         
         IF @@ROWCOUNT = 1
            BREAK

         FETCH NEXT FROM @cur_Zone INTO @cPA_Zone
      END

      IF @cSuggestedLOC = ''
         EXEC @nErrNo = [dbo].[nspRDTPASTD]
              @c_userid          = 'RDT'
            , @c_storerkey       = @cStorerKey
            , @c_lot             = ''
            , @c_sku             = ''
            , @c_id              = @cID
            , @c_fromloc         = @cLOC
            , @n_qty             = 0
            , @c_uom             = '' -- not used
            , @c_packkey         = '' -- optional, if pass-in SKU
            , @n_putawaycapacity = 0
            , @c_final_toloc     = @cSuggestedLOC     OUTPUT
            , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
            , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT
            , @c_PAStrategyKey   = @cPAStrategyKey
            , @n_PABookingKey    = @nPABookingKey     OUTPUT

      IF ISNULL( @cSuggestedLOC, '') <> ''
      BEGIN
         IF @cFitCasesInAisle <> 'Y'
         BEGIN
            EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
               ,@cLOC
               ,@cID
               ,@cSuggestedLOC
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
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
               ,@nPABookingKey = @nPABookingKey OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 150454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Suggested LOC
         GOTO RollBackTran
      END

      IF @cFitCasesInAisle = 'Y'
      BEGIN
         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT UCCNo, LOT, LOC, SKU
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   LOC = @cLOC
         AND   ID = @cID
         AND   Status = '1'
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @cUCC, @cLOT, @cLOC, @cSKU
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE dbo.RFPutaway WITH (ROWLOCK) SET 
               CaseID = @cUCC
            WHERE StorerKey = @cStorerKey
            AND   LOT = @cLOT
            AND   FromLOC = @cLOC
            AND   ID = @cID
            AND   SKU = @cSKU

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 150455
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRFPutaway Err
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               GOTO RollBackTran
            END
            FETCH NEXT FROM CUR_UPD INTO @cUCC, @cLOT, @cLOC, @cSKU
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD
      END
   END
   ELSE
   BEGIN
      SELECT @cSUSR1 = SUSR1 
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      -- sequence to display for nike sdc is 10, 6, 7, 8, 9
      SELECT   
         @cUdf10 = MAX( Userdefined10),
         @cUdf06 = CASE WHEN MAX( Userdefined10) = '1' THEN '' ELSE MIN( Userdefined06) END,
         @cUdf07 = CASE WHEN MAX( Userdefined10) = '1' OR MIN( Userdefined06) = '1' THEN '' ELSE MIN( Userdefined07) END,
         @cUdf08 = CASE WHEN MAX( Userdefined10) = '1' OR MIN( Userdefined07) = '1' THEN '' ELSE MIN( Userdefined08) END,
         @cUdf09 = CASE WHEN MAX( Userdefined10) = '1' OR MIN( Userdefined08) = '1' THEN '' ELSE MIN( Userdefined09) END
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   UCCNo = @cUCC
      AND   [Status] = '1' -- received

      IF ISNULL( @cUdf10, '') = '1'
         SET @cCode = '001'               -- Quick strike
      ELSE IF ISNULL( @cUdf06, '') = '1'
         SET @cCode = '002'               -- 1st sku
      ELSE IF ISNULL( @cUdf07, '') = '1'
         SET @cCode = '003'               -- Mixed sku
      ELSE IF ISNULL( @cUdf08, '') = '1'
         SET @cCode = '004'               -- QA
      ELSE IF ISNULL( @cUdf09, '') = '1'
         SET @cCode = '005'               -- Special ucc
      ELSE
      BEGIN
         SELECT @nUCCQty = ISNULL( SUM( Qty), 0)
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         AND   [Status] = '1' -- received

         IF RDT.rdtIsValidQTY( @cSUSR1, 0) = 1
         BEGIN
            IF @nUCCQty < CAST( @cSUSR1 AS INT)
               SET @cCode = '006'         -- Less ucc std count
         END
         ELSE
            SET @cCode = ''
      END
   
      IF @cCode IN ( '002', '004', '006')
      BEGIN
         --should not check the capacity even it is already full 
         --system should putaway to the PickLoc that's their rule
         SELECT TOP 1 @cSuggestedLOC = SL.LOC
         FROM dbo.SKUxLOC SL WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
         AND   SL.SKU = @cUCC_SKU
         AND   SL.StorerKey = @cStorerKey
         AND   SL.LocationType = 'PICK'
         ORDER BY SL.LOC
      
         IF ISNULL( @cSuggestedLOC, '') = ''
         BEGIN
            SET @nErrNo = 150456
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Home Loc
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         SELECT TOP 1 @cSuggestedLOC = LOC.Loc
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
         JOIN dbo.UCC UCC WITH (NOLOCK) ON ( LLI.Loc = UCC.Loc)
         WHERE LLI.StorerKey = @cStorerKey
         AND   LOC.LocationRoom IN ('CASE', 'MEZZANINE')
         AND   LOC.Facility = @cFacility
         AND   LOC.LocationType = 'OTHER'
         AND   LOC.[Status] = 'OK'
         AND   LOC.Locationflag = 'NONE'
         AND   LOC.LocationType NOT IN ('DYNPPICK', 'DYNPICKP', 'DAMAGE')
         GROUP BY LOC.Loc, LOC.LogicalLocation, LOC.MaxPallet, LOC.MaxCarton
         HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
                     ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) > 0 
                AND ( LOC.MaxCarton >= ( COUNT( DISTINCT UCC.UCCNo) + 1))
         ORDER BY LOC.LogicalLocation, LOC.Loc

         IF ISNULL( @cSuggestedLOC, '') = ''
         BEGIN
            SELECT TOP 1 @cSuggestedLOC = LOC.Loc
            FROM dbo.LOC LOC WITH (NOLOCK)
            LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
            JOIN dbo.UCC UCC WITH (NOLOCK) ON ( LLI.Loc = UCC.Loc)
            WHERE LLI.StorerKey = @cStorerKey
            AND   LOC.LocationRoom IN ('CASE', 'MEZZANINE')
            AND   LOC.Facility = @cFacility
            AND   LOC.LocationType = 'OTHER'
            AND   LOC.[Status] = 'OK'
            AND   LOC.Locationflag = 'NONE'
            AND   LOC.LocationType NOT IN ('DYNPPICK', 'DYNPICKP', 'DAMAGE')
            GROUP BY LOC.Loc, LOC.LogicalLocation, LOC.MaxPallet
            HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
                        ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0 
            ORDER BY LOC.LogicalLocation, LOC.Loc
         END
      END

      IF ISNULL( @cSuggestedLOC, '') = ''
      BEGIN
         SET @nErrNo = 150457
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Sugg Loc
         GOTO RollBackTran
      END
      
      /*-------------------------------------------------------------------------------
                                    Book suggested location
      -------------------------------------------------------------------------------*/

      IF ISNULL( @cSuggestedLOC, '') <> ''
      BEGIN
         SET @nErrNo = 0
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cLoc
            ,@cID
            ,@cSuggestedLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@cSKU          = @cUCC_SKU
            ,@cUCCNo        = @cUCC                
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_521ExtPA05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO