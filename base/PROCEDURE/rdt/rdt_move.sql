SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Move                                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT common move                                             */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2006-07-10 1.0  UngDH    Created                                     */
/* 2006-10-27 1.1  UngDH    Add storer config MoveToLOCNotCheckFacility */
/*                          Fix ToID cannot set to blank                */
/* 2006-11-22 1.2  UngDH    Fix checking of CantMixSKU&UCC doesnt get   */
/*                          location type                               */
/* 2007-04-27 1.3  James    SOS67842 Add no. of move that can be        */
/*                          performed per session                       */
/* 2007-05-15 1.4  AuwYong  SOS72009 Adding Checking for location not   */
/*                          allow for comingle sku                      */
/* 2007-05-31 1.5  Vicky    SOS#77266 - Commingle sku checking not      */
/*                          accurate, rewrite the checking part         */
/* 2008-03-19 1.6  James    Break @curUCC into 2 statement and forced   */
/*                          to use index hint IDX_UCC_LOTxLOCxID        */
/* 2010-10-01 1.7  Shong    Qty Available need to deduct ReplenQty      */
/* 2011-11-11 1.8  ChewKP   LCI Project Changes Update UCC Table        */
/*                          (ChewKP01)                                  */
/* 2011-11-29 1.9  Ung      SOS229877 Add MoveCheckLOCColumnRestriction */
/* 2012-02-14 2.0  James    For UCC move, if from loc doesn't have id   */
/*                          then ignore id (james01)                    */
/* 2012-05-07 2.1  ChewKP   SOS#243561 - LoseUCC (ChewKP02)             */
/* 2012-07-19 2.2  ChewKP   SOS#250946 - LoseID for UCC (ChewKP03)      */
/* 2012-09-24 2.3  Leong    SOS# 256205/258672 - Bug fix.               */
/* 2013-01-17 2.4  Ung      Move QTYAlloc and QTYPick by CaseID (ung01) */
/*                          Multi SKU UCC (ung02)                       */
/* 2013-07-10 2.5  ChewKP   TBL Enhancement -- (ChewKP04)               */
/* 2013-10-02 2.6  Chee     Added StorerConfig ByPassCantMixSKUnUCC     */
/*                          (Chee01)                                    */
/* 2013-01-30 2.7  Ung      SOS251326 Fix trigger rollback but not itrn */
/* 2014-02-06 2.8  Ung      SOS296465 Move QTYAlloc with UCC.Status=3   */
/* 2014-10-16 2.9  Ung      SOS323013 Performance tuning                */
/* 2015-04-30 3.0  Ung      SOS339417 Performance tuning MoveQTYAlloc   */
/*                          SOS315975 Add MoveQTYPick                   */
/*                          SOS342435 Add QTYReplen                     */
/*                          SOS336606 MoveCheckLOCColumnRestriction chg */
/* 2015-04-30 3.1  Ung      SOS336606 MoveCheckLOCColumnRestriction chg */
/* 2016-03-24 3.2  Ung      SOS366906 Add UCC MoveQTYAlloc without task */
/*                          SOS360339 Add MoveQTYAlloc/Pick with CaseID */
/* 2016-09-05 3.3  Ung      SOS372531 Fix QTYReplen calc                */
/* 2017-07-26 3.4  Ung      Performance tuning                          */
/* 2018-10-30 3.5  Ung      WMS-6866 Add Channel                        */
/* 2018-12-17 3.6  Ung      WMS-3273 MoveToLOCNotCheckFacility to func  */
/* 2019-01-11 3.7  Ung      Performance tuning (to reduce deadlock)     */
/* 2020-05-18 3.8  Ung      WMS-127706 Add MoveCheckLOCColumnExactMatch */
/* 2020-06-16 3.9  James    WMS-13116 Add insert ItrnUCC (james02)      */
/* 2020-08-07 4.0  Ung      Performance tuning (remove where case when) */
/* 2021-02-18 4.1  James    WMS-16020 Add WaveKey (james03)             */
/* 2022-03-11 4.2  TLTING01 Perfromance tune - Force Order              */
/* 2023-01-09 4.3  James    WMS-21437 Add ToLoc MaxSKU check (james04)  */
/* 2023-07-24 4.4  Ung      WMS-22703 Fix move by SKU, MOveQTYAlloc     */
/* 2024-04-07 4.5  Ung      WMS-25173 Add UCC.Status = 4-Replen         */
/* 2024-10-01 4.6  James    WMS-26122 Add UCCPickStatus (james05)       */
/* 2024-11-12 4.7  PXL009   FCR-1125 Merged 4.5, 4.6 from v0 branch     */
/* 2024-11-27 4.8.0  NLT013 FCR-1522 Support Overallocation for UL      */
/************************************************************************/

CREATE    PROCEDURE [RDT].[rdt_Move] (
   @nMobile     INT,
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
   @nQTY        INT           = 0,    -- For move by SKU, QTY must have value
   @nQTYAlloc   INT           = 0,
   @nQTYPick    INT           = 0,
   @nQTYReplen  INT           = 0,
   @cFromLOT    NVARCHAR( 10) = NULL, -- Applicable for all 6 types of move
   @nMoveCnt    INT           = 0,        -- No. of move per session
   @nFunc       INT           = 0,
   @cTaskDetailKey NVARCHAR( 10) = '',
   @cOrderKey   NVARCHAR( 10) = '',
   @cDropID     NVARCHAR( 20) = '',
   @cCaseID     NVARCHAR( 20) = '',
   @cChannel    NVARCHAR( 20) = '',
   @nChannel_ID BIGINT = 0,
   @cWaveKey    NVARCHAR( 10) = ''
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cSQL          NVARCHAR( MAX)
DECLARE @cSQLParam     NVARCHAR( MAX)
DECLARE @nRowCount     INT
DECLARE @cStorerConfig_UCC  NVARCHAR( 1)
DECLARE @cChkFacility  NVARCHAR( 5)
DECLARE @cToLocType    NVARCHAR( 10)
DECLARE @cLoseID       NVARCHAR( 1)
DECLARE @cToIDForItrn  NVARCHAR( 18)
DECLARE @cMoveQTYAlloc NVARCHAR( 1)
DECLARE @cMoveQTYPick  NVARCHAR( 1)
DECLARE @cMoveRefKey   NVARCHAR( 10)
DECLARE @cUCCAllocStatus  NVARCHAR( 1)
DECLARE @cUCCPickStatus   NVARCHAR( 1)

DECLARE @cUCCLOT NVARCHAR( 10)
DECLARE @cLOT    NVARCHAR( 10)
DECLARE @cLOC    NVARCHAR( 10)
DECLARE @cID     NVARCHAR( 18)
DECLARE @cLoseUCC NVARCHAR( 1) -- (ChewKP02)
DECLARE @cFromLocLoseUCC NVARCHAR( 1)  -- (ChewKP04)
      , @cToLocLoseUCC NVARCHAR( 1)    -- (ChewKP04)

DECLARE @nFromLOC_UCC INT
DECLARE @nFromLOC_SKU INT
DECLARE @nToLOC_UCC   INT
DECLARE @nToLOC_SKU   INT

DECLARE @nMoveLoop  INT
       ,@cNSKU        NVARCHAR(20)
       ,@cByPassUCCTrack NVARCHAR(1)
       ,@cStorerConfig_ByPassCantMixSKUnUCC NVARCHAR(1)

DECLARE @cFromStatus    NVARCHAR( 10) = ''
DECLARE @cToStatus      NVARCHAR( 10) = ''
DECLARE @tItrnUCCVar    VARIABLETABLE
DECLARE @cItrnKey       NVARCHAR(10)

DECLARE @nMaxSKU        INT = 0
DECLARE @nSKUCnt        INT = 0
DECLARE @nIsSKUExists   INT = 0

SET @nErrNo = 0
SET @nQTY = IsNULL( @nQTY, 0)

-- Get StorerConfig 'UCCTracking'
SET @cStorerConfig_UCC = '0' -- Default Off
SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
FROM dbo.StorerConfig (NOLOCK)
WHERE StorerKey = @cStorerKey
   AND ConfigKey = 'UCC'

-- Move QTYAlloc (ung01)
SET @cMoveQTYPick = rdt.RDTGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)

IF @cMoveQTYAlloc = '1'
   SET @cUCCAllocStatus = '3'
ELSE
   SET @cUCCAllocStatus = ''

IF @cMoveQTYPick = '1'
   SET @cUCCPickStatus = '5'
ELSE
   SET @cUCCPickStatus = ''

SET @cStorerConfig_ByPassCantMixSKUnUCC = rdt.RDTGetConfig( @nFunc, 'ByPassCantMixSKUnUCC', @cStorerKey)

--By Pass UCC Tracking when rdt.Storerconfig By PassUCCTrack is turn on (ChewKP01)
SET @cByPassUCCTrack = ''
SET @cByPassUCCTrack = rdt.RDTGetConfig( 0, 'ByPassUCCTrack', @cStorerKey)

