SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_732ExtUpd02                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Check if qty has entered in step 4. If no qty then not      */
/*          allow to esc                                                */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2019-11-22  1.0  James       WMS-11122. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_732ExtUpd02]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cCCKey       NVARCHAR( 10) 
   ,@cCCSheetNo   NVARCHAR( 10) 
   ,@cCountNo     NVARCHAR( 1)  
   ,@cLOC         NVARCHAR( 10) 
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@cOption      NVARCHAR( 1)  
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cQtyOnScreen   NVARCHAR( 60)

   IF @nStep = 4 -- SKU, QTY
   BEGIN
      IF @nInputKey = 0 -- ESC
      BEGIN
         SELECT @cQtyOnScreen = O_Field09
         FROM RDT.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile

         IF ISNULL( @cQtyOnScreen, '') = ''
         BEGIN
            SET @nErrNo = 146201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Qty Required'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Quit
         END
      END
   END

   Quit:
END

GO