SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_MoveSKUSuggLoc07                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Find a friend, then find empty LOC                          */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 07-02-2017  1.0  Ung         WMS-1025 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_MoveSKUSuggLoc07] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerkey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cFromLoc      NVARCHAR( 10),
   @cFromID       NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cToID         NVARCHAR( 18),
   @cToLOC        NVARCHAR( 10),
   @cType         NVARCHAR( 10), -- LOCK/UNLOCK
   @nPABookingKey INT           OUTPUT,
	@cOutField01   NVARCHAR( 20) OUTPUT,
	@cOutField02   NVARCHAR( 20) OUTPUT,
   @cOutField03   NVARCHAR( 20) OUTPUT,
   @cOutField04   NVARCHAR( 20) OUTPUT,
   @cOutField05   NVARCHAR( 20) OUTPUT,
   @cOutField06   NVARCHAR( 20) OUTPUT,
   @cOutField07   NVARCHAR( 20) OUTPUT,
   @cOutField08   NVARCHAR( 20) OUTPUT,
   @cOutField09   NVARCHAR( 20) OUTPUT,
   @cOutField10   NVARCHAR( 20) OUTPUT,
	@cOutField11   NVARCHAR( 20) OUTPUT,
	@cOutField12   NVARCHAR( 20) OUTPUT,
   @cOutField13   NVARCHAR( 20) OUTPUT,
   @cOutField14   NVARCHAR( 20) OUTPUT,
   @cOutField15   NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSuggLOC    NVARCHAR(10)
   DECLARE @cOutput     NVARCHAR(20)
   DECLARE @i           INT
   DECLARE @nQTY_Bal    INT
   DECLARE @nQTY_FitIn  INT
   DECLARE @cLOCType    NVARCHAR(10)
   DECLARE @cPUOM       NVARCHAR( 1)
   DECLARE @nPQTY       INT -- QTY in pref UOM
   DECLARE @nMQTY       INT -- QTY in master UOM
   DECLARE @nPUOM_Div   INT

   IF @cType = 'UNLOCK'
      GOTO Quit

   IF @cType = 'LOCK'
   BEGIN
      -- Putaway only for trade return stage LOC
      IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cFromLoc AND LOC.LocationType = 'RETURN')
      BEGIN
         SET @nErrNo = -1  -- Bypass putaway
         GOTO Quit
      END
   
      SET @i = 1
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      
      SET @cSuggLOC = ''
      SET @nQTY_Bal = @nQTY
   
      -- Get login info
      SELECT 
         @cFacility = Facility, 
         @cPUOM = V_UOM
      FROM rdt.rdtMOBREC WITH (NOLOCK) 
      WHERE Mobile = @nMobile
   
      -- Get SKU info
      SELECT 
         @nPUOM_Div = CAST(
            CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END AS INT)
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
   
      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @nPQTY = 0
         SET @nMQTY = @nQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQTY / @nPUOM_Div
         SET @nMQTY = @nQTY % @nPUOM_Div
      END
         
      -- Check both UOM key-in
      IF @nPQTY > 0 AND @nMQTY > 0
      BEGIN
         SET @nErrNo = 105802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OneUOMQTYOnly
         GOTO Quit
      END
      
      -- Decide loc type
      IF @nPQTY > 0
         SET @cLOCType = 'CASE'
      ELSE
         SET @cLOCType = 'PICK'
   
      -- Find empty LOC
      SELECT TOP 1
          @cSuggLOC = LOC.LOC
      FROM dbo.LOC LOC WITH (NOLOCK)
         JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LOC.LOC <> @cFromLOC
         AND SL.LocationType = @cLOCType
         AND SL.StorerKey = @cStorerKey
         AND SL.SKU = @cSKU
      GROUP BY LOC.PALogicalLOC, LOC.LOC
      HAVING SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) = 0
      ORDER BY LOC.PALogicalLOC, LOC.LOC
   
      IF @cSuggLOC <> ''
      BEGIN
         SET @cOutField01 = @cSuggLOC
         GOTO Quit
      END
   
      -- Find a friend, fill up to QtyLocationLimit
      DECLARE @curLOC CURSOR
      SET @curLOC = CURSOR FOR
         SELECT 
             LOC.LOC, SL.QtyLocationLimit - (SL.QTY - SL.QTYPicked)
         FROM dbo.LOC LOC WITH (NOLOCK)
            JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND SL.LocationType = @cLOCType
            AND SL.StorerKey = @cStorerKey
            AND SL.SKU = @cSKU
            AND LOC.LOC <> @cFromLOC
            AND SL.QTY - SL.QTYPicked > 0 
            AND SL.QtyLocationLimit - (SL.QTY - SL.QTYPicked) > 0 
         ORDER BY 
            SL.QtyLocationLimit - (SL.QTY - SL.QTYPicked), 
            LOC.PALogicalLOC, 
            LOC.LOC
            
      OPEN @curLOC
      FETCH NEXT FROM @curLOC INTO @cSuggLOC, @nQTY_FitIn
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cOutput = @cSuggLOC + RIGHT( SPACE(10) + RTRIM( CAST( @nQTY_FitIn AS NVARCHAR(10))), 10)
   
         IF @i = 1 SET @cOutField01 = @cOutput ELSE
         IF @i = 2 SET @cOutField02 = @cOutput ELSE
         IF @i = 3 SET @cOutField03 = @cOutput ELSE
         IF @i = 4 SET @cOutField04 = @cOutput ELSE
         IF @i = 5 SET @cOutField05 = @cOutput ELSE
         IF @i = 5 SET @cOutField06 = @cOutput 
   
         SET @i = @i + 1
         SET @nQTY_Bal = @nQTY_Bal - @nQTY_FitIn
         
         IF @i > 6 OR @nQTY_Bal <= 0
            BREAK
   
         FETCH NEXT FROM @curLOC INTO @cSuggLOC, @nQTY_FitIn
      END
   
      -- Check no suggest loc
      IF @cOutField01 = ''
      BEGIN
         SET @nErrNo = 105801
         SET @cOutField01 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoSuggestedLOC
         SET @nErrNo = 0
         GOTO Quit
      END
   END
   
Quit:

END

GO