--SOS67842 add by James to force move by no. of record specified by parameter passed in
IF @nMoveCnt > 0
   SET @nMoveLoop = 1
ELSE
   SET @nMoveLoop = 0

/*-------------------------------------------------------------------------------

                                 Validate parameters

-------------------------------------------------------------------------------*/
-- Validate StorerKey (compulsory)
IF @cStorerKey = '' OR @cStorerKey IS NULL
BEGIN
   SET @nErrNo = 60501
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need StorerKey
   GOTO Fail
END

-- Validate Facility (compulsory)
IF @cFacility = '' OR @cFacility IS NULL
BEGIN
   SET @nErrNo = 60502
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Facility
   GOTO Fail
END

-- Validate SourceType (compulsory)
IF @cSourceType IS NULL
BEGIN
   SET @nErrNo = 60503
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad SourceType
   GOTO Fail
END

-- Validate FromLOC (compulsory)
IF @cFromLOC = '' OR @cFromLOC IS NULL
BEGIN
   SET @nErrNo = 60504
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLOC needed
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
      SET @nErrNo = 60505
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad FromLOC
      GOTO Fail
   END

   -- Validate LOC's facility
   IF @cChkFacility <> @cFacility
   BEGIN
      SET @nErrNo = 60506
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
      GOTO Fail
   END
END

-- Validate UCC (optional)
IF @cUCC IS NOT NULL
BEGIN
   IF @cByPassUCCTrack <> '1' -- (ChewKP01)
   BEGIN
      IF @cStorerConfig_UCC <> '1'
      BEGIN
         SET @nErrNo = 60507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCTrackingOff
         GOTO Fail
      END
   END

   -- Validate UCC
   DECLARE @cChkStatus NVARCHAR(10)
   SET @cChkStatus = '1' + '4' + @cUCCAllocStatus + @cUCCPickStatus
   EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT,
      @cUCC,
      @cStorerKey,
      @cChkStatus,
      @nChkQTY = 1,
      @cChkLOC = NULL, -- (james01)
      @cChkID  = @cFromID -- If @cFromID IS NULL, no checking on ID

   IF @nErrNo <> 0
      GOTO Fail

   -- Get UCC SKU, LOT, LOC, ID, QTY
   IF @cUCCAllocStatus = '' AND @cUCCPickStatus = ''
      SELECT
         @cUCCLOT = LOT,
         @cLOC = LOC,
         @cID  = ID,
         @nQTY = QTY
      FROM dbo.UCC WITH (NOLOCK, INDEX=IDX_UCC_UCCNo)
      WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND Status IN ( '1', '4')
   ELSE
      SELECT
         @cUCCLOT = LOT,
         @cLOC = LOC,
         @cID  = ID,
         @nQTY = QTY
      FROM dbo.UCC WITH (NOLOCK, INDEX=IDX_UCC_UCCNo)
      WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND Status IN ('1', '4', @cUCCAllocStatus, @cUCCPickStatus) -- Received, Replenish, Allocated, Picked
            AND Status <> ''

   -- If ucc from blank id loc then cannot
   -- get id from ucc table anymore (james01)
   IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID (NOLOCK)
                  WHERE LOT = @cUCCLOT
                  AND LOC = @cFromLOC
                  AND ID = '')
   BEGIN
      IF @cFromID IS NULL
         SET @cFromID = @cID

      IF @cFromID <> @cID
      BEGIN
         SET @nErrNo = 60508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCID Unmatch
         GOTO Fail
      END
   END

   IF @cFromLOT IS NOT NULL AND @cFromLOT <> @cUCCLOT
   BEGIN
      SET @nErrNo = 60509
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCLOT Unmatch
      GOTO Fail
   END
END

-- Validate ToLOC (compulsory)
IF @cToLOC = '' OR @cToLOC IS NULL
BEGIN
   SET @nErrNo = 60510
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC needed
   GOTO Fail
