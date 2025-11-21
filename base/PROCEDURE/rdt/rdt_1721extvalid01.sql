SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1721ExtValid01                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Move                                      */
/*                                                                      */
/* Purpose: Check ID                                                    */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2024-11-28  1.0  CYU027   FCR-1391 Levis                              */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1721ExtValid01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @cFacility         NVARCHAR( 15),
   @cStorer         NVARCHAR( 15),
   @cID             NVARCHAR( 20),
   @cToLOC          NVARCHAR( 10),
   @cSuggestLoc     NVARCHAR( 15),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN

   DECLARE @cLocationOverride    NVARCHAR( 20)
   DECLARE @cPutawayZone         NVARCHAR (10)
   DECLARE @nTotalPallet         INT
   DECLARE @nMaxPallet           INT

   IF @nStep = 2
   BEGIN
      SET @cLocationOverride = rdt.RDTGetConfig( @nFunc, 'LocationOverride', @cStorer)
      IF @cLocationOverride = '0'
         SET @cLocationOverride = ''

      --override suggest loc
      IF ISNULL(@cSuggestLoc,'') <>'' AND @cLocationOverride <> '1' AND @cSuggestLoc <> @cToLOC
      BEGIN
         SET @nErrNo = 229902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CannotOverride
         GOTO Quit
      END

      SELECT @cPutawayZone = PutawayZone FROM LOC( NOLOCK)
         WHERE LOC = @cToLOC

      IF ISNULL(@cPutawayZone,'') <> 'OBSTG'
      BEGIN
         SET @nErrNo = 229904
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LocNotOBSTG
         GOTO Quit
      END

      SELECT @nTotalPallet = COUNT(DISTINCT (LLI.ID))
      FROM LOTxLOCxID LLI (NOLOCK )
              INNER JOIN LOC L (NOLOCK ) ON LLI.loc = L.Loc
              INNER JOIN PalletDetail P (NOLOCK ) ON  P.palletkey = LLI.ID
      WHERE L.loc = @cToLOC
        AND P.Storerkey = @cStorer
        AND ISNULL(LLI.ID, '') <> ''
        AND P.status < 9
      GROUP BY L.Loc, L.MaxPallet

      SELECT @nMaxPallet = MaxPallet FROM LOC(NOLOCK ) WHERE Loc = @cToLOC

      IF( @nMaxPallet <= @nTotalPallet )
      BEGIN
         SET @nErrNo = 229903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LocationFull
         GOTO Quit
      END
   END




   Quit:


END

GO