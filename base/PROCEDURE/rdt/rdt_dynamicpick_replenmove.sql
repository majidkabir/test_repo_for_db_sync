SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_ReplenMove                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Replenishment Move                                      */
/*          SOS85866 - Dynamic Pick Replenishment To                    */
/*          SOS87946 - UCC Dynamic Pick Replenishment To                */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2007-09-25 1.0  jwong    Created                                     */
/* 2008-08-14 1.1  jwong    add order by orderkey to make allocation    */
/*                          based on orderkey (james01)                 */
/* 2008-09-04 1.2  jwong    Add update ToLOC during confirm             */
/*                          replenishment (james02)                     */
/* 2008-10-29 1.3  jwong    Stamp UCC to AltSKU when update pickdetail  */
/* 2010-07-07 1.4  TLTING   Update Replenish edit date (tlting01)       */
/* 2013-07-09 1.5  ChewKP   SOS#281897 - TBL Enhancement (ChewKP01)     */
/* 2014-08-05 1.6  Leong    SOS#317542 - Include Order status check.    */
/* 2015-03-16 1.7  Ung      Preparation for L5-L16                      */
/* 2015-06-03 1.8  ChewKP   SOS#343057 - Include diff Confikey for      */
/*                          Manifest Printing (ChewKP02)                */
/* 2018-01-16 1.9  ChewKP   WMS-3767-Call rdt.rdtPrintJob (ChewKP02)    */
/* 2020-07-10 2.0  James    WMS-14147 Add replen customsp logic(james03)*/
/* 2023-07-26 2.1  James    WMS-22615 Fix wrong param seq (james04)     */
/*                          Add UCC_RowRef as new parameters            */
/* 2023-10-05 2.2  Michael  1. Fix duplicated CARTONLBL&CTNMNFEST labels*/
/*                             printed for MultiUCC (ML01)              */
/*                          2. Fix wrong FromLOT get from MultiUCC(ML02)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_DynamicPick_ReplenMove] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nErrNo      INT          OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max
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
   @c_WaveKey   NVARCHAR( 10),
   @cReplenKey  NVARCHAR( 10),
   @cLottable02 NVARCHAR( 18),
   @nUCC_RowRef INT = 0
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
      ,@c_PickDetailKey    NVARCHAR( 10)
      ,@cStorerConfig_UCC  NVARCHAR( 1)
      ,@c_PickHeaderKey    NVARCHAR( 10)
      ,@c_OrderKey    NVARCHAR( 10)
      ,@c_OrderLineNo NVARCHAR( 5)
      ,@c_UOM         NVARCHAR(10)
      ,@c_PackKey     NVARCHAR(10)
      ,@c_errmsg      NVARCHAR( 250)
      ,@cLocationType NVARCHAR( 10)
      ,@b_Success     INT
      ,@n_err         INT
      ,@nRowCount     INT
      ,@nCnt          INT
      ,@n_OrdAvailQTY INT
      ,@n_UOMQTY      INT
      ,@cRetrieveDynamicPickslipNo NVARCHAR( 30)
      ,@cPrintLabel   NVARCHAR(3)     -- (ChewKP01) (ChewKP02)
      ,@cPrinter      NVARCHAR( 10)   -- (ChewKP01)
      ,@nCartonNo     INT             -- (ChewKP01)
      ,@cPickSlipNo   NVARCHAR( 10)   -- (ChewKP01)
      ,@cDataWindow   NVARCHAR( 50)   -- (ChewKP01)
      ,@cTargetDB     NVARCHAR( 10)   -- (ChewKP01)
      ,@cLabelNo      NVARCHAR( 20)   -- (ChewKP01)
      ,@cUCCStatus    NVARCHAR(  5)   -- (ChewKP01)
      ,@nQtyInPickLoc INT             -- (ChewKP01)
      ,@cLottable01   NVARCHAR( 18)
      ,@cLottable03   NVARCHAR( 18)
      ,@dLottable04   DATETIME

   DECLARE @cSQLStatement   NVARCHAR(2000),
           @cSQLParms       NVARCHAR(2000)

   SET @nErrNo = 0

   -- Get extended ExtendedPltBuildCfmSP
   DECLARE @cExtendedReplenCfmSP NVARCHAR(20)
   SET @cExtendedReplenCfmSP = rdt.rdtGetConfig( @nFunc, 'ExtendedReplenCfmSP', @cStorerKey)
   IF @cExtendedReplenCfmSP = '0'
      SET @cExtendedReplenCfmSP = ''

   -- Extended putaway
   IF @cExtendedReplenCfmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedReplenCfmSP AND type = 'P')
      BEGIN
         SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cExtendedReplenCfmSP) +
            ' @nMobile, @nFunc, @cLangCode, @cSourceType, @cStorerKey, @cFacility, ' +
            ' @cFromLOC, @cToLOC, @cFromID, @cToID, @cSKU, @cUCC, @nQTY, @cFromLOT, @cWaveKey, @cReplenKey, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nUCC_RowRef'
         SET @cSQLParms =
            '@nMobile         INT,                  ' +
            '@nFunc           INT,                  ' +
            '@cLangCode       NVARCHAR( 3),         ' +
            '@cSourceType     NVARCHAR( 30),        ' +
            '@cStorerKey      NVARCHAR( 15),        ' +
            '@cFacility       NVARCHAR( 5),         ' +
            '@cFromLOC        NVARCHAR( 10),        ' +
            '@cToLOC          NVARCHAR( 10),        ' +
            '@cFromID         NVARCHAR( 18) = NULL, ' + -- NULL means not filter by ID. Blank ID is a valid ID
            '@cToID           NVARCHAR( 18) = NULL, ' + -- NULL means not changing ID. Blank ID is a valid ID
            '@cSKU            NVARCHAR( 20) = NULL, ' + -- Either SKU or UCC only
            '@cUCC            NVARCHAR( 20) = NULL, ' + -- Either SKU or UCC only
            '@nQTY            INT       = 0,        ' + -- For move by SKU, QTY must have value
            '@cFromLOT        NVARCHAR( 10) = NULL, ' + -- Applicable for all 6 types of move
            '@cWaveKey        NVARCHAR( 10),        ' +
            '@cReplenKey      NVARCHAR( 10),        ' +
            '@cLottable01     NVARCHAR( 18),        ' +
            '@cLottable02     NVARCHAR( 18),        ' +
            '@cLottable03     NVARCHAR( 18),        ' +
            '@dLottable04     DATETIME,             ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
            '@nUCC_RowRef     INT '

         EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,
            @nMobile, @nFunc, @cLangCode, @cSourceType, @cStorerKey, @cFacility,
            @cFromLOC, @cToLOC, @cFromID, @cToID, @cSKU, @cUCC, @nQTY, @cFromLOT, @c_WaveKey, @cReplenKey,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nUCC_RowRef

         GOTO Quit
      END
   END

   -- Get StorerConfig 'UCCTracking'
   SET @cStorerConfig_UCC = '0' -- Default Off
   SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
   FROM dbo.StorerConfig (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ConfigKey = 'UCC'


/*-------------------------------------------------------------------------------

                                 Validate parameters

-------------------------------------------------------------------------------*/
   -- Validate StorerKey (compulsory)
   IF @cStorerKey = '' OR @cStorerKey IS NULL
   BEGIN
      SET @nErrNo = 64301
      SET @cErrMsg = rdt.rdtgetmessage( 64301, @cLangCode, 'DSP') --'Need StorerKey'
      GOTO Fail
   END

   -- Validate Facility (compulsory)
   IF @cFacility = '' OR @cFacility IS NULL
   BEGIN
      SET @nErrNo = 64302
      SET @cErrMsg = rdt.rdtgetmessage( 64302, @cLangCode, 'DSP') --'Need Facility'
      GOTO Fail
   END

   -- Validate SourceType (compulsory)
   IF @cSourceType IS NULL
   BEGIN
      SET @nErrNo = 64303
      SET @cErrMsg = rdt.rdtgetmessage( 64303, @cLangCode, 'DSP') --'Bad SourceType'
      GOTO Fail
   END

   -- Validate FromLOC (compulsory)
   IF @cFromLOC = '' OR @cFromLOC IS NULL
   BEGIN
      SET @nErrNo = 64304
      SET @cErrMsg = rdt.rdtgetmessage( 64304, @cLangCode, 'DSP') --'FromLOC needed'
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
         SET @nErrNo = 64305
         SET @cErrMsg = rdt.rdtgetmessage( 64305, @cLangCode, 'DSP') --'Bad FromLOC'
         GOTO Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 64306
         SET @cErrMsg = rdt.rdtgetmessage( 64306, @cLangCode, 'DSP') --'Diff facility'
         GOTO Fail
      END
   END

   -- Validate ToLOC (compulsory)
   IF @cToLOC = '' OR @cToLOC IS NULL
   BEGIN
      SET @nErrNo = 64307
      SET @cErrMsg = rdt.rdtgetmessage( 64307, @cLangCode, 'DSP') --'ToLOC needed'
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
      --IF @@ROWCOUNT = 0 -- (ChewKP01)
      IF @cToLoc <> 'PICK'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)
                         WHERE Loc = @cToLoc )
         BEGIN
            SET @nErrNo = 64308
            SET @cErrMsg = rdt.rdtgetmessage( 64308, @cLangCode, 'DSP') --'Bad ToLOC'
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
          SET @nErrNo = 64309
          SET @cErrMsg = rdt.rdtgetmessage( 64309, @cLangCode, 'DSP') --'Diff facility'
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
            SET @nErrNo = 64310
            SET @cErrMsg = rdt.rdtgetmessage(64310, @cLangCode, 'DSP') -- 'LocNotCommgSKU'
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
            SET @nErrNo = 64311
            SET @cErrMsg = rdt.rdtgetmessage(64311, @cLangCode, 'DSP') -- 'LocNotCommgSKU'
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
               SET @nErrNo = 64312
               SET @cErrMsg = rdt.rdtgetmessage(64312, @cLangCode, 'DSP') -- 'LocNotCommgSKU'
               GOTO Fail
            END
       END
    END -- If exists commingle
   END -- if exists storerconfig
   -- SOS#77266 - Rewrite
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
         SET @nErrNo = 64313
         SET @cErrMsg = rdt.rdtgetmessage( 64313, @cLangCode, 'DSP') --'Invalid ID'
         GOTO Fail
      END

      -- Validate ID in multi LOC
   /*
      IF @nRowCount > 1
      BEGIN
         SET @nErrNo = 60511
         SET @cErrMsg = rdt.rdtgetmessage( 60511, @cLangCode, 'DSP') --'ID in MultiLOC'
         GOTO Fail
      END
   */
   END

   -- Validate both SKU and UCC passed-in
   IF @cSKU IS NOT NULL AND @cUCC IS NOT NULL
   BEGIN
      SET @nErrNo = 64314
      SET @cErrMsg = rdt.rdtgetmessage( 64314, @cLangCode, 'DSP') --'Either SKU/UCC'
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
         SET @nErrNo = 64315
         SET @cErrMsg = rdt.rdtgetmessage( 64315, @cLangCode, 'DSP') --'Invalid SKU'
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
            SET @nErrNo = 64316
            SET @cErrMsg = rdt.rdtgetmessage( 64316, @cLangCode, 'DSP') --'LOCHasMultiID'
            GOTO Fail
         END
      END

      -- Validate QTY
      IF RDT.rdtIsValidQTY( @nQTY, 1) = 0
      BEGIN
         SET @nErrNo = 64317
         SET @cErrMsg = rdt.rdtgetmessage( 64317, @cLangCode, 'DSP') --'Invalid QTY'
         GOTO Fail
      END
   END

   -- Validate UCC (optional)
   IF @cUCC IS NOT NULL
   BEGIN
      IF @cStorerConfig_UCC <> '1'
      BEGIN
         SET @nErrNo = 64318
         SET @cErrMsg = rdt.rdtgetmessage( 64318, @cLangCode, 'DSP') --'UCCTrackingOff'
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
--         '6', -- Status
--       Changed from 6 to 4 coz loadplan allocation only exclude for ucc.status in ('3', '4')
         @cUCCStatus , -- Status -- (ChewKP01)
         @nChkQTY = 1,
         @cChkLOC = @cFromLOC,
         @cChkID  = @cFromID -- If @cFromID IS NULL, no checking on ID

      IF @nErrNo <> 0
         GOTO Fail

      -- Get UCC SKU, LOT, LOC, ID, QTY
      SELECT
         @cUCCSKU = UCC.SKU,
         @cUCCLOT = UCC.LOT,
         @cLOC = UCC.LOC,
         @cID  = UCC.ID,
         @nQTY = UCC.QTY
      FROM dbo.UCC UCC(NOLOCK)
      LEFT JOIN dbo.REPLENISHMENT RP(NOLOCK) on UCC.Lot=RP.Lot and UCC.Loc=RP.FromLoc and UCC.ID=RP.ID AND UCC.UCCNo=RP.RefNo AND RP.Replenishmentkey=@cReplenKey    --(ML02)
      WHERE UCC.StorerKey = @cStorerKey
         AND UCC.UCCNo = @cUCC
         AND UCC.Status = CASE WHEN @cToLoc = 'PICK' THEN '5' ELSE '6' END
