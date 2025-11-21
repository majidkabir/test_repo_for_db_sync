SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtSNOVal01                                   */
/* Purpose:                                                             */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-09-22 1.0  yeekung      WMS-23600 Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtSNOVal01] (
   @nMobile      INT,          
   @nFunc        INT,          
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT,          
   @nInputKey    INT,          
   @cFacility    NVARCHAR( 5), 
   @cStorerkey   NVARCHAR( 15),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,          
   @cSerialNo    NVARCHAR( 30),
   @cType        NVARCHAR( 15),
   @cDocType     NVARCHAR( 10),
   @cDocNo       NVARCHAR( 20),
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   IF @nInputKey = 1
   BEGIN
      IF EXISTS( SELECT 1
                  FROM Serialno (NOLOCK)
                  WHERE Serialno = @cSerialNo
                     AND Storerkey = @cStorerKey
                     AND ExternStatus IN ('9','H'))
      BEGIN
         SET @nErrNo = 206701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SerialNo
         GOTO Quit
      END
   END

Quit:

GO