END
ELSE
BEGIN
   SET @cLoseUCC = ''
   SELECT
      @cChkFacility = Facility,
      @cLoseID      = LoseID,
      @cLoseUCC     = LoseUCC -- (ChewKP02)
   FROM dbo.LOC (NOLOCK)
   WHERE LOC = @cToLOC

   -- Validate LOC
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 60511
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ToLOC
      GOTO Fail
   END

   -- Validate ToLOC's facility
   DECLARE @cMoveToLOCNotCheckFacility NVARCHAR(1)
   SET @cMoveToLOCNotCheckFacility = rdt.RDTGetConfig( @nFunc, 'MoveToLOCNotCheckFacility', @cStorerKey)
   IF @cMoveToLOCNotCheckFacility <> '1'
   BEGIN
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 60512
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Fail
      END
   END

   -- Validate move restriction by column
   DECLARE @cColumnName NVARCHAR( 20)
   SET @cColumnName = rdt.RDTGetConfig( @nFunc, 'MoveCheckLOCColumnRestriction', @cStorerKey)
   IF @cColumnName = '0'
      SET @cColumnName = rdt.RDTGetConfig( 0, 'MoveCheckLOCColumnRestriction', @cStorerKey)
   IF @cColumnName <> '0'
   BEGIN
      -- Validate restrict by column exist
      DECLARE @cDataType NVARCHAR(128)
      SET @cDataType = ''
      SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'LOC' AND COLUMN_NAME = @cColumnName

      IF @cDataType <> ''
      BEGIN
         DECLARE @nAllowMove     INT
         DECLARE @cDefaultValue  NVARCHAR(10)

         -- Default value when column is NULL
         IF @cDataType = 'nvarchar' OR @cDataType = 'nchar'
            SET @cDefaultValue = ''''''
         ELSE
            SET @cDefaultValue = '0'

         DECLARE @cMoveCheckLOCColumnExactMatch NVARCHAR(1)
         SET @cMoveCheckLOCColumnExactMatch = rdt.RDTGetConfig( @nFunc, 'MoveCheckLOCColumnExactMatch', @cStorerKey)
         IF @cMoveCheckLOCColumnExactMatch = '0'
            SET @cMoveCheckLOCColumnExactMatch = rdt.RDTGetConfig( 0, 'MoveCheckLOCColumnExactMatch', @cStorerKey)

         -- Validate FromLOC ToLOC same restrict by column value
         SET @nAllowMove = 1 -- Yes
         SET @cSQLParam = '@cFromLOC NVARCHAR( 10), @cToLOC NVARCHAR( 10), @cColumnName NVARCHAR( 20), @nAllowMove INT OUTPUT'
         SET @cSQL = 'SELECT @nAllowMove = 0 ' +
            ' FROM dbo.LOC FromLOC WITH (NOLOCK)' +
               ' INNER JOIN dbo.LOC ToLOC WITH (NOLOCK) ON (FromLOC.LOC = @cFromLOC AND ToLOC.LOC = @cToLOC)' +
            ' WHERE ISNULL( FromLOC.' + @cColumnName + ',' + @cDefaultValue + ') <> ' + ' ISNULL( ToLOC.' + @cColumnName + ',' + @cDefaultValue + ')' +
            CASE WHEN @cMoveCheckLOCColumnExactMatch = '0'
                 THEN
                  ' AND ISNULL( FromLOC.' + @cColumnName + ',' + @cDefaultValue + ') <> ' + @cDefaultValue +
                  ' AND ISNULL( ToLOC.' + @cColumnName + ',' + @cDefaultValue + ') <> ' + @cDefaultValue
                 ELSE ''
            END
         EXEC sp_executesql @cSQL, @cSQLParam, @cFromLOC, @cToLOC, @cColumnName, @nAllowMove OUTPUT
         IF @nAllowMove = 0
         BEGIN
            SET @nErrNo = 60513
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MoveChkColFail
            GOTO Fail
         END
      END
   END

   -- Check commingle SKU
   DECLARE @nFromCnt int, @nToCnt int, @cFromSKU NVARCHAR(20), @cToSKU NVARCHAR(20)
   SELECT @nFromCnt = 0, @nToCnt = 0
   IF rdt.RDTGetConfig( 0, 'CheckNonCommingleSKUInMove', @cStorerKey) = '1'
   BEGIN
      IF EXISTS (SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK)
                 WHERE LOC.LOC = @cToLOC
                 AND   LOC.CommingleSKU = '0')
      BEGIN
         -- SKU specified
         IF @cSKU IS NOT NULL
         BEGIN
            IF EXISTS( SELECT TOP 1 1
               FROM dbo.LOTxLOCxID LLI (NOLOCK)
                  INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU)
                  INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE LLI.StorerKey = @cStorerKey
                  AND LLI.LOC = @cToLOC
                  AND LLI.SKU <> @cSKU
                  AND (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0))
            BEGIN
               SET @nErrNo = 60514
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --LocNotCommgSKU
               GOTO Fail
            END
         END

         -- SKU not specified (move by LOC or ID or UCC)
         ELSE
         BEGIN
            -- Get FromLOC SKU count
            /*
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
               AND LLI.QTY - LLI.QTYPicked > 0
            */
            SET @cSQL =
               ' SELECT @nFromCnt = COUNT(DISTINCT LLI.SKU) ' +
               ' FROM dbo.LOTxLOCxID LLI (NOLOCK) ' +
                  ' INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU) ' +
                  ' INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey) ' +
               ' WHERE LLI.StorerKey = @cStorerKey ' +
                  ' AND LLI.LOC = @cFromLOC ' +
                  CASE WHEN @cFromID  IS NULL THEN '' ELSE ' AND LLI.ID  = @cFromID  ' END +
                  CASE WHEN @cFromLOT IS NULL THEN '' ELSE ' AND LLI.LOT = @cFromLOT ' END +
                  CASE WHEN @cSKU     IS NULL THEN '' ELSE ' AND LLI.SKU = @cSKU     ' END + -- Move by SKU
                  CASE WHEN @cUCC     IS NULL THEN '' ELSE ' AND LLI.LOT = @cUCCLOT  ' END + -- Move by UCC (already got LOT,LOC,ID)
                  ' AND LLI.QTY - LLI.QTYPicked > 0 '
            SET @cSQLParam =
               ' @cStorerKey  NVARCHAR(15), ' +
               ' @cFromLOC    NVARCHAR(10), ' +
               ' @cFromID     NVARCHAR(18), ' +
               ' @cFromLOT    NVARCHAR(10), ' +
               ' @cSKU        NVARCHAR(20), ' +
               ' @cUCCLOT     NVARCHAR(10), ' +
               ' @nFromCnt    INT OUTPUT    '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cFromLOC, @cFromID, @cFromLOT, @cSKU, @cUCCLOT,
               @nFromCnt OUTPUT

            IF @nFromCnt > 1
            BEGIN
               SET @nErrNo = 60515
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --LocNotCommgSKU
               GOTO Fail
            END

            -- Get To LOC SKU count
            SELECT @nToCnt = COUNT(DISTINCT LLI.SKU)
            FROM dbo.LOTxLOCxID LLI (NOLOCK)
               INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU)
               INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE LLI.StorerKey = @cStorerKey
               AND LLI.LOC = @cToLOC
               AND (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0)
            IF @nToCnt > 1
            BEGIN
             SET @nErrNo = 60516
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --LocNotCommgSKU
               GOTO Fail
            END

            IF (@nFromCnt = 1 AND @nToCnt = 1)
            BEGIN
               -- Get From LOC SKU
               /*
               SELECT @cFromSKU = LLI.SKU
               FROM dbo.LOTxLOCxID LLI (NOLOCK)
                  INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU)
                  INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE LLI.StorerKey = @cStorerKey
                  AND LLI.LOC = @cFromLOC
                  AND LLI.ID  = CASE WHEN @cFromID  IS NULL THEN LLI.ID  ELSE @cFromID  END
                  AND LLI.LOT = CASE WHEN @cFromLOT IS NULL THEN LLI.LOT ELSE @cFromLOT END
                  AND LLI.SKU = CASE WHEN @cSKU     IS NULL THEN LLI.SKU ELSE @cSKU     END -- Move by SKU
                  AND LLI.LOT = CASE WHEN @cUCC     IS NULL THEN LLI.LOT ELSE @cUCCLOT  END -- Move by UCC (already got LOT,LOC,ID)
                  AND LLI.QTY - LLI.QTYPicked > 0
               */
               SET @cSQL =
                  ' SELECT @cFromSKU = LLI.SKU ' +
                  ' FROM dbo.LOTxLOCxID LLI (NOLOCK) ' +
                     ' INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU) ' +
                     ' INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey) ' +
                  ' WHERE LLI.StorerKey = @cStorerKey ' +
                     ' AND LLI.LOC = @cFromLOC ' +
                     CASE WHEN @cFromID  IS NULL THEN '' ELSE ' AND LLI.ID  = @cFromID  ' END +
                     CASE WHEN @cFromLOT IS NULL THEN '' ELSE ' AND LLI.LOT = @cFromLOT ' END +
                     CASE WHEN @cSKU     IS NULL THEN '' ELSE ' AND LLI.SKU = @cSKU     ' END + -- Move by SKU
                     CASE WHEN @cUCC     IS NULL THEN '' ELSE ' AND LLI.LOT = @cUCCLOT  ' END + -- Move by UCC (already got LOT,LOC,ID)
                     ' AND LLI.QTY - LLI.QTYPicked > 0 '
               SET @cSQLParam =
                  ' @cStorerKey  NVARCHAR(15), ' +
                  ' @cFromLOC    NVARCHAR(10), ' +
                  ' @cFromID     NVARCHAR(18), ' +
                  ' @cFromLOT    NVARCHAR(10), ' +
                  ' @cSKU        NVARCHAR(20), ' +
                  ' @cUCCLOT     NVARCHAR(10), ' +
                  ' @cFromSKU    NVARCHAR(20) OUTPUT '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cFromLOC, @cFromID, @cFromLOT, @cSKU, @cUCCLOT,
                  @cFromSKU OUTPUT

               -- Get To LOC SKU
               SELECT @cToSKU = LLI.SKU
               FROM dbo.LOTxLOCxID LLI (NOLOCK)
                  INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU)
                  INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE LLI.StorerKey = @cStorerKey
                  AND LLI.LOC = @cToLOC
                  AND (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0)

               IF RTRIM( @cFromSKU) <> RTRIM( @cToSKU)
               BEGIN
                  SET @nErrNo = 60517
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --LocNotCommgSKU
                  GOTO Fail
               END
            END
         END
      END
   END

   -- (james04)
   IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
               WHERE LOC = @cToLOC
               AND   Facility = @cFacility
               AND   CommingleSKU = '1')
   BEGIN
      SELECT @nMaxSKU = MaxSKU
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLOC
      AND   Facility = @cFacility
      AND   CommingleSKU = '1'

      -- Only check if MaxSku setup
      IF @nMaxSKU > 0
      BEGIN
         -- Move by Sku
         IF @cSKU IS NOT NULL
         BEGIN
            -- Sku to move in not exists in ToLoc, MaxSku checking need + 1
            IF NOT EXISTS ( SELECT 1
                            FROM dbo.LOTxLOCxID WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND   Loc = @cToLOC
                            AND   Sku = @cSKU
                            AND   (QTY - QTYPicked > 0 OR PendingMoveIn > 0))
               SET @nIsSKUExists = 1
            ELSE
               SET @nIsSKUExists = -1  -- exclude the sku which already exists in toloc
         END
         ELSE  -- Move by Loc/Id
         BEGIN
            SELECT @nIsSKUExists = COUNT( DISTINCT LLI.Sku)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
            WHERE LLI.StorerKey = @cStorerKey
            AND   (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0)
            AND   (( @cFromID IS NULL AND LLI.Id = LLI.Id) OR ( @cFromID IS NOT NULL AND LLI.Id = @cFromID))
            AND   LOC.Facility = @cFacility
            AND   LOC.Loc = @cFromLOC
            AND   NOT EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI2 WITH (NOLOCK)
                  JOIN dbo.LOC LOC2 WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
                  WHERE LLI2.StorerKey = @cStorerKey
                  AND   (LLI2.QTY - LLI2.QTYPicked > 0 OR LLI2.PendingMoveIn > 0)
                  AND   LOC2.Facility = @cFacility
                  AND   LOC2.Loc = @cToLOC
                  AND   LLI.Sku = LLI2.Sku)
         END

         SELECT @nSKUCnt = COUNT( DISTINCT SKU)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.Loc LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
         WHERE LOC.Loc = @cToLOC
         AND   LOC.Facility = @cFacility
         AND   LLI.StorerKey = @cStorerKey
         AND   (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0)

         IF @nMaxSKU < ( @nSKUCnt + @nIsSKUExists)
         BEGIN
            SET @nErrNo = 60549
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Over MaxSku
            GOTO Fail
         END
      END
   END
END

