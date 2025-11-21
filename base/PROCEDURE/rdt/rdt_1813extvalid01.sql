SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1813ExtValid01                                  */
/* Purpose: Move By ID Extended Validate                                */
/*                                                                      */
/* Called from: rdtfnc_PalletConsolidate                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 17-02-2015 1.0  James      SOS315975 - Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1813ExtValid01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFromID          NVARCHAR( 20), 
   @cOption          NVARCHAR( 1), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT, 
   @cToID            NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cFacility   NVARCHAR( 5)

   SELECT @cFacility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @nErrNo = 0

   IF @nInputKey = 1
   BEGIN/*
      IF @nStep = 3
      BEGIN
         -- Check if move availale qty then must move whole sku qty
         IF @cOption = '1' AND rdt.RDTGetConfig( @nFunc, 'MergePltMvPartAlvQty', @cStorerKey) <> '1'
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                        WHERE LLI.StorerKey = @cStorerKey 
                        AND   LLI.ID = @cFromID 
                        AND   LOC.Facility = @cFacility
                        AND   SKU = @cSKU
                        HAVING ( ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0) <> @nQty))
            BEGIN
               SET @nErrNo = 51701  -- Move partial sku
               GOTO Quit
            END
         END

         -- Check cannot move partial allocated qty from pallet 
         -- (if rdt config not allow move partial qty turn on)
         IF @cOption = '2' AND rdt.RDTGetConfig( @nFunc, 'MergePltMvPartAlcQty', @cStorerKey) <> '1'
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                        WHERE LLI.StorerKey = @cStorerKey 
                        AND   LLI.ID = @cFromID 
                        AND   LOC.Facility = @cFacility
                        HAVING ( ISNULL( SUM( QTYAllocated), 0) <> @nQty))     
            BEGIN
               SET @nErrNo = 51702  -- Move partial allc
               GOTO Quit
            END
         END
      END
      */

      IF @nStep = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                     WHERE LLI.StorerKey = @cStorerKey 
                     AND   LLI.ID = @cFromID 
                     AND   LOC.Facility = @cFacility
                     AND   QTY > 0
                     AND   LOC.LocationCategory = 'ASRS')
         BEGIN
            SET @nErrNo = 51701  -- X Mv ASRS PLT
            GOTO Quit
         END
         
      END

      IF @nStep IN (4, 5)
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                     WHERE LLI.StorerKey = @cStorerKey 
                     AND   LLI.ID = @cToID 
                     AND   LOC.Facility = @cFacility
                     AND   QTY > 0
                     AND   LOC.LocationCategory = 'ASRS')
         BEGIN
            SET @nErrNo = 51702  -- X Mv ASRS PLT
            GOTO Quit
         END

         IF rdt.rdtGetConfig( @nFunc, 'NotAllowMoveToNewID', @cStorerKey) = '1'
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cToID)
            BEGIN
               SET @nErrNo = 51703  -- TO ID X EXISTS
               GOTO Quit
            END
         END
      END
   END

QUIT:

GO