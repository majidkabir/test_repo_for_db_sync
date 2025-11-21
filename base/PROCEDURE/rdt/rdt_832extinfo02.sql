SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_832ExtInfo02                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-07-14  1.0  Ung         WMS-13699 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_832ExtInfo02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT, 
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @tExtUpd        VariableTable READONLY,
   @cDoc1Value     NVARCHAR( 20),
   @cCartonID      NVARCHAR( 20),
   @cCartonSKU     NVARCHAR( 20),
   @nCartonQTY     INT,
   @cPackInfo      NVARCHAR( 4),
   @cCartonType    NVARCHAR( 10),
   @cCube          NVARCHAR( 10),
   @cWeight        NVARCHAR( 10),
   @cPackInfoRefNo NVARCHAR( 20), 
   @cPickSlipNo    NVARCHAR( 10),
   @nCartonNo      INT,
   @cLabelNo       NVARCHAR( 20),
   @cExtendedInfo  NVARCHAR( 20) OUTPUT, 
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 832 -- Carton pack
   BEGIN
      IF @nAfterStep = 2 -- Carton ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cMsg NVARCHAR( 20)
            SET @cMsg = 
               RTRIM( rdt.rdtgetmessage( 154901, @cLangCode, 'DSP')) + --LAST CARTON NO: 
               ' ' + 
               CAST( @nCartonNo AS NVARCHAR(4))

             EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '', @cMsg
             SET @nErrNo = 0
         END
      END
   END

Quit:

END

GO