--         AND Status = '6'
--         AND Status = '4'
      ORDER BY CASE WHEN RP.Replenishmentkey IS NULL THEN 1 ELSE 2 END    --(ML02)


      SET @cSKU = @cUCCSKU
      SET @cFromLOT = @cUCCLOT
      SET @cFromLOC = @cLOC
      SET @cFromID = @cID

      IF @cFromID IS NULL
         SET @cFromID = @cID

      IF @cFromID <> @cID
      BEGIN
         SET @nErrNo = 64319
         SET @cErrMsg = rdt.rdtgetmessage( 64319, @cLangCode, 'DSP') --'UCCID Unmatch'
         GOTO Fail
      END

      IF @cFromLOT IS NOT NULL AND @cFromLOT <> @cUCCLOT
      BEGIN
         SET @nErrNo = 64320
         SET @cErrMsg = rdt.rdtgetmessage( 64320, @cLangCode, 'DSP') --'UCCLOT Unmatch'
         GOTO Fail
      END
   END

   -- Validate QTY
   IF @cSKU IS NULL AND @cUCC IS NULL AND @nQTY <> 0
   BEGIN
      SET @nErrNo = 64321
      SET @cErrMsg = rdt.rdtgetmessage( 64321, @cLangCode, 'DSP') --'Bad QTY Param'
      GOTO Fail
   END

   -- Validate LOT
   IF @cFromLOT IS NOT NULL AND @cFromLOT = ''
   BEGIN
      SET @nErrNo = 64322
      SET @cErrMsg = rdt.rdtgetmessage( 64322, @cLangCode, 'DSP') --'Invalid LOT'
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
      AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) >= RP.Qty)
      BEGIN
         SET @nErrNo = 64330
         SET @cErrMsg = rdt.rdtgetmessage( 64330, @cLangCode, 'DSP') --'InventNotEnuf'
         GOTO Fail
      END
   END

   /*-------------------------------------------------------------------------------

                                      Actual move

   -------------------------------------------------------------------------------*/

   BEGIN TRAN
   SAVE TRAN Replen_Move

   IF @cToLoc <> 'PICK'
   BEGIN
      EXECUTE dbo.nspItrnAddMove
         @n_ItrnSysId     = NULL,
         @c_StorerKey     = @cstorerkey,
         @c_Sku           = @csku,
         @c_Lot           = @cFromLOT,
         @c_FromLoc       = @cfromloc,
         @c_FromID        = @cFromID,
         @c_ToLoc         = @cToLOC,
         @c_ToID          = @cFromID,
         @c_Status        = 'OK',
         @c_lottable01    = '',
         @c_lottable02    = '',
         @c_lottable03    = '',
         @d_lottable04    = NULL,
         @d_lottable05    = NULL,
         @n_casecnt       = 0,
         @n_innerpack     = 0,
         @n_qty           = @nQTY,
         @n_pallet        = 0,
         @f_cube          = 0,
         @f_grosswgt      = 0,
         @f_netwgt        = 0,
         @f_otherunit1    = 0,
         @f_otherunit2    = 0,
         @c_SourceKey     = @cReplenKey,
         @c_SourceType    = @cSourceType,
         @c_PackKey       = '',
         @c_UOM           = '',
         @b_UOMCalc       = 1,
         @d_EffectiveDate = NULL,
         @c_itrnkey       = '',
         @b_Success       = @b_Success  OUTPUT,
         @n_err           = @n_err      OUTPUT,
         @c_errmsg        = @c_errmsg   OUTPUT

      IF NOT @b_success = 1
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 64323
         SET @cErrMsg = rdt.rdtgetmessage( 64323, @cLangCode, 'DSP') --'ItrnMovefailed'
         GOTO Fail
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
         SET @nErrNo = 64324
         SET @cErrMsg = rdt.rdtgetmessage( 64324, @cLangCode, 'DSP') --'UPD UCC Failed'
         GOTO Fail
      END
   END -- update ucc

