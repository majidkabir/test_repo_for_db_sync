SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513ExtVal04                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-07-24 1.0  Ung        WMS-2452 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_513ExtVal04] (
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nInputKey       INT,          
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR(  5),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,          
   @cToID           NVARCHAR( 18),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,   
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @cPickSlipNo NVARCHAR(10)
DECLARE @cSOStatus   NVARCHAR(10)
DECLARE @cShipperKey NVARCHAR(15)

IF @nFunc = 513 -- Move by SKU
BEGIN
   IF @nStep = 3 -- SKU
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check LOC allocated
         IF EXISTS( SELECT 1 FROM SKUxLOC WITH (NOLOCK) WHERE LOC = @cFromLOC AND StorerKey = @cStorerKey AND SKU = @cSKU AND QTYAllocated > 0)
         BEGIN
            SET @nErrNo = 112801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Allocated SKU
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '112801 ', @cErrMsg
            GOTO Quit
         END
      END
   END
   
   ELSE IF @nStep = 6 -- LOC
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE @cLocationFlag NVARCHAR( 10)
         DECLARE @cLocationCategory  NVARCHAR( 10)
         
         SELECT 
            @cLocationFlag = LocationFlag, 
            @cLocationCategory = LocationCategory
         FROM LOC WITH (NOLOCK)
         WHERE LOC = @cToLOC
         
         IF @cLocationFlag = 'Inactive' OR @cLocationCategory = 'Disable'
         BEGIN
            SET @nErrNo = 112802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INACTIVE/DISABLE LOC
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '112802 ', @cErrMsg
            GOTO Quit
         END
      END
   END
END

Quit:


GO