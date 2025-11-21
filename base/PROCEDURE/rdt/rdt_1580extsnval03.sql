SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtSNVal03                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: User decide whether need receive this item or not base on screen  */
/*          input (1 or 0). If no then return -1 then proceed to receive      */
/*          as normal item                                                    */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 2022-04-04  1.0  yeekung      WMS-19225. Created                           */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtSNVal03]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT, 
   @cSerialNo        NVARCHAR( 30),
   @cType            NVARCHAR( 15), --CHECK/INSERT
   @cDocType         NVARCHAR( 10), 
   @cDocNo           NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKUClass NVARCHAR(20),
           @nLenSNo   INT

   IF @nFunc IN ( 1580, 1581) -- Piece receiving
   BEGIN

      SELECT @cSKUClass=class
      FROM SKU (NOLOCK)
      WHERE SKU=@cSKU
      AND Storerkey=@cstorerkey

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SERIALNO', @cSerialNo) = 0
      BEGIN
         SET @nErrNo = 185401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
         GOTO Quit
      END
      
      SELECT @nLenSNo=short
      FROM codelkup (NOLOCK)
      WHERE listname='Serialno'
      AND  code=@cSKUClass
      AND storerkey=@cstorerkey

      IF (@nLenSNo<>LEN(@cSerialNo))
      BEGIN
         SET @nErrNo = 185402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SNOCharNotTally
         GOTO Quit
      END
   END

Quit:

END


GO