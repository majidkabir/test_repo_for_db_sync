SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtSNVal02                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: User decide whether need receive this item or not base on screen  */
/*          input (1 or 0). If no then return -1 then proceed to receive      */
/*          as normal item                                                    */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 2019-11-29  1.0  James        WMS-11215. Created                           */
/* 2020-01-06  1.1  James        WMS-11528 Add serialno format check (james01)*/
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtSNVal02]
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

   IF @nFunc IN ( 1580, 1581) -- Piece receiving
   BEGIN
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SERIAL', @cSerialNo) = 0
      BEGIN
         SET @nErrNo = 147351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
         GOTO Quit
      END
      
      IF @cSerialNo = '1'
         SET @nErrNo = 0
      ELSE
         SET @nErrNo = -1
   END

Quit:

END


GO