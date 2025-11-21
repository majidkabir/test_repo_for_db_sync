SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1813ExtValid04                                  */
/* Purpose: Move By ID Extended Validate                                */
/*                                                                      */
/* Called from: rdtfnc_PalletConsolidate                                */
/*              Modified from rdt_1813ExtValid03                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 18-12-2018 1.0  ChewKP     WMS-7282 - Created                        */
/* 19-09-2019 1.1  James      WMS- Allow ASRS pallet to merge (james01) */
/* 12-10-2023 1.2  Luke       JSM-181509 Add LLI.QTY > 0 to retrieve the*/ 
/*                                       vaild qty                      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1813ExtValid04] (
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
          ,@cProductModel  NVARCHAR( 30)
          ,@cPQty          NVARCHAR(5)
          ,@cMQty          NVARCHAR(5)
          ,@cLocationCategory NVARCHAR( 10)

   DECLARE @nLLI_Qty       INT
   DECLARE @nLLI_QtyAlloc  INT
   DECLARE @nLLI_QtyPick   INT
   DECLARE @nToID_Qty       INT
   DECLARE @nToID_QtyAlloc  INT
   DECLARE @nToID_QtyPick   INT

   SELECT @cFacility = Facility,
          @cOption = I_Field09,
          @cFromScn = V_String25,
          @cOnScreenSKU = O_Field05,
          @cFromLOC = V_LOC,
          @cPQTY    = I_Field08,
          @cMQTY    = I_Field13
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @nErrNo = 0

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         -- (james01)
         SELECT @nLLI_Qty  = ISNULL( SUM( Qty), 0),
                @nLLI_QtyAlloc  = ISNULL( SUM( QtyAllocated), 0),
                @nLLI_QtyPick  = ISNULL( SUM( QtyPicked), 0),
                @cLocationCategory = LOC.LocationCategory
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey 
         AND   LLI.ID = @cFromID 
         AND   LOC.Facility = @cFacility
         AND   QTY > 0
         GROUP BY LOC.LocationCategory

         IF @cLocationCategory <> 'STAGING'
         BEGIN
            SET @nErrNo = 133212  -- Need Staging
            GOTO Quit
         END

         IF (@nLLI_QtyAlloc + @nLLI_QtyPick) > 0 AND 
            NOT EXISTS ( SELECT 1 FROM rdt.rdtPPA WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey
                         AND ID = @cFromID )
         BEGIN
            SET @nErrNo = 133211  -- InvalidID
            GOTO Quit
         END

         IF (@nLLI_QtyAlloc + @nLLI_QtyPick) > 0 AND
            EXISTS ( SELECT 1 FROM rdt.rdtPPA WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   ID = @cFromID
                     AND   ISNULL(OrderKey,'') = '' ) 
         BEGIN
            SET @nErrNo = 133201  -- InvalidID
            GOTO Quit
         END
         /*
      -- Check if from pallet is ASRS pallet (with available qty)
         IF @nLLI_Qty > 0 AND @cLocationCategory = 'ASRS'
         BEGIN
            -- If from pallet do not have any alloc or pick qty, allow merge
            --IF (@nLLI_QtyAlloc + @nLLI_QtyPick) > 0
            --BEGIN
               SET @nErrNo = 133202  -- X Mv ASRS PLT
               GOTO Quit
            --END
         END
         ELSE  -- Not ASRS pallet, check if it is already been audit. If yes, allow merge
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPPA WITH (NOLOCK) 
                            WHERE StorerKey = @cStorerKey
                            AND ID = @cFromID ) AND @nLLI_QtyPick = 0
            BEGIN
               SET @nErrNo = 133211  -- InvalidID
               GOTO Quit
            END
         
            IF EXISTS ( SELECT 1 FROM rdt.rdtPPA WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND ID = @cFromID
                            AND ISNULL(OrderKey,'') = '' ) 
            BEGIN
               SET @nErrNo = 133201  -- InvalidID
               GOTO Quit
            END
         END
         */
      END

      IF @nStep = 3
      BEGIN
         IF ISNULL( @cSKU, '') <> ''
         BEGIN
            SELECT @cProductModel = ProductModel 
            FROM dbo.SKU WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU 

            IF @cProductModel = 'COPACK'
            BEGIN
               IF ISNULL(@cPQTY,'')  <> '' 
               BEGIN
                  SET @nErrNo = 133210  -- CopackItemKeyInBT
                  GOTO Quit
               END
            END
            
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
               SET @nErrNo = 133203  -- SKU NOT ON ID
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
                  SET @nErrNo = 133204  -- Key/Scan UPC
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
               SET @nErrNo = 133205  -- Key/Scan UPC
               GOTO Quit
            END
         END
      END

      IF @nStep IN (4, 5)
      BEGIN
         -- (james01)
         SELECT @nToID_Qty  = ISNULL( SUM( Qty), 0),
                @nToID_QtyAlloc  = ISNULL( SUM( QtyAllocated), 0),
                @nToID_QtyPick  = ISNULL( SUM( QtyPicked), 0),
                @cLocationCategory = LOC.LocationCategory
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey 
         AND   LLI.ID = @cToID 
         AND   LOC.Facility = @cFacility
         GROUP BY LOC.LocationCategory

         SELECT @nLLI_Qty  = ISNULL( SUM( Qty), 0),
                @nLLI_QtyAlloc  = ISNULL( SUM( QtyAllocated), 0),
                @nLLI_QtyPick  = ISNULL( SUM( QtyPicked), 0)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey 
         AND   LLI.ID = @cFromID 
         AND   LOC.Facility = @cFacility
		 AND   LLI.QTY > '0' --Luke
         GROUP BY LOC.LocationCategory

         IF @nToID_Qty > 0 AND @cLocationCategory <> 'STAGING'
         BEGIN
            SET @nErrNo = 133213  -- Need Staging
            GOTO Quit
         END      
         /*
         IF ( @nLLI_QtyAlloc + @nLLI_QtyPick) > 0 AND @nToID_Qty > 0
         BEGIN
            SET @nErrNo = 133214  -- ToID not empty
            GOTO Quit
         END
         */
         IF ( @nLLI_QtyAlloc + @nLLI_QtyPick) = 0 AND ( @nToID_QtyAlloc + @nToID_QtyPick) > 0
         BEGIN
            SET @nErrNo = 133215  -- ToID Has Pick
            GOTO Quit
         END

         IF rdt.rdtGetConfig( @nFunc, 'NotAllowMoveToNewID', @cStorerKey) = '1'
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cToID)
            BEGIN
               SET @nErrNo = 133207  -- TO ID X EXISTS
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
               SET @nErrNo = 133208  -- DIFF PLTID LOC
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
            SET @nErrNo = 133209  -- SKU NOT ON ID
            GOTO Quit
         END
      END

   END

QUIT:

GO