-- Validate FromID (optional)
IF @cFromID IS NOT NULL
BEGIN
   -- Validate ID
   IF NOT EXISTS( SELECT TOP 1 1
      FROM dbo.LOTxLOCxID (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC
         AND ID = @cFromID)
   BEGIN
      SET @nErrNo = 60518
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
      GOTO Fail
   END

   -- Validate ID in multi LOC
/*
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 60519
 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID in MultiLOC
      GOTO Fail
   END
*/
END

-- Validate both SKU and UCC passed-in
IF @cSKU IS NOT NULL AND @cUCC IS NOT NULL
BEGIN
   SET @nErrNo = 60520
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Either SKU/UCC
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
      SET @nErrNo = 60521
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
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
         SET @nErrNo = 60522
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOCHasMultiID
         GOTO Fail
      END
   END

   -- Validate QTY
   IF RDT.rdtIsValidQTY( @nQTY, 1) = 0
   BEGIN
      SET @nErrNo = 60523
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
      GOTO Fail
   END

   -- Validate QTYAlloc
   IF @nQTYAlloc <> 0
   BEGIN
      IF @cMoveQTYAlloc <> '1'
      BEGIN
         SET @nErrNo = 60524
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MoveAllocNotOn
         GOTO Fail
      END

      -- Check QTYAlloc
      IF RDT.rdtIsValidQTY( @nQTYAlloc, 1) = 0
      BEGIN
         SET @nErrNo = 60525
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad QTYAlloc
         GOTO Fail
      END
   END

   -- Validate QTYPick
   IF @nQTYPick <> 0
   BEGIN
      IF @cMoveQTYPick <> '1'
      BEGIN
         SET @nErrNo = 60526
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MovePickNotOn
         GOTO Fail
      END

      -- Check QTYPick
      IF RDT.rdtIsValidQTY( @nQTYPick, 1) = 0
      BEGIN
         SET @nErrNo = 60527
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad QTYPick
         GOTO Fail
      END
   END

   -- Validate QTYReplen
   IF @nQTYReplen <> 0
   BEGIN
      -- Check QTYPick
      IF RDT.rdtIsValidQTY( @nQTYReplen, 1) = 0
      BEGIN
         SET @nErrNo = 60546
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad QTYReplen
         GOTO Fail
      END

     IF @nQTYReplen > (@nQTY-@nQTYAlloc-@nQTYPick)
      BEGIN
         SET @nErrNo = 60547
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYRepln>Avail
         GOTO Fail
      END
   END

   -- Check QTY to move
   IF @nQTY-@nQTYAlloc-@nQTYPick < 0
   BEGIN
      SET @nErrNo = 60528
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY<Alloc+Pick
      GOTO Fail
   END
END

-- Validate QTY
IF @cSKU IS NULL AND @cUCC IS NULL AND @nQTY <> 0
BEGIN
   SET @nErrNo = 60529
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad QTY Param
   GOTO Fail
END

-- Validate LOT
IF @cFromLOT IS NOT NULL AND @cFromLOT = ''
BEGIN
   SET @nErrNo = 60530
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOT
   GOTO Fail
END

-- (ChewKP04)
IF @cStorerConfig_UCC = '1'
BEGIN
   IF @cStorerConfig_ByPassCantMixSKUnUCC <> '1'
   BEGIN
      SET @cFromLocLoseUCC = ''
      SET @cToLocLoseUCC = ''
      SELECT @cFromLocLoseUCC = LoseUCC FROM dbo.Loc WITH (NOLOCK)
      WHERE Loc = @cFromLOC

      SELECT @cToLocLoseUCC = LoseUCC FROM dbo.Loc WITH (NOLOCK)
      WHERE Loc = @cToLOC

      IF @cFromLocLoseUCC = '1' AND @cToLocLoseUCC = '0'
      BEGIN
         SET @nErrNo = 60531
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToLoc
         GOTO Fail
      END
   END
END

/*-------------------------------------------------------------------------------

                                   Actual move

-------------------------------------------------------------------------------*/
/* There are 6 types of move:
   By ID
   1. ID
   2. ID, SKU, QTY
   3. ID, UCC

   By LOC
   4. LOC
   5. LOC, SKU, QTY
   6. LOC, UCC
*/

DECLARE @b_Success   INT
DECLARE @cUCC_ToUpd  NVARCHAR( 20)

DECLARE @cLLI_SKU    NVARCHAR( 20)
DECLARE @cPackKey    NVARCHAR( 10)
DECLARE @cPackUOM3   NVARCHAR( 10)

DECLARE @nQTY_Move   INT
DECLARE @nQTY_Avail  INT
DECLARE @nQTY_Replen INT

DECLARE @nBal_Avail  INT
DECLARE @nBal_Alloc  INT
DECLARE @nBal_Pick   INT
DECLARE @nBal_Replen INT

DECLARE @nLLI_QTY    INT
DECLARE @nLLI_Avail  INT
DECLARE @nLLI_Alloc  INT
DECLARE @nLLI_Pick   INT
DECLARE @nLLI_Replen INT

DECLARE @nPD_Alloc   INT
DECLARE @nPD_Pick    INT

DECLARE @curLLI CURSOR
DECLARE @curUCC CURSOR


IF ((@cSKU IS NULL AND @cUCC IS NULL) AND -- Move by ID or LOC and
   (@cMoveQTYAlloc <> '1' OR              -- Move QTY Alloc turn off or
    @cMoveQTYPick  <> '1'))               -- Move QTY Pick turn off
BEGIN
   /*
   SELECT
      @nLLI_Alloc = ISNULL( SUM( LLI.QTYAllocated), 0),
      @nLLI_Pick = ISNULL( SUM( LLI.QTYPicked), 0)
   FROM dbo.LOTxLOCxID LLI (NOLOCK)
   WHERE LLI.StorerKey = @cStorerKey
      AND LLI.LOC = @cFromLOC
      AND LLI.ID  = CASE WHEN @cFromID  IS NULL THEN LLI.ID  ELSE @cFromID END
      AND LLI.LOT = CASE WHEN @cFromLOT IS NULL THEN LLI.LOT ELSE @cFromLOT END
   */
   SET @cSQL =
      ' SELECT ' +
         ' @nLLI_Alloc = ISNULL( SUM( LLI.QTYAllocated), 0), ' +
         ' @nLLI_Pick = ISNULL( SUM( LLI.QTYPicked), 0) ' +
      ' FROM dbo.LOTxLOCxID LLI (NOLOCK) ' +
      ' WHERE LLI.StorerKey = @cStorerKey ' +
         ' AND LLI.LOC = @cFromLOC ' +
            CASE WHEN @cFromID  IS NULL THEN '' ELSE ' AND LLI.ID  = @cFromID  ' END +
            CASE WHEN @cFromLOT IS NULL THEN '' ELSE ' AND LLI.LOT = @cFromLOT ' END
   SET @cSQLParam =
      ' @cStorerKey  NVARCHAR(15), ' +
      ' @cFromLOC    NVARCHAR(10), ' +
      ' @cFromID     NVARCHAR(18), ' +
      ' @cFromLOT    NVARCHAR(10), ' +
      ' @nLLI_Alloc  INT OUTPUT,   ' +
' @nLLI_Pick   INT OUTPUT    '
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cFromLOC, @cFromID, @cFromLOT,
      @nLLI_Alloc OUTPUT,
      @nLLI_Pick  OUTPUT

   -- Move QTY Alloc not allow
   IF @cMoveQTYAlloc <> '1' AND @nLLI_Alloc > 0
   BEGIN
      SET @nErrNo = 60532
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAlloc > 0
      GOTO Fail
   END

   -- Move QTY Pick not allow
   IF @cMoveQTYPick <> '1' AND @nLLI_Pick > 0
   BEGIN
      SET @nErrNo = 60533
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYPick > 0
      GOTO Fail
   END
END

-- Move by UCC
IF @cUCC IS NOT NULL
BEGIN
   -- Move QTY Alloc
   IF @cMoveQTYAlloc = '1'
   BEGIN
      SET @cSQL = ''

      -- Get QTY alloc
      IF @cTaskDetailKey <> ''
         /*
         SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status BETWEEN '0' AND '3'
            AND QTY > 0
            AND TaskDetailKey = @cTaskDetailKey
         */
         SET @cSQL = ' AND TaskDetailKey = @cTaskDetailKey '

      ELSE IF @cCaseID <> ''
         /*
         SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status BETWEEN '0' AND '3'
            AND QTY > 0
            AND CaseID = @cCaseID
         */
         SET @cSQL = ' AND CaseID = @cCaseID '

      ELSE IF @cDropID <> ''
         /*
         SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status BETWEEN '0' AND '3'
            AND QTY > 0
            AND DropID = @cDropID
         */
         SET @cSQL = ' AND DropID = @cDropID '

      ELSE IF @cDropID = ''
         /*
         SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status BETWEEN '0' AND '3'
            AND QTY > 0
            AND DropID = @cUCC
         */
         SET @cSQL = ' AND DropID = @cUCC '

      IF @cSQL <> ''
      BEGIN
         SET @cSQL =
            ' SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0) ' +
            ' FROM dbo.PickDetail PD (NOLOCK) ' +
            ' WHERE StorerKey = @cStorerKey ' +
               ' AND LOC = @cFromLOC ' +
               CASE WHEN @cFromID  IS NULL THEN '' ELSE ' AND ID  = @cFromID  ' END +
               CASE WHEN @cFromLOT IS NULL THEN '' ELSE ' AND LOT = @cFromLOT ' END +
               ' AND Status BETWEEN ''0'' AND ''3'' ' +
               ' AND QTY > 0 ' +
               @cSQL -- TaskDetailKey/CaseID/DropID
         SET @cSQLParam =
            ' @cStorerKey     NVARCHAR(15), ' +
            ' @cFromLOC       NVARCHAR(10), ' +
            ' @cFromID        NVARCHAR(18), ' +
            ' @cFromLOT       NVARCHAR(10), ' +
            ' @cTaskDetailKey NVARCHAR(10), ' +
            ' @cCaseID        NVARCHAR(20), ' +
            ' @cDropID        NVARCHAR(20), ' +
            ' @cUCC           NVARCHAR(20), ' +
            ' @nPD_Alloc      INT OUTPUT    '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cFromLOC, @cFromID, @cFromLOT,
            @cTaskDetailKey,
            @cCaseID,
            @cDropID,
            @cUCC,
            @nPD_Alloc OUTPUT

         -- Move alloc QTY more then UCC QTY
         IF @nPD_Alloc > @nQTY
         BEGIN
            SET @nErrNo = 60548
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PDUCCQTY>MVQTY
            GOTO Fail
         END
      END

      SET @nQTYAlloc = @nPD_Alloc
   END
END

-- Move by SKU
IF @cSKU IS NOT NULL
BEGIN
   -- Move QTY Alloc
   IF @cMoveQTYAlloc = '1' AND @nQTYAlloc > 0
   BEGIN
      -- Get QTY alloc
      IF @cTaskDetailKey <> ''
         /*
         SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status BETWEEN '0' AND '3'
            AND QTY > 0
            AND TaskDetailKey = @cTaskDetailKey
         */
         SET @cSQL = ' AND TaskDetailKey = @cTaskDetailKey '

      ELSE IF @cOrderKey <> ''
         /*
         SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
        AND Status BETWEEN '0' AND '3'
            AND QTY > 0
            AND OrderKey = @cOrderKey
         */
         SET @cSQL = ' AND OrderKey = @cOrderKey '

      ELSE IF @cCaseID <> ''
         /*
         SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status BETWEEN '0' AND '3'
            AND QTY > 0
            AND CaseID = @cCaseID
         */
         SET @cSQL = ' AND CaseID = @cCaseID '

      ELSE IF @cDropID <> ''
         /*
         SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status BETWEEN '0' AND '3'
            AND QTY > 0
            AND DropID = @cDropID
         */
         SET @cSQL = ' AND DropID = @cDropID '
      ELSE IF @cWaveKey <> ''
         SET @cSQL = ' AND WaveKey = @cWaveKey '
         /*
      ELSE
         SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status BETWEEN '0' AND '3'
            AND QTY > 0
         */

      SET @cSQL =
         ' SELECT @nPD_Alloc = ISNULL( SUM( QTY), 0) ' +
         ' FROM dbo.PickDetail PD (NOLOCK) ' +
     ' WHERE StorerKey = @cStorerKey ' +
            ' AND SKU = @cSKU ' +
            ' AND LOC = @cFromLOC ' +
            CASE WHEN @cFromID  IS NULL THEN '' ELSE ' AND ID  = @cFromID  ' END +
            CASE WHEN @cFromLOT IS NULL THEN '' ELSE ' AND LOT = @cFromLOT ' END +
            ' AND Status BETWEEN ''0'' AND ''3'' ' +
            ' AND QTY > 0 ' +
            @cSQL -- TaskDetailKey/OrderKey/CaseID/DropID
      SET @cSQLParam =
         ' @cStorerKey     NVARCHAR(15), ' +
         ' @cSKU           NVARCHAR(20), ' +
         ' @cFromLOC       NVARCHAR(10), ' +
         ' @cFromID        NVARCHAR(18), ' +
         ' @cFromLOT       NVARCHAR(10), ' +
         ' @cTaskDetailKey NVARCHAR(10), ' +
         ' @cOrderKey      NVARCHAR(10), ' +
         ' @cCaseID        NVARCHAR(20), ' +
         ' @cDropID        NVARCHAR(20), ' +
         ' @cWaveKey       NVARCHAR(10), ' +
         ' @nPD_Alloc      INT OUTPUT    '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cSKU, @cFromLOC, @cFromID, @cFromLOT,
         @cTaskDetailKey,
         @cOrderKey,
         @cCaseID,
         @cDropID,
         @cWaveKey,
         @nPD_Alloc OUTPUT

      -- Move partial QTY Alloc not allow
      IF @nQTYAlloc < @nPD_Alloc
      BEGIN
         SET @nErrNo = 60534
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MvPartQTYAlloc
         GOTO Fail
      END

      -- Move QTY Alloc more then PickDetail
      IF @nQTYAlloc > @nPD_Alloc
      BEGIN
         SET @nErrNo = 60543
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAvalNotEnuf
         GOTO Fail
      END
   END

   -- Move QTY pick
   IF @cMoveQTYPick  = '1' AND @nQTYPick  > 0
   BEGIN
      SET @cSQL = ''

      -- Get QTY pick
      IF @cTaskDetailKey <> ''
         /*
         SELECT @nPD_Pick = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status = '5'
            AND QTY > 0
            AND TaskDetailKey = @cTaskDetailKey           */
         SET @cSQL = ' AND TaskDetailKey = @cTaskDetailKey '

      ELSE IF @cOrderKey <> ''
         /*
         SELECT @nPD_Pick = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status = '5'
            AND QTY > 0
            AND OrderKey = @cOrderKey
         */
         SET @cSQL = ' AND OrderKey = @cOrderKey '

      ELSE IF @cCaseID <> ''
         /*
         SELECT @nPD_Pick = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status = '5'
            AND QTY > 0
            AND CaseID = @cCaseID
         */
         SET @cSQL = ' AND CaseID = @cCaseID '

      ELSE IF @cDropID <> ''
         /*
         SELECT @nPD_Pick = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status = '5'
            AND QTY > 0
            AND DropID = @cDropID
         */
         SET @cSQL = ' AND DropID = @cDropID '

         /*
      ELSE
         SELECT @nPD_Pick = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cFromLOC
            AND ID  = CASE WHEN @cFromID  IS NULL THEN ID  ELSE @cFromID  END
            AND LOT = CASE WHEN @cFromLOT IS NULL THEN LOT ELSE @cFromLOT END
            AND Status = '5'
            AND QTY > 0
         */

      SET @cSQL =
         ' SELECT @nPD_Pick = ISNULL( SUM( QTY), 0) ' +
         ' FROM dbo.PickDetail PD (NOLOCK) ' +
         ' WHERE StorerKey = @cStorerKey ' +
            ' AND LOC = @cFromLOC ' +
            CASE WHEN @cFromID  IS NULL THEN '' ELSE ' AND ID  = @cFromID  ' END +
            CASE WHEN @cFromLOT IS NULL THEN '' ELSE ' AND LOT = @cFromLOT ' END +
            ' AND SKU = @cSKU ' +
            ' AND Status = ''5'' ' +
            ' AND QTY > 0 ' +
            @cSQL -- TaskDetailKey/OrderKey/CaseID/DropID
      SET @cSQLParam =
         ' @cStorerKey     NVARCHAR(15), ' +
         ' @cSKU           NVARCHAR(20), ' +
         ' @cFromLOC       NVARCHAR(10), ' +
         ' @cFromID        NVARCHAR(18), ' +
         ' @cFromLOT       NVARCHAR(10), ' +
         ' @cTaskDetailKey NVARCHAR(10), ' +
         ' @cOrderKey      NVARCHAR(10), ' +
         ' @cCaseID        NVARCHAR(20), ' +
         ' @cDropID        NVARCHAR(20), ' +
         ' @nPD_Pick       INT OUTPUT    '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cSKU, @cFromLOC, @cFromID, @cFromLOT,
         @cTaskDetailKey,
         @cOrderKey,
         @cCaseID,
         @cDropID,
         @nPD_Pick OUTPUT

      -- Move partial QTY Pick not allow if without scope
      IF @nQTYPick < @nPD_Pick AND
         @cTaskDetailKey = ''  AND
         @cOrderKey = ''       AND
         @cCaseID = ''         AND
         @cDropID = ''
      BEGIN
         SET @nErrNo = 60535
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MvPartQTYPick
         GOTO Fail
      END

      -- Move QTY Pick more then PickDetail
      IF @nQTYPick > @nPD_Pick
      BEGIN
         SET @nErrNo = 60542
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYPickNotEnuf
         GOTO Fail
      END
   END
END

-- Get LOTxLOCxID candidate
/*
SET @curLLI = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT
      LLI.LOT,
      LLI.LOC,
      LLI.ID,
      LLI.QTY,
      LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked -
         CASE WHEN @nQTYReplen > 0 THEN 0 ELSE (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) END QTYAvail, --
      LLI.QTYAllocated,
      LLI.QTYPicked,
      LLI.QTYReplen,
      SKU.SKU,
      SKU.PackKey,
      Pack.PackUOM3
   FROM dbo.LOTxLOCxID LLI (NOLOCK)
      INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU)
      INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE LLI.StorerKey = @cStorerKey
      AND LLI.LOC = @cFromLOC
      AND LLI.ID  = CASE WHEN @cFromID  IS NULL THEN LLI.ID  ELSE @cFromID  END
      AND LLI.LOT = CASE WHEN @cFromLOT IS NULL THEN LLI.LOT ELSE @cFromLOT END
      AND LLI.SKU = CASE WHEN @cSKU     IS NULL THEN LLI.SKU ELSE @cSKU     END -- Move by SKU
      AND LLI.LOT = CASE WHEN @cUCC     IS NULL THEN LLI.LOT ELSE @cUCCLOT  END -- Move by UCC (already got LOT,LOC,ID)
      AND LLI.QTY -
         (CASE WHEN @cMoveQTYAlloc = '1' THEN 0 ELSE LLI.QTYAllocated END) -
         (CASE WHEN @cMoveQTYPick = '1'  THEN 0 ELSE LLI.QTYPicked END) -
         (CASE WHEN @nQTYReplen > 0      THEN 0 ELSE (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) END)
          > 0
   ORDER BY LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.QTY OPTION (RECOMPILE)
*/

SET @cSQL =     
   ' SET @curLLI = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +     
      ' SELECT ' +     
         ' LLI.LOT, ' +     
         ' LLI.LOC, ' +     
         ' LLI.ID,  ' +     
         ' LLI.QTY, ' +     
         --' LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - ' +
		 ' LLI.QTY - (LLI.QTYAllocated - LLI.QTYExpected) - LLI.QTYPicked - ' +  --FCR-1152
         CASE WHEN @nQTYReplen > 0 THEN '0' ELSE '(CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)' END + ' QTYAvail, ' +     
         ' LLI.QTYAllocated, ' +     
         ' LLI.QTYPicked, ' +     
         ' LLI.QTYReplen, ' +     
         ' SKU.SKU, ' +     
         ' SKU.PackKey, ' +     
         ' Pack.PackUOM3 ' +     
      ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK ) ' +      
         ' INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU) ' +     
         ' INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey) ' +     
      ' WHERE LLI.StorerKey = @cStorerKey ' +      
         ' AND LLI.LOC = @cFromLOC ' +      
         ' AND LLI.Qty > 0 ' +      
         CASE WHEN @cFromID  IS NULL THEN '' ELSE ' AND LLI.ID  = @cFromID  ' END +     
         CASE WHEN @cFromLOT IS NULL THEN '' ELSE ' AND LLI.LOT = @cFromLOT ' END +     
         CASE WHEN @cSKU     IS NULL THEN '' ELSE ' AND LLI.SKU = @cSKU     ' END + -- Move by SKU    
         CASE WHEN @cUCC     IS NULL THEN '' ELSE ' AND LLI.LOT = @cUCCLOT  ' END + -- Move by UCC (already got LOT,LOC,ID)    
         ' AND LLI.QTY - ' +     
            CASE WHEN @cMoveQTYAlloc = '1' THEN '0' ELSE ' (LLI.QTYAllocated - LLI.QTYExpected) ' END + ' - ' +       --FCR-1152
            CASE WHEN @cMoveQTYPick = '1'  THEN '0' ELSE ' LLI.QTYPicked ' END + ' - ' +     
            CASE WHEN @nQTYReplen > 0      THEN '0' ELSE ' (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) ' END +     
            ' >= 0 ' +     
      ' ORDER BY SKU.SKU, LLI.LOT, LLI.QTY ' +        --tlting01
      ' OPTION (FORCE ORDER) ' +  --tlting01
      ' OPEN @curLLI '

