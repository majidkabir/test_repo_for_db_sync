SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_941ReplenMove03                                 */
/* Copyright      : Maersk                                              */
/* Customer       : Granite                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-08-06 1.0  Cuize    FCR-674. Created                            */
/* 2024-10-01 1.1  NLT013   Unlock original destination loc if it is    */
/*                          overwritten                                 */
/************************************************************************/

CREATE   PROC [RDT].[rdt_941ReplenMove03] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @cSourceType NVARCHAR( 30),
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cFromLOC    NVARCHAR( 10),
   @cToLOC      NVARCHAR( 10),
   @cFromID     NVARCHAR( 18) = NULL, -- NULL means not filter by ID. Blank ID is a valid ID
   @cToID       NVARCHAR( 18) = NULL, -- NULL means not changing ID. Blank ID is a valid ID
   @cSKU        NVARCHAR( 20) = NULL, -- Either SKU or UCC only
   @cUCC        NVARCHAR( 20) = NULL, --
   @nQTY        INT       = 0,    -- For move by SKU, QTY must have value
   @cFromLOT    NVARCHAR( 10) = NULL, -- Applicable for all 6 types of move
   @cWaveKey    NVARCHAR( 10),
   @cReplenKey  NVARCHAR( 10),
   @cLottable01 NVARCHAR( 18),
   @cLottable02 NVARCHAR( 18),
   @cLottable03 NVARCHAR( 18),
   @dLottable04 DATETIME,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT,  -- screen limitation, 20 char max
   @nUCC_RowRef INT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @cChkFacility   NVARCHAR( 5)
      ,@cLoseID       NVARCHAR( 1)
      ,@cUCCLOT       NVARCHAR( 10)
      ,@cID           NVARCHAR( 18)
      ,@cUCCSKU       NVARCHAR( 20)
      ,@cLOC          NVARCHAR( 10)
      ,@cLot          NVARCHAR( 10)
      ,@cPickDetailKey    NVARCHAR( 10)
      ,@cStorerConfig_UCC  NVARCHAR( 1)
      ,@cPickHeaderKey    NVARCHAR( 10)
      ,@cOrderKey    NVARCHAR( 10)
      ,@cOrderLineNo NVARCHAR( 5)
      ,@cUOM         NVARCHAR(10)
      ,@cPackKey     NVARCHAR(10)
      ,@c_errmsg      NVARCHAR( 250)
      ,@cLocationType NVARCHAR( 10)
      ,@b_Success     INT
      ,@n_err         INT
      ,@nRowCount     INT
      ,@nCnt          INT
      ,@n_OrdAvailQTY INT
      ,@n_UOMQTY      INT
      ,@cRetrieveDynamicPickslipNo NVARCHAR( 30)
      ,@cPrintLabel   NVARCHAR(3)
      ,@cPrinter      NVARCHAR( 10)
      ,@nCartonNo     INT
      ,@cPickSlipNo   NVARCHAR( 10)
      ,@cDataWindow   NVARCHAR( 50)
      ,@cTargetDB     NVARCHAR( 10)
      ,@cLabelNo      NVARCHAR( 20)
      ,@cUCCStatus    NVARCHAR(  5)
      ,@nQtyInPickLoc INT
      ,@cMoveQTYAlloc NVARCHAR( 1)
      ,@cMoveQTYPick  NVARCHAR( 1)
      ,@cSQLStatement NVARCHAR( MAX)
      ,@cSQLParms     NVARCHAR( MAX)
      ,@cCartonLBL    NVARCHAR( 10)
      ,@cCtnMnFest    NVARCHAR( 10)
      ,@cPaperPrinter NVARCHAR( 10)
      ,@nStep         INT
      ,@nInputKey     INT
      ,@nQTYAlloc     INT
      ,@nQTYPick      INT
      ,@curUpdPD      CURSOR
      ,@cMoveQTYReplen NVARCHAR( 1)
      ,@nQTYReplen     INT

   SELECT
      @cPrinter = Printer,
      @cPaperPrinter = Printer_Paper,
      @nStep = Step,
      @nInputKey = InputKey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nErrNo = 0

   -- Get StorerConfig 'UCCTracking'
   SET @cStorerConfig_UCC = '0' -- Default Off
   SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
   FROM dbo.StorerConfig (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ConfigKey = 'UCC'

   SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.RDTGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cMoveQTYReplen = rdt.RDTGetConfig( @nFunc, 'MoveQTYReplen', @cStorerKey)

/*-------------------------------------------------------------------------------

                                 Validate parameters

-------------------------------------------------------------------------------*/
   -- Validate StorerKey (compulsory)
   IF @cStorerKey = '' OR @cStorerKey IS NULL
   BEGIN
      SET @nErrNo = 225401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need StorerKey'
      GOTO Fail
   END

   -- Validate Facility (compulsory)
   IF @cFacility = '' OR @cFacility IS NULL
   BEGIN
      SET @nErrNo = 225402
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need Facility'
      GOTO Fail
   END

   -- Validate SourceType (compulsory)
   IF @cSourceType IS NULL
   BEGIN
      SET @nErrNo = 225403
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad SourceType'
      GOTO Fail
   END

   -- Validate FromLOC (compulsory)
   IF @cFromLOC = '' OR @cFromLOC IS NULL
   BEGIN
      SET @nErrNo = 225404
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'FromLOC needed'
      GOTO Fail
   END
   ELSE
   BEGIN
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 225405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad FromLOC'
         GOTO Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 225406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO Fail
      END
   END

   -- Validate ToLOC (compulsory)
   IF @cToLOC = '' OR @cToLOC IS NULL
   BEGIN
      SET @nErrNo = 225407
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToLOC needed'
      GOTO Fail
   END
   ELSE
   BEGIN

      SELECT
         @cChkFacility = Facility,
         @cLoseID = LoseID
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate LOC
      IF @cToLoc <> 'PICK'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)
                         WHERE Loc = @cToLoc )
         BEGIN
            SET @nErrNo = 225408
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad ToLOC'
            GOTO Fail
         END
      END

      -- Validate ToLOC's facility
      IF NOT EXISTS( SELECT 1
         FROM rdt.StorerConfig (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ConfigKey = 'MoveToLOCNotCheckFacility'
            AND SValue = '1')
         IF @cChkFacility <> @cFacility
        BEGIN
          SET @nErrNo = 225409
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
          GOTO Fail
        END

   -- SOS72009 Checking for location not allow for comingle sku
   -- SOS#77266 - Rewrite
   DECLARE @nFromCnt int, @nToCnt int, @cFromSKU NVARCHAR(20), @cToSKU NVARCHAR(20)
   SELECT @nCnt = 0, @nFromCnt = 0, @nToCnt = 0
   IF EXISTS( SELECT 1
      FROM rdt.StorerConfig WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigKey = 'CheckNonCommingleSKUInMove'
         AND SValue = '1')
    BEGIN
      IF EXISTS (SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK)
                 WHERE LOC.LOC = @cToLOC
                 AND   LOC.CommingleSKU = '0')
      BEGIN
         SELECT @nFromCnt = COUNT(DISTINCT LLI.SKU)
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
         INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU)
         INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LLI.StorerKey = @cStorerKey
         AND LLI.LOC = @cFromLOC
  AND LLI.ID  = CASE WHEN @cFromID  IS NULL THEN LLI.ID  ELSE @cFromID  END
         AND LLI.LOT = CASE WHEN @cFromLOT IS NULL THEN LLI.LOT ELSE @cFromLOT END
         AND LLI.SKU = CASE WHEN @cSKU     IS NULL THEN LLI.SKU ELSE @cSKU     END -- Move by SKU
         AND LLI.LOT = CASE WHEN @cUCC     IS NULL THEN LLI.LOT ELSE @cUCCLOT  END -- Move by UCC (already got LOT,LOC,ID)
         GROUP BY LLI.Storerkey, LLI.SKU,  LLI.ID, LLI.LOT
         HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0

         IF @nFromCnt > 1
         BEGIN
            SET @nErrNo = 225410
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LocNotCommgSKU'
            GOTO Fail
         END

         SELECT @nToCnt = COUNT(DISTINCT LLI.SKU)
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
         INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU)
         INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LLI.StorerKey = @cStorerKey
         AND LLI.LOC = @cToLOC
         GROUP BY LLI.Storerkey, LLI.SKU
         HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0

         IF @nToCnt > 1
         BEGIN
            SET @nErrNo = 225411
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LocNotCommgSKU'
            GOTO Fail
         END

         IF (@nFromCnt  = 1 AND @nToCnt = 1)
         BEGIN
            SELECT DISTINCT @cFromSKU = LLI.SKU
            FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE LLI.StorerKey = @cStorerKey
            AND LLI.LOC = @cFromLOC
            AND LLI.ID  = CASE WHEN @cFromID  IS NULL THEN LLI.ID  ELSE @cFromID  END
            AND LLI.LOT = CASE WHEN @cFromLOT IS NULL THEN LLI.LOT ELSE @cFromLOT END
            AND LLI.SKU = CASE WHEN @cSKU     IS NULL THEN LLI.SKU ELSE @cSKU     END -- Move by SKU
            AND LLI.LOT = CASE WHEN @cUCC     IS NULL THEN LLI.LOT ELSE @cUCCLOT  END -- Move by UCC (already got LOT,LOC,ID)
            GROUP BY LLI.Storerkey, LLI.SKU,  LLI.ID, LLI.LOT
            HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0

            SELECT DISTINCT @cToSKU = LLI.SKU
            FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE LLI.StorerKey = @cStorerKey
            AND LLI.LOC = @cToLOC
            GROUP BY LLI.Storerkey, LLI.SKU
            HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0

            IF RTRIM(@cFromSKU) <> RTRIM(@cToSKU)
            BEGIN
               SET @nErrNo = 225412
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LocNotCommgSKU'
               GOTO Fail
            END
       END
    END -- If exists commingle
   END -- if exists storerconfig