--   IF @cFromLoc = @cToLoc
--   BEGIN
      -- Update replen task with confirmed = 'Y' & ToLOC = suggested ToLOC
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

         SET @nErrNo = 64325
         SET @cErrMsg = rdt.rdtgetmessage( 64325, @cLangCode, 'DSP') --UPD RPL Fail
         GOTO Fail
      END
--   END
--   ELSE
--   BEGIN
--      -- Update replen task with confirmed = 'Y' & ToLOC = suggested ToLOC
--      UPDATE dbo.REPLENISHMENT WITH (ROWLOCK) SET
--         Confirmed = 'Y'
--         ,ToLOC = @cToLoc
--         ,ArchiveCop = NULL
--         ,EditDate   = GetDate()       -- tlting01
--         ,EditWho    = SUser_SName()
--      WHERE ReplenishmentKey = @cReplenKey
--
--      IF @@ERROR <> 0
--      BEGIN
--         ROLLBACK TRAN
--
--         SET @nErrNo = 64326
--         SET @cErrMsg = rdt.rdtgetmessage( 64326, @cLangCode, 'DSP') --UPD RPL Fail
--         GOTO Fail
--      END
--   END

   SELECT @cLocationType = LocationType
   FROM dbo.Loc WITH (NOLOCK)
   WHERE LOC = @cToLOC

   IF @cLocationType = 'DYNAMICPK' OR @cLocationType = 'CASE' -- Exclude FCP & Bulk To PP. FCP already allocated & Bulk To PP can be excluded
   BEGIN
      SET @nQtyInPickLoc = 0
      SELECT @nQtyInPickLoc = ISNULL(QtyInPickLoc, 0)
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE ReplenishmentKey = @cReplenKey

      IF @nQtyInPickLoc > 0
      BEGIN
         SET @nQTY = @nQtyInPickLoc
      END

   -- Start offset
      WHILE @nQTY > 0
      BEGIN
         SELECT
            @c_OrderKey    = OD.OrderKey,
            @c_OrderLineNo = OD.OrderLineNumber,
            @n_OrdAvailQTY = OD.OpenQty - OD.QtyAllocated - OD.QtyPicked,
            @c_UOM         = CASE OD.UOM WHEN P.PACKUOM1 THEN '2'
               WHEN P.PACKUOM2 THEN '3'
               WHEN P.PACKUOM3 THEN '6'
               WHEN P.PACKUOM4 THEN '1'
               END,
            @n_UOMQTY      = CASE OD.UOM WHEN P.PACKUOM1 THEN ABS((OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) /P.CaseCnt)
               WHEN P.PACKUOM2 THEN ABS((OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) /P.InnerPack)
               WHEN P.PACKUOM3 THEN (OD.OpenQty - OD.QtyAllocated - OD.QtyPicked)
               WHEN P.PACKUOM4 THEN ABS((OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) /P.Pallet)
               END,
            @c_PackKey     = OD.Packkey
         FROM dbo.WaveDetail WD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (WD.Orderkey = OD.Orderkey)
         JOIN dbo.Pack P WITH(NOLOCK) ON (OD.Packkey  = P.Packkey)
         JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey) -- SOS#317542
         WHERE  OD.Storerkey = @cStorerKey
            AND OD.OpenQty - OD.QtyAllocated - OD.QtyPicked > 0
            AND OD.SKU = @cSKU
            AND 1 = CASE WHEN OD.Lottable02 = '' THEN 1
                         WHEN OD.Lottable02 = @cLottable02 THEN 1
                    ELSE 0 END
            AND WD.WaveKey = @c_WaveKey
            AND (O.Status NOT IN ('9','CANC') OR O.SOStatus NOT IN ('9','CANC')) -- SOS#317542
         ORDER BY WD.WaveKey,
            OD.OrderKey DESC-- to make allocation based on orderkey (james01)

         IF @@ROWCOUNT = 0
         BEGIN
            -- (ChewKP01)
            IF @cLocationType = 'DYNAMICPK'
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 64331
               SET @cErrMsg = rdt.rdtgetmessage( 64331, @cLangCode, 'DSP') --NoOrDtlOffset
               GOTO Fail
            END
            ELSE IF @cLocationType = 'CASE'
            BEGIN
               BREAK
            END
         END

         IF @nQTY < @n_OrdAvailQTY
            SET @n_OrdAvailQTY = @nQTY

         SET @b_success = 0
         EXECUTE dbo.nspg_getkey
            'PICKDETAILKEY' ,
            10 ,
            @c_PickDetailKey   Output ,
            @b_success      = @b_success Output,
            @n_err          = @n_err Output,
            @c_errmsg       = @c_errmsg Output

         IF @b_success <> 1
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 64327
            SET @cErrMsg = rdt.rdtgetmessage( 64327, @cLangCode, 'DSP') --GetPDKeyFail
            GOTO Fail
         END

         INSERT INTO dbo.PICKDETAIL( Pickdetailkey, Caseid, PickHeaderKey, Orderkey, OrderlineNumber, Storerkey, Sku, UOM,
         UOMQty, Packkey, Lot, Loc, ID, Qty, Wavekey, PickSlipNo, CartonType, ALTSKU)
         VALUES
         ( @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNo, @cStorerKey, @cSKU, @c_UOM,
         @n_UOMQTY, @c_PackKey, @cFromLot, @cToLoc, CASE WHEN @cLoseID = '1' THEN '' ELSE @cFromid END
         , @n_OrdAvailQTY, @c_WaveKey, NULL, 'REPLEN', ISNULL(@cUCC, ''))

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 64328
            SET @cErrMsg = rdt.rdtgetmessage( 64327, @cLangCode, 'DSP') --CreatePKDFail
            GOTO Fail
         END

         -- 2) Get PickSlipNo
         SELECT @cRetrieveDynamicPickslipNo = rdt.RDTGetConfig( @nFunc, 'RetrieveDynamicPickslipNo', @cStorerKey)

         IF EXISTS (SELECT 1 FROM sysobjects WHERE name = RTRIM(@cRetrieveDynamicPickslipNo) AND type = 'P')
         BEGIN
            SET @cRetrieveDynamicPickslipNo = 'RDT.' + LTRIM(@cRetrieveDynamicPickslipNo)
            SET @cSQLStatement = N'EXEC ' + RTRIM(@cRetrieveDynamicPickslipNo) +
                ' @c_WaveKey, @c_OrderKey, @c_PickDetailKey, @c_PickHeaderKey OUTPUT'

            SET @cSQLParms = N'@c_Wavekey        NVARCHAR( 10),    ' +
                              '@c_OrderKey       NVARCHAR( 10),  ' +
                              '@c_PickDetailKey  NVARCHAR( 10),  ' +
                              '@c_PickHeaderKey  NVARCHAR( 10) OUTPUT '


            EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,
                   @c_Wavekey
                  ,@c_OrderKey
                  ,@c_PickDetailKey
                  ,@c_PickHeaderKey OUTPUT

            -- Stamp pickslip no
            IF @c_PickHeaderKey <> ''
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  PickSlipNo = @c_PickHeaderKey,
                  TrafficCop = NULL,
                  AltSKU = ISNULL(@cUCC, '')
               WHERE PickDetailKey = @c_PickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN

                  SET @nErrNo = 64328
                  SET @cErrMsg = rdt.rdtgetmessage( 64328, @cLangCode, 'DSP') --UPD PKD Fail
                  GOTO Fail
               END
            END
         END   -- End for if exists

         IF @nQTY > @n_OrdAvailQTY
         BEGIN
            SET @nQTY = @nQTY - @n_OrdAvailQTY
         END
         ELSE
         BEGIN
            BREAK
         END
      END   -- End for While @nQTY > 0
   END   -- Locationtype
   ELSE -- Print Label for FCP Replenishment
   IF @nUCC_RowRef = 0 OR @nUCC_RowRef = (SELECT MIN(UCC_RowRef) FROM dbo.UCC (NOLOCK) WHERE UCCNo=@cUCC)     -- (ML01)
   BEGIN
         -- (ChewKP01)
         -- (ChewKP02)
         -- 1 = Print Carton Label and Manifest
         -- C = Print Carton Label
         -- M = Print Manifest
         SET @cPrintLabel = ''
         SET @cPrintLabel = rdt.RDTGetConfig( @nFunc, 'PrintLabel', @cStorerKey)
         IF @cPrintLabel = '0'
            SET @cPrintLabel = ''


         SELECT @cPrinter = Printer
         FROM rdt.rdtMobrec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         IF CHARINDEX ('1', RTRIM(@cPrintLabel)) <> 0  OR CHARINDEX ('C', RTRIM(@cPrintLabel)) <> 0 -- (ChewKP02)
         BEGIN
            IF ISNULL(@cPrinter, '') <> ''
            BEGIN
               SET @cDataWindow = ''
               SET @cTargetDB = ''
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')
               FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND ReportType = 'CARTONLBL'

               IF ISNULL(@cDataWindow, '') = ''
               BEGIN
                  SET @nErrNo = 64332
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
                  ROLLBACK TRAN
                  GOTO Fail
               END

               IF ISNULL(@cTargetDB, '') = ''
               BEGIN
                  SET @nErrNo = 64333
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
                  ROLLBACK TRAN
                  GOTO Fail
               END

               --get pickSlipNo, CartonNo
               SET @cLabelNo = ''
               SET @nCartonNo = 0
               SET @cPickSlipNo = ''

               SELECT @nCartonNo   = CartonNo,
                      @cPickSlipNo = PickSlipNo,
                      @cLabelNo = Labelno
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   RefNo = @cUCC

               -- (ChewKP02)
               -- Call printing spooler
               --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Parm4, Parm5, Printer, NoOfCopy, Mobile, TargetDB)
               --VALUES('PRINTCARTONLBL', 'CARTONLBL', '0', @cDataWindow, 5, @cPickSlipNo, @nCartonNo, @nCartonNo, @cLabelNo, @cLabelNo, @cPrinter, 1, @nMobile, @cTargetDB)


               EXEC RDT.rdt_BuiltPrintJob
                     @nMobile,
                     @cStorerKey,
                     'CARTONLBL',
                     'PRINTCARTONLBL',
                     @cDataWindow,
                     @cPrinter,
                     @cTargetDB,
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     @cPickSlipNo,
                     @nCartonNo,
                     @nCartonNo,
                     @cLabelNo,
                     @cLabelNo

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN

                  SET @nErrNo = 64334
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'
                  ROLLBACK TRAN
                  GOTO Fail
               END

            END
         END

         IF CHARINDEX ('1', RTRIM(@cPrintLabel)) <> 0  OR CHARINDEX ('M', RTRIM(@cPrintLabel)) <> 0 -- (ChewKP02)
         BEGIN
            SET @cDataWindow = ''
            SET @cTargetDB = ''
            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')
            FROM RDT.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ReportType = 'CTNMNFEST'


            IF ISNULL(@cDataWindow, '') = ''
            BEGIN
               SET @nErrNo = 64336
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
               ROLLBACK TRAN
               GOTO Fail
            END

            IF ISNULL(@cTargetDB, '') = ''
            BEGIN
               SET @nErrNo = 64337
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
               ROLLBACK TRAN
               GOTO Fail
            END

            -- Call printing spooler
            --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Parm4, Parm5, Printer, NoOfCopy, Mobile, TargetDB)
            --VALUES('PRINTCTNMNFEST', 'CTNMNFEST', '0', @cDataWindow, 3, @cPickSlipNo, @cLabelNo, @cLabelNo, '', '', @cPrinter, 1, @nMobile, @cTargetDB)

            EXEC RDT.rdt_BuiltPrintJob
                     @nMobile,
                     @cStorerKey,
                     'CTNMNFEST',
                     'PRINTCTNMNFEST',
                     @cDataWindow,
                     @cPrinter,
                     @cTargetDB,
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     @cPickSlipNo,
                     @cLabelNo,
                     @cLabelNo


            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN

               SET @nErrNo = 64335
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'
               ROLLBACK TRAN
               GOTO Fail
            END
         END



         --print carton label process (end)
   END

   COMMIT TRAN Replen_Move

   Fail:
   Quit:

GO