SET @cSQLParam =
   ' @curLLI      CURSOR OUTPUT, ' +
   ' @cStorerKey  NVARCHAR(15),  ' +
   ' @cFromLOC    NVARCHAR(10),  ' +
   ' @cFromID     NVARCHAR(18),  ' +
   ' @cFromLOT    NVARCHAR(10),  ' +
   ' @cSKU        NVARCHAR(20),  ' +
   ' @cUCCLOT     NVARCHAR(10)   '

EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
   @curLLI OUTPUT,
   @cStorerKey,
   @cFromLOC,
   @cFromID,
   @cFromLOT,
   @cSKU,
   @cUCCLOT

-- Convert ToID to format understood by nspItrnAddMoveCheck
IF @cToID IS NULL
   SET @cToIDForItrn = '' -- Not changing ID (nspItrnAddMoveCheck will default ToID = FromID)
ELSE IF @cToID = ''
   SET @cToIDForItrn = 'CLEAR' -- Set ID as blank (nspItrnAddMoveCheck will set ToID = '')
ELSE
   SET @cToIDForItrn = @cToID

SET @nBal_Avail  = @nQTY - @nQTYAlloc - @nQTYPick
SET @nBal_Alloc  = @nQTYAlloc
SET @nBal_Pick   = @nQTYPick
SET @nBal_Replen = @nQTYReplen


