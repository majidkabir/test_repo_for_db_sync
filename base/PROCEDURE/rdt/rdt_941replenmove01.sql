SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_941ReplenMove01                                 */  
/* Copyright      : Maersk                                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2020-07-10 1.0  James    WMS-14147. Created                          */  
/* 2023-05-31 1.1  James    WMS-22615 Add UCCWithMultiSKU (james01)     */  
/* 2023-10-05 1.2  James    Addhoc Fix duplicated CARTONLBL&CTNMNFEST   */  
/*                          labels printed for MultiUCC (james02)       */  
/************************************************************************/  
  
CREATE    PROC [RDT].[rdt_941ReplenMove01] (  
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
      ,@cPickDetailKey     NVARCHAR( 10)  
      ,@cStorerConfig_UCC  NVARCHAR( 1)  
      ,@cPickHeaderKey    NVARCHAR( 10)  
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
      ,@cLong         NVARCHAR(255)   
      ,@cNotes        NVARCHAR(2000)   
      ,@cLottable06   NVARCHAR( 30)  
  
  
   DECLARE @cSQL            NVARCHAR(MAX),  
           @cSQLParms       NVARCHAR(MAX)  
  
   DECLARE @cUCCWithMultiSKU       NVARCHAR( 1)  
   DECLARE @nDebug         INT = 0  
     
   IF @nDebug = 1  
    SELECT @cFromLOT '@cFromLOT', @cfromloc '@cfromloc', @cFromID '@cFromID', @cToLOC '@cToLOC',   
    @csku '@csku', @nQTY '@nQTY', @cReplenKey '@cReplenKey'     
   SET @nErrNo = 0  
  
   -- Get StorerConfig 'UCCTracking'  
   SET @cStorerConfig_UCC = '0' -- Default Off  
   SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END  
   FROM dbo.StorerConfig (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND ConfigKey = 'UCC'  
  
   SET @cUCCWithMultiSKU = rdt.RDTGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)  
/*-------------------------------------------------------------------------------  
  
                                 Validate parameters  
  
-------------------------------------------------------------------------------*/  
   -- Validate StorerKey (compulsory)  
   IF @cStorerKey = '' OR @cStorerKey IS NULL  
   BEGIN  
      SET @nErrNo = 154751  
      SET @cErrMsg = rdt.rdtgetmessage( 154751, @cLangCode, 'DSP') --'Need StorerKey'  
      GOTO Fail  
   END  
  
   -- Validate Facility (compulsory)  
   IF @cFacility = '' OR @cFacility IS NULL  
   BEGIN  
      SET @nErrNo = 154752  
      SET @cErrMsg = rdt.rdtgetmessage( 154752, @cLangCode, 'DSP') --'Need Facility'  
      GOTO Fail  
   END  
  
   -- Validate SourceType (compulsory)  
   IF @cSourceType IS NULL  
   BEGIN  
      SET @nErrNo = 154753  
      SET @cErrMsg = rdt.rdtgetmessage( 154753, @cLangCode, 'DSP') --'Bad SourceType'  
      GOTO Fail  
   END  
  
   -- Validate FromLOC (compulsory)  
   IF @cFromLOC = '' OR @cFromLOC IS NULL  
   BEGIN  
      SET @nErrNo = 154754  
      SET @cErrMsg = rdt.rdtgetmessage( 154754, @cLangCode, 'DSP') --'FromLOC needed'  
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
         SET @nErrNo = 154755  
         SET @cErrMsg = rdt.rdtgetmessage( 154755, @cLangCode, 'DSP') --'Bad FromLOC'  
         GOTO Fail  
      END  
  
      -- Validate LOC's facility  
      IF @cChkFacility <> @cFacility  
      BEGIN  
         SET @nErrNo = 154756  
         SET @cErrMsg = rdt.rdtgetmessage( 154756, @cLangCode, 'DSP') --'Diff facility'  
         GOTO Fail  
      END  
   END  
  
   -- Validate ToLOC (compulsory)  
   IF @cToLOC = '' OR @cToLOC IS NULL  
   BEGIN  
      SET @nErrNo = 154757  
      SET @cErrMsg = rdt.rdtgetmessage( 154757, @cLangCode, 'DSP') --'ToLOC needed'  
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
            SET @nErrNo = 154758  
            SET @cErrMsg = rdt.rdtgetmessage( 154758, @cLangCode, 'DSP') --'Bad ToLOC'  
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
          SET @nErrNo = 154759  
          SET @cErrMsg = rdt.rdtgetmessage( 154759, @cLangCode, 'DSP') --'Diff facility'  
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
            SET @nErrNo = 154760  
            SET @cErrMsg = rdt.rdtgetmessage(154760, @cLangCode, 'DSP') -- 'LocNotCommgSKU'  
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
            SET @nErrNo = 154761  
            SET @cErrMsg = rdt.rdtgetmessage(154761, @cLangCode, 'DSP') -- 'LocNotCommgSKU'  
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
               SET @nErrNo = 154762  
               SET @cErrMsg = rdt.rdtgetmessage(154762, @cLangCode, 'DSP') -- 'LocNotCommgSKU'  
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
         SET @nErrNo = 154763  
         SET @cErrMsg = rdt.rdtgetmessage( 154763, @cLangCode, 'DSP') --'Invalid ID'  
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
   IF @cSKU IS NOT NULL AND @cUCC IS NOT NULL --AND @cUCCWithMultiSKU <> '1'  
   BEGIN  
      SET @nErrNo = 154764  
      SET @cErrMsg = rdt.rdtgetmessage( 154764, @cLangCode, 'DSP') --'Either SKU/UCC'  
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
         SET @nErrNo = 154765  
         SET @cErrMsg = rdt.rdtgetmessage( 154765, @cLangCode, 'DSP') --'Invalid SKU'  
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
            SET @nErrNo = 154766  
            SET @cErrMsg = rdt.rdtgetmessage( 154766, @cLangCode, 'DSP') --'LOCHasMultiID'  
            GOTO Fail  
         END  
      END  
  
      -- Validate QTY  
      IF RDT.rdtIsValidQTY( @nQTY, 1) = 0  
      BEGIN  
         SET @nErrNo = 154767  
         SET @cErrMsg = rdt.rdtgetmessage( 154767, @cLangCode, 'DSP') --'Invalid QTY'  
         GOTO Fail  
      END  
   END  
  
   -- Validate UCC (optional)  
   IF @cUCC IS NOT NULL  
   BEGIN  
      IF @cStorerConfig_UCC <> '1'  
      BEGIN  
         SET @nErrNo = 154768  
         SET @cErrMsg = rdt.rdtgetmessage( 154768, @cLangCode, 'DSP') --'UCCTrackingOff'  
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
  
      -- (james01)  
      IF @cUCCWithMultiSKU <> '1'  
      BEGIN  
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
      END  
        
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
         AND (( @cToLoc = 'PICK' AND [STATUS] = '5') OR ( @cToLoc <> 'PICK' AND [STATUS] = '6'))  
         --AND (( @cUCCWithMultiSKU = '1' AND SKU = @cSKU) OR ( @cUCCWithMultiSKU <> '1' AND SKU = SKU))    
         AND (( @cFromLOT <> '' AND Lot = @cFromLOT) OR ( @cFromLOT = '' AND Lot = Lot))   
         AND ((@nUCC_RowRef <> '' AND UCC_RowRef = @nUCC_RowRef) OR (@nUCC_RowRef = '' AND UCC_RowRef = UCC_RowRef))  
  
      SET @cSKU = @cUCCSKU  
      SET @cFromLOT = @cUCCLOT  
      SET @cFromLOC = @cLOC  
      SET @cFromID = @cID  
  
      IF @cFromID IS NULL  
         SET @cFromID = @cID  
  
      IF @cFromID <> @cID  
      BEGIN  
         SET @nErrNo = 154769  
         SET @cErrMsg = rdt.rdtgetmessage( 154769, @cLangCode, 'DSP') --'UCCID Unmatch'  
         GOTO Fail  
      END  
  
      IF @cFromLOT IS NOT NULL AND @cFromLOT <> @cUCCLOT  
      BEGIN  
         SET @nErrNo = 154770  
         SET @cErrMsg = rdt.rdtgetmessage( 154770, @cLangCode, 'DSP') --'UCCLOT Unmatch'  
         GOTO Fail  
      END  
   END  
  
   -- Validate QTY  
   IF @cSKU IS NULL AND @cUCC IS NULL AND @nQTY <> 0  
   BEGIN  
      SET @nErrNo = 154771  
      SET @cErrMsg = rdt.rdtgetmessage( 154771, @cLangCode, 'DSP') --'Bad QTY Param'  
      GOTO Fail  
   END  
  
   -- Validate LOT  
   IF @cFromLOT IS NOT NULL AND @cFromLOT = ''  
   BEGIN  
      SET @nErrNo = 154772  
      SET @cErrMsg = rdt.rdtgetmessage( 154772, @cLangCode, 'DSP') --'Invalid LOT'  
      GOTO Fail  
   END  
  
   SELECT @cLottable06 = Lottable06  
   FROM dbo.LOTATTRIBUTE WITH (NOLOCK)  
   WHERE Lot = @cFromLOT  
     
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
         SET @nErrNo = 154780  
         SET @cErrMsg = rdt.rdtgetmessage( 154780, @cLangCode, 'DSP') --'InventNotEnuf'  
         GOTO Fail  
      END  
   END  
  
   /*-------------------------------------------------------------------------------  
  
                                      Actual move  
  
   -------------------------------------------------------------------------------*/  
   DECLARE @nTranCount  INT    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  
   SAVE TRAN Replen_Move  
  
   IF @cToLoc <> 'PICK'  
   BEGIN  
    IF @nDebug = 1  
       SELECT @cFromLOT '@cFromLOT', @cfromloc '@cfromloc', @cFromID '@cFromID', @cToLOC '@cToLOC',   
       @csku '@csku', @nQTY '@nQTY', @cReplenKey '@cReplenKey'   
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
         SET @nErrNo = 154773  
         SET @cErrMsg = rdt.rdtgetmessage( 154773, @cLangCode, 'DSP') --'ItrnMovefailed'  
         GOTO RollBackTran  
      END  
  
   END  
  
   IF ISNULL(@cUCC, '') <> ''  
   BEGIN -- update ucc  
      IF @cUCCWithMultiSKU = '1'  
      BEGIN  
         UPDATE dbo.UCC SET  
         Status = CASE WHEN @cToLoc <> 'PICK' THEN '6' ELSE Status END,  
            Loc = @ctoloc,  
            EditDate = GETDATE(),  
            EditWho = sUSER_sNAME()  
         WHERE UCC_RowRef = @nUCC_RowRef  
  
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SET @nErrNo = 154788  
            SET @cErrMsg = rdt.rdtgetmessage( 154774, @cLangCode, 'DSP') --'UPD UCC Failed'  
            GOTO RollBackTran  
         END  
      END  
      ELSE  
      BEGIN  
         UPDATE dbo.UCC WITH (ROWLOCK) SET  
         Status = CASE WHEN @cToLoc <> 'PICK' THEN '6' ELSE Status END,  
            Loc = @ctoloc,  
            EditDate = GETDATE(),  
            EditWho = sUSER_sNAME()  
         WHERE UCCNo = @cUCC  
         AND   Loc = @cFromLOC  
         AND   SKU = @cSKU  
         AND   Storerkey = @cStorerKey  
         AND   (( @cFromLOT <> '' AND Lot = @cFromLOT) OR ( @cFromLOT = '' AND Lot = Lot))  
  
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SET @nErrNo = 154774  
            SET @cErrMsg = rdt.rdtgetmessage( 154774, @cLangCode, 'DSP') --'UPD UCC Failed'  
            GOTO RollBackTran  
         END  
      END  
   END -- update ucc  
  
   -- Update replen task with confirmed = 'Y' & ToLOC = suggested ToLOC  
   UPDATE dbo.REPLENISHMENT WITH (ROWLOCK) SET  
      ToLOC       = @cToLOC    
      ,Confirmed  = 'Y'  
      ,ArchiveCop = NULL  
      ,EditDate   = GetDate()      
      ,EditWho    = SUser_SName()  
   WHERE ReplenishmentKey = @cReplenKey  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 154775  
      SET @cErrMsg = rdt.rdtgetmessage( 154775, @cLangCode, 'DSP') --UPD RPL Fail  
      GOTO RollBackTran  
   END  
  
   SELECT @cLocationType = LocationType  
   FROM dbo.Loc WITH (NOLOCK)  
   WHERE LOC = @cToLOC  
  
   IF @cLocationType = 'DYNAMICPK' OR @cLocationType = 'CASE' -- Exclude FCP & Bulk To PP. FCP already allocated & Bulk To PP can be excluded  
   BEGIN  
      SELECT @cLong = CL.Long,    
             @cNotes = CL.Notes    
      FROM dbo.CODELKUP CL (NOLOCK)    
      WHERE ListName = 'ALLOCPREF'   
      AND   Storerkey = @cStorerKey  
      SELECT @cNotes = REPLACE(@cNotes, '@c_', 'Orders.')  
        
      SET @nQtyInPickLoc = 0  
      SELECT @nQtyInPickLoc = ISNULL(QtyInPickLoc, 0)  
      FROM dbo.Replenishment WITH (NOLOCK)  
      WHERE ReplenishmentKey = @cReplenKey  
  
      IF @nQtyInPickLoc > 0  
      BEGIN  
         SET @nQTY = @nQtyInPickLoc  
      END  
  
   DECLARE @cOrderKey   NVARCHAR( 10)  
   DECLARE @cOrderLineNo NVARCHAR( 5)  
   DECLARE @cUOM        NVARCHAR( 10)  
   DECLARE @cPackKey    NVARCHAR( 10)  
   DECLARE @nOrdAvailQTY INT  
   DECLARE @nUOMQTY     INT  
   DECLARE @n_Seqno        INT  
   DECLARE @c_c_Country    NVARCHAR( 30)  
   DECLARE @c_Delim NVARCHAR( 1)  
   DECLARE @t_Country TABLE (        
      Seqno    INT,         
      Country  NVARCHAR( 30) )     
        
   SET @c_Delim = ','    
   INSERT INTO @t_Country       
   SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @cLottable06)    
     
   -- Start offset  
      WHILE @nQTY > 0  
      BEGIN  
         IF EXISTS ( SELECT 1 FROM @t_Country)  
         BEGIN  
            DECLARE @curD CURSOR      
            SET @curD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
            SELECT Seqno, Country FROM @t_Country ORDER BY Seqno    
            OPEN @curD    
            FETCH NEXT FROM @curD INTO @n_Seqno, @c_c_Country    
            WHILE @@FETCH_STATUS = 0    
            BEGIN    
               SET @cSQL = ''  
               SET @cSQL =   
               ' SELECT ' +  
               '    @cOrderKey    = OD.OrderKey, ' +  
               '    @cOrderLineNo = OD.OrderLineNumber, ' +  
               '    @nOrdAvailQTY = OD.OpenQty - OD.QtyAllocated - OD.QtyPicked, ' +  
               '    @cUOM         = CASE OD.UOM WHEN P.PACKUOM1 THEN ''2'' ' +  
               '       WHEN P.PACKUOM2 THEN ''3'' ' +  
               '       WHEN P.PACKUOM3 THEN ''6'' ' +  
               '       WHEN P.PACKUOM4 THEN ''1'' ' +  
               '       END, ' +  
               '    @nUOMQTY      = CASE OD.UOM WHEN P.PACKUOM1 THEN ABS((OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) /P.CaseCnt) ' +  
               '       WHEN P.PACKUOM2 THEN ABS((OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) /P.InnerPack) ' +  
               '       WHEN P.PACKUOM3 THEN (OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) ' +  
               '       WHEN P.PACKUOM4 THEN ABS((OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) /P.Pallet) ' +  
               '       END, ' +  
               '    @cPackKey     = OD.Packkey ' +  
               ' FROM dbo.WaveDetail WD WITH (NOLOCK) ' +  
               ' JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (WD.Orderkey = OD.Orderkey) ' +  
               ' JOIN dbo.Pack P WITH(NOLOCK) ON (OD.Packkey  = P.Packkey) ' +  
               ' JOIN dbo.Orders Orders WITH (NOLOCK) ON (Orders.OrderKey = OD.OrderKey) ' +   
               ' JOIN dbo.LOTATTRIBUTE LOTATTRIBUTE WITH (NOLOCK) ON (OD.SKU = LOTATTRIBUTE.SKU AND OD.StorerKey = LOTATTRIBUTE.StorerKey) ' +  
               ' WHERE OD.Storerkey = @cStorerKey ' +  
               ' AND   OD.OpenQty - OD.QtyAllocated - OD.QtyPicked > 0 ' +  
               ' AND   OD.SKU = @cSKU ' +  
               ' AND   1 = CASE WHEN OD.Lottable02 = '''' THEN 1 ' +  
               '                WHEN OD.Lottable02 = @cLottable02 THEN 1 ' +  
               '           ELSE 0 END ' +  
               ' AND   WD.WaveKey = @cWaveKey ' +  
               ' AND   Orders.Status NOT IN (''9'',''CANC'') ' +   
               ' AND   Orders.SOStatus NOT IN (''9'',''CANC'')  ' +   
               ' AND   LOTATTRIBUTE.Lot = @cFromLot '   
              
               IF ISNULL( @cLong, '') <> '' AND ISNULL( @cNotes, '') <> ''  
                  SET @cSQL = @cSQL +   
                  ' AND   1 = CASE WHEN ' + @cLong + ' AND ' + @cNotes + ' THEN 1 ELSE 0 END '   
              
               SET @cSQL = @cSQL +    
               ' ORDER BY WD.WaveKey, ' +  
               '          OD.OrderKey DESC ' + -- to make allocation based on orderkey   
               ' SET @nRowCount = @@ROWCOUNT'   
  
               SET @cSQLParms =   
                  '@cStorerKey   NVARCHAR( 15), ' +    
                  '@cSKU         NVARCHAR( 20), ' +    
                  '@cLottable01  NVARCHAR( 18), ' +    
                  '@cLottable02  NVARCHAR( 18), ' +    
                  '@cLottable03  NVARCHAR( 18), ' +    
                  '@dLottable04  DATETIME,      ' +    
                  '@cWaveKey     NVARCHAR( 10), ' +   
                  '@cFromLot     NVARCHAR( 10), ' +  
                  '@c_c_Country  NVARCHAR( 30), ' +  
                  '@cOrderKey    NVARCHAR( 10) OUTPUT, ' +  
                  '@cOrderLineNo NVARCHAR( 5)  OUTPUT, ' +  
                  '@cUOM         NVARCHAR( 10) OUTPUT, ' +  
                  '@cPackKey     NVARCHAR( 10) OUTPUT, ' +  
                  '@nOrdAvailQTY INT           OUTPUT, ' +  
                  '@nUOMQTY      INT           OUTPUT, ' +   
                  '@nRowCount    INT           OUTPUT  '  
                  PRINT @cSQL  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParms,   
                  @cStorerKey  = @cStorerKey,    
                  @cSKU        = @cSKU,    
                  @cLottable01 = @cLottable01,     
                  @cLottable02 = @cLottable02,     
                  @cLottable03 = @cLottable03,     
                  @dLottable04 = @dLottable04,     
                  @cWaveKey    = @cWaveKey,  
                  @cFromLot    = @cFromLot,  
                  @c_c_Country = @c_c_Country,  
                  @cOrderKey   = @cOrderKey     OUTPUT,  
                  @cOrderLineNo= @cOrderLineNo  OUTPUT,  
                  @cUOM        = @cUOM          OUTPUT,  
                  @cPackKey    = @cPackKey      OUTPUT,  
                  @nOrdAvailQTY= @nOrdAvailQTY  OUTPUT,  
                  @nUOMQTY     = @nUOMQTY       OUTPUT,  
                  @nRowCount   = @nRowCount     OUTPUT  
           
               FETCH NEXT FROM @curD INTO @n_Seqno, @c_c_Country  
            END  
         END  
         ELSE  
         BEGIN  
            SELECT   
               @cOrderKey    = OD.OrderKey,   
               @cOrderLineNo = OD.OrderLineNumber,   
               @nOrdAvailQTY = OD.OpenQty - OD.QtyAllocated - OD.QtyPicked,   
               @cUOM         = CASE OD.UOM WHEN P.PACKUOM1 THEN '2'   
                  WHEN P.PACKUOM2 THEN '3'   
                  WHEN P.PACKUOM3 THEN '6'   
                  WHEN P.PACKUOM4 THEN '1'   
                  END,   
               @nUOMQTY      = CASE OD.UOM WHEN P.PACKUOM1 THEN ABS((OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) /P.CaseCnt)   
                  WHEN P.PACKUOM2 THEN ABS((OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) /P.InnerPack)   
                  WHEN P.PACKUOM3 THEN (OD.OpenQty - OD.QtyAllocated - OD.QtyPicked)   
                  WHEN P.PACKUOM4 THEN ABS((OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) /P.Pallet)   
                  END,   
               @cPackKey     = OD.Packkey   
            FROM dbo.WaveDetail WD WITH (NOLOCK)   
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (WD.Orderkey = OD.Orderkey)   
            JOIN dbo.Pack P WITH(NOLOCK) ON (OD.Packkey  = P.Packkey)   
            JOIN dbo.Orders Orders WITH (NOLOCK) ON (Orders.OrderKey = OD.OrderKey)    
            WHERE OD.Storerkey = @cStorerKey   
            AND   OD.OpenQty - OD.QtyAllocated - OD.QtyPicked > 0   
            AND   OD.SKU = @cSKU   
            AND   1 = CASE WHEN OD.Lottable02 = '' THEN 1   
                           WHEN OD.Lottable02 = @cLottable02 THEN 1   
                      ELSE 0 END   
            AND   WD.WaveKey = @cWaveKey   
            AND   Orders.Status NOT IN ('9','CANC')   
            AND   Orders.SOStatus NOT IN ('9','CANC')   
              
            SET @nRowCount = @@ROWCOUNT  
         END  
           
         IF @nRowCount = 0  
         BEGIN  
            IF @cLocationType = 'DYNAMICPK'  
            BEGIN  
               SET @nErrNo = 154781  
               SET @cErrMsg = rdt.rdtgetmessage( 154781, @cLangCode, 'DSP') --NoOrDtlOffset  
               GOTO RollBackTran  
            END  
            ELSE IF @cLocationType = 'CASE'  
            BEGIN  
               BREAK  
            END  
         END  
            
         IF @nQTY < @nOrdAvailQTY  
            SET @nOrdAvailQTY = @nQTY  
  
         SET @b_success = 0  
         EXECUTE dbo.nspg_getkey  
            'PICKDETAILKEY' ,  
            10 ,  
            @keystring      = @cPickDetailKey   OUTPUT ,  
            @b_success      = @b_success        OUTPUT,  
            @n_err          = @n_err            OUTPUT,  
            @c_errmsg       = @c_errmsg         OUTPUT  
  
         IF @b_success <> 1  
         BEGIN  
            SET @nErrNo = 154777  
            SET @cErrMsg = rdt.rdtgetmessage( 154777, @cLangCode, 'DSP') --GetPDKeyFail  
            GOTO RollBackTran  
         END  
  
         INSERT INTO dbo.PICKDETAIL( Pickdetailkey, Caseid, PickHeaderKey, Orderkey, OrderlineNumber, Storerkey, Sku, UOM,  
         UOMQty, Packkey, Lot, Loc, ID, Qty, Wavekey, PickSlipNo, CartonType, ALTSKU)  
         VALUES  
         ( @cPickDetailKey, '', '', @cOrderKey, @cOrderLineNo, @cStorerKey, @cSKU, @cUOM,  
         @nUOMQTY, @cPackKey, @cFromLot, @cToLoc, CASE WHEN @cLoseID = '1' THEN '' ELSE @cFromid END  
         , @nOrdAvailQTY, @cWaveKey, NULL, 'REPLEN', ISNULL(@cUCC, ''))  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 154778  
            SET @cErrMsg = rdt.rdtgetmessage( 154777, @cLangCode, 'DSP') --CreatePKDFail  
            GOTO RollBackTran  
         END  
  
         -- 2) Get PickSlipNo  
         SELECT @cRetrieveDynamicPickslipNo = rdt.RDTGetConfig( @nFunc, 'RetrieveDynamicPickslipNo', @cStorerKey)  
  
         IF EXISTS (SELECT 1 FROM sysobjects WHERE name = RTRIM(@cRetrieveDynamicPickslipNo) AND type = 'P')  
         BEGIN  
            SET @cRetrieveDynamicPickslipNo = 'RDT.' + LTRIM(@cRetrieveDynamicPickslipNo)  
            SET @cSQL = N'EXEC ' + RTRIM(@cRetrieveDynamicPickslipNo) +  
                ' @cWaveKey, @c_OrderKey, @cPickDetailKey, @cPickHeaderKey OUTPUT'  
  
            SET @cSQLParms = N'@cWaveKey        NVARCHAR( 10),    ' +  
                              '@c_OrderKey       NVARCHAR( 10),  ' +  
                              '@cPickDetailKey  NVARCHAR( 10),  ' +  
                              '@cPickHeaderKey  NVARCHAR( 10) OUTPUT '  
  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParms,  
                   @cWaveKey  
                  ,@cOrderKey  
                  ,@cPickDetailKey  
                  ,@cPickHeaderKey OUTPUT  
  
            -- Stamp pickslip no  
            IF @cPickHeaderKey <> ''  
            BEGIN  
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                  PickSlipNo = @cPickHeaderKey,  
                  TrafficCop = NULL,  
                  AltSKU = ISNULL(@cUCC, '')  
               WHERE PickDetailKey = @cPickDetailKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 154778  
                  SET @cErrMsg = rdt.rdtgetmessage( 154778, @cLangCode, 'DSP') --UPD PKD Fail  
                  GOTO RollBackTran  
               END  
            END  
         END   -- End for if exists  
  
         IF @nQTY > @nOrdAvailQTY  
         BEGIN  
            SET @nQTY = @nQTY - @nOrdAvailQTY  
         END  
         ELSE  
         BEGIN  
            BREAK  
         END  
      END   -- End for While @nQTY > 0  
   END   -- Locationtype  
   ELSE -- Print Label for FCP Replenishment  
   BEGIN  
      IF @nUCC_RowRef = 0 OR @nUCC_RowRef = (SELECT MIN(UCC_RowRef) FROM dbo.UCC (NOLOCK) WHERE UCCNo=@cUCC)     -- (james02)  
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
                  SET @nErrNo = 154782  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
                  GOTO RollBackTran  
               END  
  
               IF ISNULL(@cTargetDB, '') = ''  
               BEGIN  
                  SET @nErrNo = 154783  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set  
                  GOTO RollBackTran  
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
                  SET @nErrNo = 154784  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'  
                  GOTO RollBackTran  
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
               SET @nErrNo = 154786  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
               GOTO RollBackTran  
            END  
     
            IF ISNULL(@cTargetDB, '') = ''  
            BEGIN  
               SET @nErrNo = 154787  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set  
               GOTO RollBackTran         
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
               SET @nErrNo = 154785  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'  
               GOTO RollBackTran  
            END  
         END    
  
             
      END
   
         --print carton label process (end)  
   END  
  
   COMMIT TRAN Replen_Move  
   GOTO Quit  
     
   RollBackTran:    
      ROLLBACK TRAN Replen_Move  
  
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN  
   Fail:  

GO