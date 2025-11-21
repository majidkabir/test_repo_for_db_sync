SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1813ExtValid03                                  */
/* Purpose: Move By ID Extended Validate                                */
/*                                                                      */
/* Called from: rdtfnc_PalletConsolidate                                */
/*              Modified from rdt_1813ExtValid01                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 13-09-2018 1.0  James      WMS6203 - Created                         */
/* 04-10-2018 1.1  James      Add checking from/to id must from same    */
/*                            loc (james01)                             */
/************************************************************************/

CREATE PROC [RDT].[rdt_1813ExtValid03] (
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

   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cOnScreenSKU   NVARCHAR( 20)
   DECLARE @cItemClass     NVARCHAR( 10)
   DECLARE @cFromScn       NVARCHAR( 4)
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cToLOC         NVARCHAR( 10)


   SELECT @cFacility = Facility,
          @cOption = I_Field09,
          @cFromScn = V_String25,
          @cOnScreenSKU = O_Field05,
          @cFromLOC = V_LOC
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @nErrNo = 0

   IF @nInputKey = 1
   BEGIN
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
            SET @nErrNo = 129101  -- X Mv ASRS PLT
            GOTO Quit
         END
         
      END

      IF @nStep = 2
      BEGIN
         IF ISNULL( @cSKU, '') <> ''
         BEGIN
            -- Check if barcode/upc scanned exists on fromid
            -- before go to multi sku screen
            IF NOT EXISTS ( SELECT 1 
                           FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                           JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                           WHERE LLI.StorerKey = @cStorerKey
                           AND   LLI.ID = @cFromID
                           AND   LLI.LOC = @cFromLOC
                           AND   LOC.Facility = @cFacility
                           AND   SKU IN ( SELECT SKU 
                                          FROM dbo.SKU SKU WITH (NOLOCK) 
                                          WHERE SKU.StorerKey = LLI.StorerKey 
                                          AND @cSKU IN ( SKU, ALTSKU, RETAILSKU, MANUFACTURERSKU)))
            BEGIN
               SET @nErrNo = 129107  -- SKU NOT ON ID
               GOTO Quit
            END
                           
            SELECT @cItemClass = ItemClass
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   SKU = @cSKU

            IF @cItemClass <> 'POSM'
            BEGIN
               -- If sku itemclass <> 'posm' then do not accept 
               -- key in the SKU # on the screen. Only accept 
               -- scanning of UPC barcode on screen 
               IF @cSKU = @cOnScreenSKU
               BEGIN
                  SET @nErrNo = 129102  -- Key/Scan UPC
                  GOTO Quit
               END
            END
         END

         -- User want to move to next screen, check must scan upc before can proceed
         IF @cOption = '1' AND ISNULL( @cSKU, '') = ''
         BEGIN
            SELECT @cItemClass = ItemClass
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   SKU = @cOnScreenSKU

            IF @cFromScn <> '3570' AND @cItemClass <> 'POSM'
            BEGIN
               SET @nErrNo = 129103  -- Key/Scan UPC
               GOTO Quit
            END
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
            SET @nErrNo = 129104  -- X Mv ASRS PLT
            GOTO Quit
         END

         IF rdt.rdtGetConfig( @nFunc, 'NotAllowMoveToNewID', @cStorerKey) = '1'
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cToID)
            BEGIN
               SET @nErrNo = 129105  -- TO ID X EXISTS
               GOTO Quit
            END
         END

         -- Get the To LOC. Check if the To ID already have inventory
         -- If yes then take the To LOC from To ID (james01)
         SELECT TOP 1 @cToLOC = LOC.Loc 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey 
         AND   LLI.ID = @cToID 
         AND   LOC.Facility = @cFacility
         AND   QTY > 0
         ORDER BY LOC.Loc

         -- If To ID do not have inventory then no need further check
         IF ISNULL( @cToLOC, '') = ''
            GOTO Quit
         ELSE
         BEGIN
            IF @cToLOC <> @cFromLOC
            BEGIN
               SET @nErrNo = 129108  -- DIFF PLTID LOC
               GOTO Quit
            END
         END

      END

      IF @nStep = 9
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM 
                         dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                         WHERE LLI.StorerKey = @cStorerKey 
                         AND   LLI.ID = @cFromID 
                         AND   LOC.Facility = @cFacility
                         AND   SKU = @cSKU)
         BEGIN
            SET @nErrNo = 129106  -- SKU NOT ON ID
            GOTO Quit
         END
      END

   END

QUIT:

GO