-- Handling transaction
DECLARE @nTranCount INT
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN         -- Begin our own transaction
SAVE TRAN rdt_Move -- For rollback or commit only our own transaction

-- Loop LOTxLOCxID candidate
-- OPEN @curLLI
FETCH NEXT FROM @curLLI INTO @cLOT, @cLOC, @cID, @nLLI_QTY, @nLLI_Avail, @nLLI_Alloc, @nLLI_Pick, @nLLI_Replen, @cLLI_SKU, @cPackKey, @cPackUOM3
WHILE @@FETCH_STATUS = 0
BEGIN
   -- Get ToLOC LocationType
   SET @cToLocType = '' -- Default as BULK (just in case SKUxLOC not yet setup)
   SELECT @cToLocType = LocationType
   FROM dbo.SKUxLOC (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cLLI_SKU
      AND LOC = @cToLOC

   -- By Pass CantMixSKU&UCC checking (Chee01)
   IF @cStorerConfig_ByPassCantMixSKUnUCC <> '1'
   BEGIN
      -- Validate if moved ToLOC will cause SKU + UCC mixed
      -- Check bulk location only. Pick location always lose UCC and become SKU
      IF @cStorerConfig_UCC = '1' AND                                      -- When warehouse has SKU and UCC
         NOT (@cToLocType IN ('CASE', 'PICK') OR @cLoseUCC = '1') AND      -- ToLOC keep UCC
         NOT (@cMoveQTYPick = '1' AND @nLLI_Pick > 0 AND @nBal_Pick > 0)   -- Not MoveQTYPick (Picked means lose UCC)
      BEGIN
         -- Get FromLOC SKU QTY
         IF @cFromID IS NULL
            SELECT @nFromLOC_SKU =
               CASE WHEN @cMoveQTYAlloc = '1'
                  THEN IsNULL( SUM( QTY - QTYPicked), 0)
                  ELSE IsNULL( SUM( QTY - QtyAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)), 0) -- (Avail + Alloc)
               END
            FROM dbo.LOTxLOCxID (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND LOC = @cFromLOC
         ELSE
            SELECT @nFromLOC_SKU =
               CASE WHEN @cMoveQTYAlloc = '1'
                  THEN IsNULL( SUM( QTY - QTYPicked), 0)
                  ELSE IsNULL( SUM( QTY - QtyAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)), 0) -- (Avail + Alloc)
               END
            FROM dbo.LOTxLOCxID (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND LOC = @cFromLOC
               AND ID  = @cFromID

         -- Get FromLOC UCC QTY
         IF @cFromID IS NULL
            SELECT @nFromLOC_UCC = IsNULL( SUM( UCC.QTY), 0)
            FROM dbo.UCC UCC (NOLOCK)
            WHERE UCC.StorerKey = @cStorerKey
               AND UCC.SKU = @cSKU
               AND UCC.LOC = @cFromLOC
               -- AND UCC.Status = '1' -- Received (Avail + Alloc)
               AND UCC.Status IN ('1', '4', @cUCCAllocStatus, @cUCCPickStatus) -- Received, Replenish, Allocated
               AND UCC.Status <> ''
         ELSE
            SELECT @nFromLOC_UCC = IsNULL( SUM( UCC.QTY), 0)
            FROM dbo.UCC UCC (NOLOCK)
            WHERE UCC.StorerKey = @cStorerKey
               AND UCC.SKU = @cSKU
               AND UCC.LOC = @cFromLOC
               AND UCC.ID  = @cFromID
               -- AND UCC.Status = '1' -- Received (Avail + Alloc)
               AND UCC.Status IN ('1', '4', @cUCCAllocStatus, @cUCCPickStatus) -- Received, Replenish, Allocated
               AND UCC.Status <> ''

         -- Get ToLOC SKU QTY
         IF @cToID IS NULL
            SELECT @nToLOC_SKU =
               CASE WHEN @cMoveQTYAlloc = '1'
                  THEN IsNULL( SUM( QTY - QTYPicked), 0)
                  ELSE IsNULL( SUM( QTY - QtyAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)), 0) -- (Avail + Alloc)
               END
            FROM dbo.LOTxLOCxID (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND LOC = @cToLOC
         ELSE
            SELECT @nToLOC_SKU =
               CASE WHEN @cMoveQTYAlloc = '1'
    THEN IsNULL( SUM( QTY - QTYPicked), 0)
                  ELSE IsNULL( SUM( QTY - QtyAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)), 0) -- (Avail + Alloc)
               END
            FROM dbo.LOTxLOCxID (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND LOC = @cToLOC
               AND ID  = @cToID

         -- Get ToLOC UCC QTY
         IF @cToID IS NULL
            SELECT @nToLOC_UCC = IsNULL( SUM( UCC.QTY), 0)
            FROM dbo.UCC UCC (NOLOCK)
            WHERE UCC.StorerKey = @cStorerKey
               AND UCC.SKU = @cSKU
               AND UCC.LOC = @cToLOC
               -- AND UCC.Status = '1' -- Received (Avail + Alloc)
               AND UCC.Status IN ('1', '4', @cUCCAllocStatus, @cUCCPickStatus) -- Received, Replenish, Allocated
               AND UCC.Status <> ''
         ELSE
            SELECT @nToLOC_UCC = IsNULL( SUM( UCC.QTY), 0)
            FROM dbo.UCC UCC (NOLOCK)
            WHERE UCC.StorerKey = @cStorerKey
               AND UCC.SKU = @cSKU
               AND UCC.LOC = @cToLOC
               AND UCC.ID = @cToID
               -- AND UCC.Status = '1' -- Received (Avail + Alloc)
               AND UCC.Status IN ('1', '4', @cUCCAllocStatus, @cUCCPickStatus) -- Received, Replenish, Allocated
               AND UCC.Status <> ''

         IF @nFromLOC_SKU > 0 -- Means SKU or UCC have stock
         BEGIN
            IF @nFromLOC_SKU = @nFromLOC_UCC -- From contain only UCC
               SET @nFromLOC_SKU = 0
            IF @nToLOC_SKU = @nToLOC_UCC -- To contain only UCC
               SET @nToLOC_SKU = 0
            IF (@nToLOC_SKU <> 0 AND @nToLOC_UCC <> 0) OR -- ToLOC is already mix SKU and UCC
               (@nFromLOC_SKU > 0 AND @nToLOC_UCC > 0) OR -- Move SKU to UCC
               (@nFromLOC_UCC > 0 AND @nToLOC_SKU > 0)    -- Move UCC to SKU
            BEGIN
   --select @nFromLOC_SKU '@nFromLOC_SKU', @nFromLOC_UCC '@nFromLOC_UCC', @nToLOC_SKU '@nToLOC_SKU', @nToLOC_UCC '@nToLOC_UCC'
               SET @nErrNo = 60536
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CantMixSKU&UCC
               GOTO RollBackTran
            END
         END
      END
   END -- IF @cStorerConfig_ByPassCantMixSKUnUCC <> '1'

   /* Calc QTY to move */
   SET @cMoveRefKey = ''
   SET @nQTY_Move   = 0
   SET @nQTY_Replen = 0
   SET @nPD_Alloc   = 0
   SET @nPD_Pick    = 0

   -- Move by LOC or ID alone
   IF @cSKU IS NULL AND
      @cUCC IS NULL
   BEGIN
      -- Move QTYAllocated
      IF (@cMoveQTYAlloc = '1' AND @nLLI_Alloc > 0) OR
         (@cMoveQTYPick  = '1' AND @nLLI_Pick  > 0)
      BEGIN
         EXEC rdt.rdt_Move_PickDetail @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cMoveQTYAlloc, @cMoveQTYPick
            ,@cLOT       -- FromLOT
            ,@cLOC       -- FromLOC
            ,@cID        -- FromID
            ,@cToLOC
            ,@cToID      -- NULL means not changing ID. Blank ID is a valid ID
            ,@cSKU       -- Either SKU or UCC only
            ,@cUCC       --
            ,@nBal_Avail -- For move by SKU or UCC, QTY must have value
            ,@nBal_Alloc
            ,@nBal_Pick
            ,@nLLI_QTY
            ,@nLLI_Alloc
            ,@nLLI_Pick
            ,@nPD_Alloc    OUTPUT
            ,@nPD_Pick     OUTPUT
            ,@cMoveRefKey  OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
            ,@cTaskDetailKey = @cTaskDetailKey
            ,@cOrderKey      = @cOrderKey
            ,@cDropID        = @cDropID
            ,@cCaseID        = @cCaseID
         IF @nErrNo <> 0
            GOTO RollBackTran

         IF @cMoveQTYAlloc = '1'
            SET @nQTY_Move = @nQTY_Move + @nLLI_Alloc
         IF @cMoveQTYPick = '1'
            SET @nQTY_Move = @nQTY_Move + @nLLI_Pick
      END

      SET @nQTY_Move = @nQTY_Move + @nLLI_Avail

      -- Not consider balance, since moving all
      SET @nBal_Avail  = 0
      SET @nBal_Alloc  = 0
      SET @nBal_Pick   = 0
      SET @nBal_Replen = 0
   END

   -- Move by SKU or UCC
   IF @cSKU IS NOT NULL OR
      @cUCC IS NOT NULL
   BEGIN
      -- Move QTYAllocated (ung01)
      IF (@cMoveQTYAlloc = '1' AND @nLLI_Alloc > 0 AND @nQTYAlloc > 0) OR
         (@cMoveQTYPick  = '1' AND @nLLI_Pick  > 0 AND @nQTYPick  > 0)
      BEGIN
         EXEC rdt.rdt_Move_PickDetail @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cMoveQTYAlloc, @cMoveQTYPick
            ,@cLOT       -- FromLOT
            ,@cLOC       -- FromLOC
            ,@cID        -- FromID
            ,@cToLOC
            ,@cToID      -- NULL means not changing ID. Blank ID is a valid ID
            ,@cSKU       -- Either SKU or UCC only
            ,@cUCC       --
            ,@nBal_Avail   -- For move by SKU or UCC, QTY must have value
            ,@nBal_Alloc
            ,@nBal_Pick
            ,@nLLI_QTY
            ,@nLLI_Alloc
            ,@nLLI_Pick
            ,@nPD_Alloc    OUTPUT
            ,@nPD_Pick     OUTPUT
            ,@cMoveRefKey  OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
            ,@cTaskDetailKey = @cTaskDetailKey
            ,@cOrderKey      = @cOrderKey
            ,@cDropID        = @cDropID
            ,@cCaseID        = @cCaseID
         IF @nErrNo <> 0
            GOTO RollBackTran

         IF @cMoveQTYAlloc = '1'
            SET @nQTY_Move = @nQTY_Move + @nPD_Alloc
         IF @cMoveQTYPick = '1'
            SET @nQTY_Move = @nQTY_Move + @nPD_Pick
      END

      IF @nLLI_Avail > @nBal_Avail
         SET @nQTY_Avail = @nBal_Avail
      ELSE
         SET @nQTY_Avail = @nLLI_Avail

      SET @nQTY_Move = @nQTY_Move + @nQTY_Avail
   END

   IF @nQTY_Move > 0
   BEGIN
      -- Move LOTxLOCxID
      EXEC dbo.nspItrnAddMove
           @n_ItrnSysId     = NULL          -- int
         , @c_StorerKey     = @cStorerKey   -- NVARCHAR(15)
         , @c_Sku           = @cLLI_SKU     -- NVARCHAR(20)
         , @c_Lot           = @cLOT         -- NVARCHAR(10)
         , @c_FromLoc       = @cLOC         -- NVARCHAR(10)
         , @c_FromID        = @cID          -- NVARCHAR(18)
         , @c_ToLoc         = @cToLoc       -- NVARCHAR(10)
         , @c_ToID          = @cToIDForItrn -- NVARCHAR(18)
         , @c_Status        = ''            -- NVARCHAR(10)
         , @c_lottable01    = ''            -- NVARCHAR(18)
         , @c_lottable02    = ''            -- NVARCHAR(18)
         , @c_lottable03    = ''            -- NVARCHAR(18)
         , @d_lottable04    = ''            -- datetime
         , @d_lottable05    = ''            -- datetime
         , @n_casecnt       = 0             -- int
         , @n_innerpack     = 0             -- int
         , @n_qty           = @nQTY_Move    -- int
         , @n_pallet        = 0             -- int
         , @f_cube          = 0             -- float
         , @f_grosswgt      = 0             -- float
         , @f_netwgt        = 0             -- float
         , @f_otherunit1    = 0             -- float
         , @f_otherunit2    = 0             -- float
         , @c_SourceKey     = ''            -- NVARCHAR(20)
         , @c_SourceType    = @cSourceType  -- NVARCHAR(30)
         , @c_PackKey       = @cPackKey     -- NVARCHAR(10)
         , @c_UOM           = @cPackUOM3    -- NVARCHAR(10)
         , @b_UOMCalc       = 1             -- int
         , @d_EffectiveDate = ''            -- datetime
         , @c_itrnkey       = @cItrnKey OUTPUT -- NVARCHAR(10)   OUTPUT
         , @b_Success       = @b_Success    -- int        OUTPUT
         , @n_err           = @nErrNo       -- int        OUTPUT
         , @c_errmsg        = @cErrMsg      -- NVARCHAR(250)  OUTPUT
         , @c_MoveRefKey    = @cMoveRefKey
         , @c_Channel       = @cChannel     -- NVARCHAR(20)
         , @n_Channel_ID    = @nChannel_ID  -- BIGINT

      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END

      -- Update UCC
      IF EXISTS (SELECT TOP 1 1
         FROM dbo.UCC WITH (NOLOCK, INDEX(IDX_UCC_LOTxLOCxID))
         WHERE StorerKey = @cStorerKey
            AND LOT = @cLOT
            AND LOC = @cLOC
            AND ID  = @cID
            -- AND Status = '1') -- Received
            AND Status IN ('1', '4', @cUCCAllocStatus, @cUCCPickStatus) -- Received, Replenish, Allocated
            AND Status <> '')
         AND @cSKU IS NULL    -- Exclude Move by SKU here, coz it update to LOTxLOCxID only
      BEGIN
         -- Get affected UCC
         -- Break the statement into 2 and forced to use index hint to prevent perfomance issue
         IF ISNULL(@cUCC, '') <> ''
            SET @curUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT UCCNo
               FROM dbo.UCC WITH (NOLOCK, INDEX(IDX_UCC_LOTxLOCxID))
               WHERE StorerKey = @cStorerKey
                  AND LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID  = @cID
                  AND UCCNo = @cUCC -- If move an UCC only
                  AND Status IN ('1', '4', @cUCCAllocStatus, @cUCCPickStatus) -- Received, Replenish, Allocated
                  AND Status <> ''
         ELSE
            SET @curUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT UCCNo
               FROM dbo.UCC WITH (NOLOCK, INDEX(IDX_UCC_LOTxLOCxID))
               WHERE StorerKey = @cStorerKey
                AND LOT = @cLOT
                AND LOC = @cLOC
                AND ID  = @cID
               AND Status IN ('1', '4', @cUCCAllocStatus, @cUCCPickStatus) -- Received, Replenish, Allocated
               AND Status <> ''

   --   remarked by James on 02-04-2008
   --      SET @curUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --         SELECT UCCNo
   --         FROM dbo.UCC (NOLOCK)
   --         WHERE StorerKey = @cStorerKey
   --            AND LOT = @cLOT
   --            AND LOC = @cLOC
   --            AND ID  = @cID
   --            AND UCCNo = CASE WHEN @cUCC IS NULL THEN UCCNo ELSE @cUCC END -- If move an UCC only
   --            AND Status = 1 -- Received

         OPEN @curUCC
         FETCH NEXT FROM @curUCC INTO @cUCC_ToUpd

         -- Loop UCC
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get LocationType
            SELECT @cToLocType = SL.LocationType
            FROM dbo.SKUxLOC SL (NOLOCK)
            WHERE SL.StorerKey = @cStorerKey
               AND SL.SKU = @cLLI_SKU
               AND SL.LOC = @cToLOC

            /*
            -- Note: nspITrnAddMoveCheck will always insert into SKUxLOC, if not found
            IF @@ROWCOUNT = 0
               SELECT @cToLocType = LOC.LocationType
               FROM dbo.LOC LOC (NOLOCK)
               WHERE LOC.LOC = @cToLOC
            */

            -- Update UCC
            UPDATE dbo.UCC WITH (ROWLOCK) SET
               LOC = @cToLOC,
               ID = CASE
                     WHEN @cLoseID = '1' THEN '' -- Lose ID
                     WHEN @cToID IS NULL THEN ID -- ID not change
                     ELSE @cToID
                     END,
               -- Lose UCC. Status 5=Picked/Repl
               Status = CASE WHEN (@cToLocType = 'PICK' OR @cToLocType = 'CASE')  THEN '5'
                             WHEN @cLoseUCC = '1' THEN '6' -- (ChewKP02)
                             ELSE Status
                        END,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE(),
               TrafficCop = NULL
            WHERE StorerKey = @cStorerKey
               AND LOT = @cLOT -- (ung02). Support multi SKU UCC
               AND LOC = @cLOC -- (ung02)
               AND ID  = @cID  -- (ung02)
               AND UCCNo = @cUCC_ToUpd
               AND Status IN ('1', '4', @cUCCAllocStatus, @cUCCPickStatus) -- Received, Replenish, Allocated 
               AND Status <> ''
           IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 60537
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd UCC fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curUCC INTO @cUCC_ToUpd
         END
         CLOSE @curUCC
         DEALLOCATE @curUCC
      END

      -- Reduce booking (QTYReplen) after QTY moved out
      IF @nQTYReplen > 0 AND
         @nLLI_Replen > 0 AND
         @nQTY_Avail > 0
      BEGIN
         IF @nQTYReplen > @nQTY_Avail
            SET @nQTY_Replen = @nQTY_Avail

         IF @nQTYReplen > @nLLI_Replen
            SET @nQTY_Replen = @nLLI_Replen
         ELSE
            SET @nQTY_Replen = @nQTYReplen