END

   -- Validate FromID (optional)
   IF @cFromID IS NOT NULL
   BEGIN
      -- Get ID
      SELECT @nRowCount = COUNT( DISTINCT LOC)
      FROM dbo.LOTxLOCxID (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC
         AND ID = @cFromID

      -- Validate ID
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 225413
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid ID'
         GOTO Fail
      END
   END

   -- Validate both SKU and UCC passed-in
   IF @cSKU IS NOT NULL AND @cUCC IS NOT NULL
   BEGIN
      SET @nErrNo = 225414
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Either SKU/UCC'
      GOTO Fail
   END

   -- Validate SKU (optional)
   IF @cSKU IS NOT NULL
   BEGIN
      IF NOT EXISTS( SELECT 1
 FROM dbo.SKU SKU (NOLOCK)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU)
      BEGIN
         SET @nErrNo = 225415
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Fail
      END

      IF @cFromID IS NULL
      BEGIN
         SELECT @nRowCount = COUNT( DISTINCT ID)
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND SKU = @cSKU
         IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 225416
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOCHasMultiID'
            GOTO Fail
         END
      END

      -- Validate QTY
      IF RDT.rdtIsValidQTY( @nQTY, 1) = 0
      BEGIN
         SET @nErrNo = 225417
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         GOTO Fail
      END
   END

   -- Validate UCC (optional)
   IF @cUCC IS NOT NULL
   BEGIN
      IF @cStorerConfig_UCC <> '1'
      BEGIN
         SET @nErrNo = 225418
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCTrackingOff'
         GOTO Fail
      END

      -- Validate UCC
      SET @cUCCStatus = ''
      IF @cToLoc = 'PICK'
      BEGIN
         SET  @cUCCStatus = '5'
      END
      ELSE
      BEGIN
         SET  @cUCCStatus = '6'
      END

      EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT,
         @cUCC,
         @cStorerKey,
         @cUCCStatus ,
         @nChkQTY = 1,
         @cChkLOC = @cFromLOC,
         @cChkID  = @cFromID -- If @cFromID IS NULL, no checking on ID

      IF @nErrNo <> 0
         GOTO Fail

      -- Get UCC SKU, LOT, LOC, ID, QTY
      SELECT
         @cUCCSKU = SKU,
         @cUCCLOT = LOT,
         @cLOC = LOC,
         @cID  = ID,
         @nQTY = QTY
      FROM dbo.UCC (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC
         AND Status = CASE WHEN @cToLoc = 'PICK' THEN '5' ELSE '6' END
--         AND Status = '6'
--         AND Status = '4'


      SET @cSKU = @cUCCSKU
      SET @cFromLOT = @cUCCLOT
      SET @cFromLOC = @cLOC
      SET @cFromID = @cID

      IF @cFromID IS NULL
         SET @cFromID = @cID

      IF @cFromID <> @cID
      BEGIN
         SET @nErrNo = 225419
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCID Unmatch'
         GOTO Fail
      END

      IF @cFromLOT IS NOT NULL AND @cFromLOT <> @cUCCLOT
      BEGIN
         SET @nErrNo = 225420
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCLOT Unmatch'
         GOTO Fail
      END
   END

   -- Validate QTY
   IF @cSKU IS NULL AND @cUCC IS NULL AND @nQTY <> 0
   BEGIN
      SET @nErrNo = 225421
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad QTY Param'
      GOTO Fail
   END

   -- Validate LOT
   IF @cFromLOT IS NOT NULL AND @cFromLOT = ''
   BEGIN
      SET @nErrNo = 225422
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOT'
      GOTO Fail
   END

   -- Validate Inventory
   IF @cToLoc <> 'PICK'
   BEGIN
      IF NOT EXISTS (SELECT 1
      FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LOTxLOCxID.LOC)
      JOIN dbo.LOT LOT WITH (NOLOCK) ON (LOT.LOT = LOTxLOCxID.LOT)
      JOIN dbo.ID  ID WITH (NOLOCK) ON (ID.ID = LOTxLOCxID.ID)
      JOIN dbo.REPLENISHMENT RP WITH (NOLOCK)
         ON (RP.LOT = LOTxLOCxID.LOT AND RP.FromLOC = LOTxLOCxID.LOC AND RP.ID = LOTxLOCxID.ID)
      WHERE RP.REPLENISHMENTKEY = @cReplenKey
      AND   LOC.LocationFlag <> 'HOLD'
      AND   LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'
      AND   (LOTxLOCxID.Qty -
            CASE WHEN @cMoveQTYAlloc = '0' THEN LOTxLOCxID.QTYAllocated ELSE 0 END -
            CASE WHEN @cMoveQTYPick = '0' THEN LOTxLOCxID.QtyPicked ELSE 0 END)
            >= RP.Qty)
      BEGIN
         SET @nErrNo = 225430
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InventNotEnuf'
         GOTO Fail
      END
   END

   DECLARE
      @cOriginalToLoc  NVARCHAR(10),
      @cReplSku        NVARCHAR(20),
      @cReplLot        NVARCHAR(10),
      @nReplQty        INT

   SELECT 
      @cOriginalToLoc = ToLoc,
      @cReplSku = Sku,
      @cReplLot = Lot,
      @nReplQty = Qty
   FROM dbo.Replenishment WITH (NOLOCK)
   WHERE RefNo = @cUCC
      AND StorerKey = @cStorerKey
   /*-------------------------------------------------------------------------------

                                      Actual move

   -------------------------------------------------------------------------------*/

   BEGIN TRAN
   SAVE TRAN Replen_Move

   -- if the original location is overwritten, need unlock the original location
   IF @cOriginalToLoc IS NOT NULL AND TRIM(@cOriginalToLoc) <> '' AND @cOriginalToLoc <> @cToLOC
   BEGIN

      UPDATE dbo.LotxLocxID WITH (ROWLOCK) 
         SET PendingMoveIn = CASE WHEN PendingMoveIn - @nReplQty >= 0 THEN PendingMoveIn - @nReplQty ELSE 0 END  
      WHERE Lot = @cReplLot
         AND Loc = @cOriginalToLoc
         AND ID  = @cID
         AND Sku = @cReplSku

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 225433
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UnlockLocFail'
         GOTO Fail
      END
   END

   IF @cToLoc <> 'PICK'
   BEGIN
      IF @cMoveQTYAlloc > 0
         SELECT @nQtyAlloc = ISNULL(SUM(A.QTY),0)
         FROM dbo.PICKDETAIL A WITH (NOLOCK)
         JOIN dbo.REPLENISHMENT B WITH (NOLOCK) ON A.DROPID = B.DROPID
         WHERE B.REPLENISHMENTKEY = @cReplenKey
           AND   A.storerkey = @cStorerKey
           AND   A.STATUS = '0'

      SET @nErrNo = 0
      EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode,
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
            @cSourceType = 'rdt_941ReplenMove03',
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility,
            @cFromLOC    = @cFromLOC,
            @cToLOC      = @cToLOC,
            @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
            @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
            @cSKU        = @cSKU,
            @nQTY        = @nQTY,
            @cFromLOT    = @cFromLOT,        -- Chee02
            @nFunc       = @nFunc,
            @nQTYAlloc   = @nQTYAlloc,
            @nQTYPick    = 0,
            @cDropID   = @cUCC

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 225423
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ItrnMovefailed'
         GOTO Fail
      END

      SET @curUpdPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PickDetailKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.REPLENISHMENT RPL WITH (NOLOCK) ON ( PD.DropID = RPL.REFNO)
      WHERE PD.Storerkey = @cStorerKey
      AND   PD.[Status] = '0'
      AND   RPL.ReplenishmentKey = @cReplenKey

      OPEN @curUpdPD
      FETCH NEXT FROM @curUpdPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
       UPDATE dbo.PickDetail SET
          DropID = '',
          EditWho = SUSER_SNAME(),
          EditDate = GETDATE()
       WHERE PickDetailKey = @cPickDetailKey

       IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 225432
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PDDtl Err'
            GOTO Fail
         END

       FETCH NEXT FROM @curUpdPD INTO @cPickDetailKey
      END
   END

   IF ISNULL(@cUCC, '') <> ''
   BEGIN -- update ucc
      UPDATE dbo.UCC WITH (ROWLOCK) SET
      Status = CASE WHEN @cToLoc <> 'PICK' THEN '6' ELSE Status END,
         Loc = @ctoloc,
         EditDate = getdate(),
         EditWho = sUSER_sNAME()
      WHERE uccno = @cUCC
      AND   loc = @cfromloc
      AND   sku = @csku
      AND   storerkey = @cstorerkey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 225424
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD UCC Failed'
         GOTO Fail
      END
   END -- update ucc

   UPDATE dbo.REPLENISHMENT WITH (ROWLOCK) SET
      ToLOC       = @cToLOC  -- james02
      ,Confirmed  = 'Y'
      ,ArchiveCop = NULL
      ,EditDate   = GetDate()    -- tlting01
      ,EditWho    = SUser_SName()
   WHERE ReplenishmentKey = @cReplenKey

   IF @@ERROR <> 0
   BEGIN
      ROLLBACK TRAN

      SET @nErrNo = 225425
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RPL Fail  
      GOTO Fail
   END

   SELECT @cLocationType = LocationType
   FROM dbo.Loc WITH (NOLOCK)
   WHERE LOC = @cToLOC

   COMMIT TRAN Replen_Move

Fail:
Quit:

GO