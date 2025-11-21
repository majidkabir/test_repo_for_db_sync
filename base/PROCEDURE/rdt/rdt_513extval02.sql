SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513ExtVal02                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-08-08 1.0  Ung        SOS374750 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_513ExtVal02] (
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
   IF @nStep = 5 -- TO ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cFromID <> @cToID
         BEGIN
            SET @nErrNo = 102751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff FromTOID
            GOTO Quit
         END
      END
   END
END

Quit:


GO