-- if suser_sname() = 'wmsgt'
--    select @nQTYReplen '@nQTYReplen', @nQTY_Move '@nQTY_Move', @nLLI_Replen '@nLLI_Replen', @nQTY_Replen '@nQTY_Replen'

         UPDATE LOTxLOCxID WITH (ROWLOCK)
         SET
            QTYReplen = QTYReplen - @nQTY_Replen
         WHERE LOT = @cLOT
            AND LOC = @cLOC
            AND ID = @cID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60544
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd LLI fail
            GOTO RollBackTran
         END
      END

      -- Record individual UCC movement
      IF @cUCC IS NOT NULL
      BEGIN
         EXEC [RDT].[rdt_ItrnUCCAdd]
            @nMobile       = @nMobile,
            @nFunc         = @nFunc,
            @cLangCode     = @cLangCode,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cSourceType   = @cSourceType,
            @cUCC          = @cUCC,
            @cSKU          = @cSKU,
            @nQTY          = @nQTY,
            @cFromStatus   = @cFromStatus,
            @cToStatus     = @cToStatus,
            @cFromLOT      = @cFromLOT,
            @cFromLOC      = @cFromLOC,
            @cFromID       = @cFromID,
            @cToLOC        = @cToLOC,
            @cToID         = @cToID,
            @cItrnKey      = @cItrnKey,
            @tItrnUCCVar   = @tItrnUCCVar,
            @nErrNo        = @nErrNo      OUTPUT,
            @cErrMsg       = @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Move by SKU or UCC
      IF @cSKU IS NOT NULL OR
         @cUCC IS NOT NULL
      BEGIN
         -- Reduce balance
         SET @nBal_Avail  = @nBal_Avail  - @nQTY_Avail
         SET @nBal_Alloc  = @nBal_Alloc  - @nPD_Alloc
         SET @nBal_Pick   = @nBal_Pick   - @nPD_Pick
         SET @nBal_Replen = @nBal_Replen - @nQTY_Replen
