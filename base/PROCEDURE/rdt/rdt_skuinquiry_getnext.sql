SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SKUInquiry_GetNext                              */
/*                                                                      */
/* Purpose: Get next SKU and/or LOC                                     */
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
/* Date       Rev  Author     Purposes                                  */
/* 2011-06-20 1.0  Ung        Created                                   */
/* 2012-10-05 1.1  ChewKP     SOS#257455 - Recreate Message (ChewKP01)  */ 
/* 2016-08-11 1.2  James      SOS375234 - Handle NULL value (james01)   */
/* 2016-09-29 1.3  Ung        Performance tuning                        */
/* 2022-01-05 1.4  James      WMS-18570 Add custom getnext sp (james02) */
/************************************************************************/

CREATE   PROC [RDT].[rdt_SKUInquiry_GetNext] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15), 
   @cFacility     NVARCHAR( 5), 
   @cInquiry_SKU  NVARCHAR( 20), 
   @cInquiry_LOC  NVARCHAR( 10), 
   @cCurrentSKU   NVARCHAR( 20), 
   @cCurrentLOC   NVARCHAR( 10), 
   @cNextSKU      NVARCHAR( 20) OUTPUT, 
   @cNextLOC      NVARCHAR( 10) OUTPUT, 
   @cSKUDescr     NVARCHAR( 60) OUTPUT, 
   @cCaseUOM      NVARCHAR( 5)  OUTPUT,
   @cEachUOM      NVARCHAR( 5)  OUTPUT, 
   @cQTYOnHand    NVARCHAR( 20) OUTPUT, 
   @cQTYAvailable NVARCHAR( 20) OUTPUT, 
   @cCS_PL        NVARCHAR( 5)  OUTPUT, 
   @cEA_CS        NVARCHAR( 5)  OUTPUT, 
   @cMin          NVARCHAR( 5)  OUTPUT, 
   @cMax          NVARCHAR( 5)  OUTPUT,
   @nRec          INT OUTPUT, 
   @nTotRec       INT OUTPUT, 
   @nErrNo        INT OUTPUT, 
   @cErrMsg       NVARCHAR( 125) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cSQL                       NVARCHAR( MAX)
   DECLARE @cSQLParam                  NVARCHAR( MAX)
   DECLARE @cSKUInquiry_GetNextRecSP   NVARCHAR( 20)
   
   -- Get storer config
   SET @cSKUInquiry_GetNextRecSP = rdt.rdtGetConfig( @nFunc, 'SKUInquiry_GetNextRecSP', @cStorerKey)
   IF @cSKUInquiry_GetNextRecSP = '0'
      SET @cSKUInquiry_GetNextRecSP = ''  

   /***********************************************************************************************
                                     Custom Matrix
   ***********************************************************************************************/
   IF @cSKUInquiry_GetNextRecSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSKUInquiry_GetNextRecSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSKUInquiry_GetNextRecSP) +
            ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility,  ' + 
            ' @cInquiry_SKU, @cInquiry_LOC, @cCurrentSKU, @cCurrentLOC, @cNextSKU OUTPUT, @cNextLOC OUTPUT, ' + 
            ' @cSKUDescr OUTPUT, @cCaseUOM OUTPUT, @cEachUOM OUTPUT, @cQTYOnHand OUTPUT, @cQTYAvailable OUTPUT, ' +
            ' @cCS_PL OUTPUT, @cEA_CS OUTPUT, @cMin OUTPUT, @cMax OUTPUT, @nRec OUTPUT, @nTotRec OUTPUT, '+
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,                    ' +
            '@nFunc           INT,                    ' +
            '@cLangCode       NVARCHAR( 3),           ' +
            '@cStorerKey      NVARCHAR( 15),          ' +
            '@cFacility       NVARCHAR( 5),           ' +
            '@cInquiry_SKU    NVARCHAR( 20),          ' +
            '@cInquiry_LOC    NVARCHAR( 10),          ' +
            '@cCurrentSKU     NVARCHAR( 20),          ' +
            '@cCurrentLOC     NVARCHAR( 10),          ' +
            '@cNextSKU        NVARCHAR( 20) OUTPUT,   ' + 
            '@cNextLOC        NVARCHAR( 10) OUTPUT,   ' +
            '@cSKUDescr       NVARCHAR( 60) OUTPUT,   ' +
            '@cCaseUOM        NVARCHAR( 5)  OUTPUT,   ' +
            '@cEachUOM        NVARCHAR( 5)  OUTPUT,   ' +
            '@cQTYOnHand      NVARCHAR( 20) OUTPUT,   ' +
            '@cQTYAvailable   NVARCHAR( 20) OUTPUT,   ' +
            '@cCS_PL          NVARCHAR( 5)  OUTPUT,   ' +
            '@cEA_CS          NVARCHAR( 5)  OUTPUT,   ' +
            '@cMin            NVARCHAR( 5)  OUTPUT,   ' +
            '@cMax            NVARCHAR( 5)  OUTPUT,   ' +
            '@nRec            INT OUTPUT,             ' +
            '@nTotRec         INT OUTPUT,             ' +
            '@nErrNo          INT           OUTPUT,   ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT    '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility,  
            @cInquiry_SKU, @cInquiry_LOC, @cCurrentSKU, @cCurrentLOC, @cNextSKU OUTPUT, @cNextLOC OUTPUT, 
            @cSKUDescr OUTPUT, @cCaseUOM OUTPUT, @cEachUOM OUTPUT, @cQTYOnHand OUTPUT, @cQTYAvailable OUTPUT, 
            @cCS_PL OUTPUT, @cEA_CS OUTPUT, @cMin OUTPUT, @cMax OUTPUT, @nRec OUTPUT, @nTotRec OUTPUT, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END
   
   /***********************************************************************************************
                              Standard Get Next SKU Inquiry record
   ***********************************************************************************************/
   DECLARE @nQtyAvailable INT
   DECLARE @nQtyOnHand    INT
   DECLARE @nQtyOnHold    INT
   DECLARE @nQtyAllocated INT
   DECLARE @nMin          INT
   DECLARE @nMax          INT
   DECLARE @nCaseCnt      INT
   DECLARE @nPalletCnt    INT
   DECLARE @curSL         CURSOR
   DECLARE @curSKU        NVARCHAR( 20)
   DECLARE @curLOC        NVARCHAR( 10)
   DECLARE @curMin        INT
   DECLARE @curMax        INT

   SET @cNextLOC = ''
   SET @cNextSKU = ''
   SET @nMin = 0
   SET @nMax = 0
   SET @nRec = 0
   SET @nTotRec = 0
   SET @cInquiry_SKU = ISNULL( @cInquiry_SKU, '')  -- (james01)
   SET @cInquiry_LOC = ISNULL( @cInquiry_LOC, '')  -- (james01)

   -- Get SKUxLOC record (possible no record)
   IF @cInquiry_SKU <> ''
      SET @curSL = CURSOR STATIC FORWARD_ONLY READ_ONLY FOR  -- STATIC is required for @@CURSOR_ROWS below
         SELECT SKU.SKU, LOC.LOC, SL.QTYLocationMinimum, SL.QTYLocationLimit
         FROM dbo.SKU WITH (NOLOCK)
            INNER JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.StorerKey = SKU.StorerKey AND SL.SKU = SKU.SKU)
            INNER JOIN dbo.LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE SKU.StorerKey = @cStorerKey
            AND SL.LocationType IN ('PICK', 'CASE')
            AND LOC.Facility = @cFacility
            AND SKU.SKU = @cInquiry_SKU
         ORDER BY SKU.SKU, LOC.LOC

   IF @cInquiry_LOC <> ''
      SET @curSL = CURSOR STATIC FORWARD_ONLY READ_ONLY FOR  -- STATIC is required for @@CURSOR_ROWS below
         SELECT SKU.SKU, LOC.LOC, SL.QTYLocationMinimum, SL.QTYLocationLimit
         FROM dbo.SKU WITH (NOLOCK)
            INNER JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.StorerKey = SKU.StorerKey AND SL.SKU = SKU.SKU)
            INNER JOIN dbo.LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE SKU.StorerKey = @cStorerKey
            AND SL.LocationType IN ('PICK', 'CASE')
            AND LOC.Facility = @cFacility
            AND LOC.LOC = @cInquiry_LOC
         ORDER BY SKU.SKU, LOC.LOC

   OPEN @curSL
   FETCH NEXT FROM @curSL INTO @curSKU, @curLOC, @curMin, @curMax
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @nRec = @nRec + 1
      SET @cNextSKU = @curSKU
      SET @cNextLOC = @curLOC
      SET @nMin = @curMin
      SET @nMax = @curMax
   
      -- Inquiry by loc
      IF @cInquiry_LOC <> '' AND @cNextSKU > @cCurrentSKU
         BREAK
      -- Inquiry by SKU
      IF @cInquiry_SKU <> '' AND @cNextLOC > @cCurrentLOC
         BREAK
      
      FETCH NEXT FROM @curSL INTO @curSKU, @curLOC, @curMin, @curMax
   END
   SET @nTotRec = @@CURSOR_ROWS 
   CLOSE @curSL
   DEALLOCATE @curSL

   IF @cNextSKU = '' 
      SET @cNextSKU = @cInquiry_SKU

   -- Get SKU info
   SELECT 
      @cSKUDescr = SKU.DESCR,
      @nCaseCnt = CAST( PACK.CaseCnt AS INT),
      @nPalletCnt = CAST( PACK.Pallet AS INT),
      @cCaseUOM = RTRIM( PACK.PACKUOM1),
      @cEachUOM = RTRIM( PACK.PACKUOM3)
   FROM dbo.SKU WITH (NOLOCK) 
      INNER JOIN dbo.PACK WITH (NOLOCK) ON (PACK.PackKey = SKU.PackKey)
   WHERE SKU.StorerKey = @cStorerKey
      AND SKU.SKU = CASE WHEN @cInquiry_SKU <> '' THEN @cInquiry_SKU ELSE @cNextSKU END --(By LOC)

   -- Get QTY on hold
   SELECT @nQtyOnHold = ISNULL(SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked
                       - (CASE WHEN LOTxLOCxID.QtyReplen < 0 THEN 0 ELSE LOTxLOCxID.QtyReplen END)),0)
   FROM  dbo.LOT LOT WITH (NOLOCK)
   JOIN dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK) ON LOT.lot = LOTxLOCxID.lot
   JOIN dbo.LOC LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc
   WHERE LOT.Status = 'HOLD'
   AND   LOT.StorerKey = @cStorerKey
   AND   LOC.Facility = RTRIM( @cFacility)
   AND   LOT.SKU = RTRIM( @cNextSKU)

   SELECT  @nQtyOnHold = @nQtyOnHold + ISNULL(SUM(LOTxLOCxID.qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked
                        - (CASE WHEN LOTxLOCxID.QtyReplen < 0 THEN 0 ELSE LOTxLOCxID.QtyReplen END)),0)
   FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
   JOIN dbo.LOT LOT WITH (NOLOCK) on LOT.lot = LOTxLOCxID.lot
   JOIN dbo.LOC LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc
   JOIN dbo.ID ID WITH (NOLOCK) on LOTxLOCxID.id = ID.id
   WHERE LOT.Status <> 'HOLD'
   AND (LOC.locationFlag = 'HOLD' OR LOC.Status = 'HOLD' OR LOC.locationFlag = 'DAMAGE') -- (Vanessa01)
   AND ID.Status = 'OK'
   AND LOTxLOCxID.StorerKey = @cStorerKey
   AND LOTxLOCxID.SKU = RTRIM( @cNextSKU)
   AND LOC.Facility = RTRIM( @cFacility)
   HAVING SUM(LOTxLOCxID.qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0

   SELECT  @nQtyOnHold = @nQtyOnHold + ISNULL(SUM(LOTxLOCxID.qty - LOTxLOCxID.QtyAllocated
      - LOTxLOCxID.QtyPicked - (CASE WHEN LOTxLOCxID.QtyReplen < 0 THEN 0 ELSE LOTxLOCxID.QtyReplen END)),0)
   FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
   JOIN dbo.LOT LOT WITH (NOLOCK) on LOT.lot = LOTxLOCxID.lot
   JOIN dbo.LOC LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc
   JOIN dbo.ID ID WITH (NOLOCK) on LOTxLOCxID.id = ID.id
   WHERE LOT.Status <> 'HOLD'
   --AND (LOC.locationFlag <> 'HOLD' AND LOC.Status <> 'HOLD' AND LOC.locationFlag <> 'DAMAGE') -- (Vanessa02)
   AND ID.Status = 'HOLD'
   AND LOTxLOCxID.StorerKey = @cStorerKey
   AND LOTxLOCxID.SKU = RTRIM( @cNextSKU)
   AND LOC.Facility = RTRIM( @cFacility)
   HAVING SUM(LOTxLOCxID.qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0

   -- Get QTY on hand
   SELECT @nQtyOnHand = SUM(Qty),
          @nQtyAllocated = SUM(QtyAllocated + QtyPicked + (CASE WHEN LOTxLOCxID.QtyReplen < 0 THEN 0 ELSE LOTxLOCxID.QtyReplen END))
   FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc
   WHERE StorerKey = @cStorerKey
   AND SKU = RTRIM( @cNextSKU)
   AND LOC.Facility = RTRIM( @cFacility)

   -- Calc output
   SET @nQtyAvailable = @nQtyOnHand - ISNULL( @nQtyAllocated, 0) - ISNULL( @nQtyOnHold, 0)
   SET @cEA_CS = @nCaseCnt

   IF @nCaseCnt > 0
   BEGIN
      SET @cQtyOnHand = CAST( FLOOR( @nQtyOnHand / @nCaseCnt) AS NVARCHAR( 5)) + ' ' + @cCaseUOM + ' ' +
                        CAST( @nQtyOnHand % @nCaseCnt AS NVARCHAR( 5)) + ' ' + @cEachUOM
      SET @cQTYAvailable = CAST( FLOOR( @nQtyAvailable / @nCaseCnt) AS NVARCHAR( 5)) + ' ' + @cCaseUOM + ' ' +
                           CAST( @nQtyAvailable % @nCaseCnt AS NVARCHAR( 5)) + ' ' + @cEachUOM
      SET @cCS_PL = CAST( FLOOR( @nPalletCnt / @nCaseCnt) AS NVARCHAR( 5)) -- CS/PL
      SET @cMin = CAST( FLOOR( @nMin / @nCaseCnt) AS NVARCHAR( 5)) -- min
      SET @cMax = CAST( FLOOR( @nMax / @nCaseCnt) as NVARCHAR( 5)) -- max
      SET @cCaseUOM = @cCaseUOM
   END
   ELSE
   BEGIN
      SET @cQtyOnHand = CAST( @nQtyOnHand AS NVARCHAR(10)) + ' ' + @cEachUOM
      SET @cQTYAvailable = CAST( @nQtyAvailable AS NVARCHAR(10)) + ' ' + @cEachUOM
      SET @cCS_PL = @nPalletCnt
      SET @cMin = @nMin
      SET @cMax = @nMax
      SET @cCaseUOM = @cEachUOM
   END

   -- Error message
   IF @cInquiry_SKU <> '' AND @nTotRec = 0
   BEGIN
      SET @nErrNo = 77551  -- (ChewKP01)
      SET @cErrMsg = rdt.rdtgetmessage( 77551, @cLangCode, 'DSP') --No pick LOC -- (ChewKP01)
   END

   IF @cInquiry_LOC <> '' AND @nTotRec = 0
   BEGIN
      IF (SELECT ISNULL( SUM( QTY), 0) 
         FROM SKUxLOC SL WITH (NOLOCK) 
            INNER JOIN LOC WITH (NOLOCK) ON (LOC.LOC = SL.LOC)
         WHERE SL.StorerKey = @cStorerKey
            AND LOC.Facility = @cFacility
            AND LOC.LOC = @cInquiry_LOC) = 0
      BEGIN
         SET @nErrNo = 77552 -- (ChewKP01)
         SET @cErrMsg = rdt.rdtgetmessage( 77552, @cLangCode, 'DSP') --Empty, NoPKLOC -- (ChewKP01)
      END
      ELSE
      BEGIN
         SET @nErrNo = 77553 -- (CheWKP01)
         SET @cErrMsg = rdt.rdtgetmessage( 77553, @cLangCode, 'DSP') --No pick LOC -- (ChewKP01)
      END
   END
   
   Quit:

GO