--select @nBal_Avail '@nBal_Avail', @nBal_Alloc '@nBal_Alloc', @nPD_Pick '@nPD_Pick', @nBal_Replen '@nBal_Replen'

         IF @nBal_Avail  = 0 AND
            @nBal_Alloc  = 0 AND
            @nBal_Pick   = 0 AND
            @nBal_Replen = 0
            BREAK -- Quit
      END

      --SOS67842 add by James to force move by no. of record specified by parameter passed in
      IF @nMoveLoop = 1
      BEGIN
         SET @nMoveCnt = @nMoveCnt - 1   --minus loop by 1
         IF @nMoveCnt = 0
            BREAK   --exit loop if reached max no. of move count
      END



   END

   FETCH NEXT FROM @curLLI INTO @cLOT, @cLOC, @cID, @nLLI_QTY, @nLLI_Avail, @nLLI_Alloc, @nLLI_Pick, @nLLI_Replen, @cLLI_SKU, @cPackKey, @cPackUOM3
END

-- Validate not fully moved
IF @nBal_Avail  <> 0 OR
   @nBal_Alloc  <> 0 OR
   @nBal_Pick   <> 0 OR
   @nBal_Replen <> 0
BEGIN
   -- Check no QTY moved
   IF (@nBal_Avail + @nBal_Alloc + @nBal_Pick) = @nQTY
   BEGIN
      SET @nErrNo = 60538
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No QTY to move
      GOTO RollBackTran
   END

   -- Check QTYAlloc not fully moved
   IF @cMoveQTYAlloc = '1' AND @nBal_Alloc <> 0
   BEGIN
      SET @nErrNo = 60539
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAllocNoEnuf
      GOTO RollBackTran
   END

   -- Check QTYPick not fully moved
   IF @cMoveQTYPick = '1' AND @nBal_Pick <> 0
   BEGIN
      SET @nErrNo = 60540
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYPickNotEnuf
      GOTO RollBackTran
   END

   -- Check QTYReplen not fully moved
   IF @nQTYReplen > 0 AND @nBal_Replen <> 0
   BEGIN
      SET @nErrNo = 60545
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYReplnNoEnuf
      GOTO RollBackTran
   END

   -- Check after move still have balance
   IF (@nBal_Avail + @nBal_Alloc + @nBal_Pick) < @nQTY
   BEGIN
      SET @nErrNo = 60541
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAvalNotEnuf
      GOTO RollBackTran
   END
END

COMMIT TRAN rdt_Move -- Only commit change made in rdt_Move
GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Move -- Only rollback change made in rdt_Move
Quit:
   -- Commit until the level we started
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
Fail:

GO