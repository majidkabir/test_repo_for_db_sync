SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_922DecodeSP01                                         */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: Decode for PMI case                                               */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2024-10-26  PXL009    1.0   FCR-759 ID and UCC Length Issue                */
/******************************************************************************/

CREATE   PROC rdt.rdt_922DecodeSP01 ( 
   @nMobile      INT, 
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT, 
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR( 15),
   @cMBOLKey     NVARCHAR( 10),
   @cLoadKey     NVARCHAR( 10),
   @cOrderKey    NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60)  OUTPUT,
   @cFieldName   NVARCHAR( 10),
   @cLabelNo     NVARCHAR( 20)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUCC     NVARCHAR( 20)

   IF @nFunc = 922
   BEGIN
      IF @nStep = 2 
      BEGIN
         IF @nInputKey = 1
         BEGIN

            IF @cBarcode <> ''
            BEGIN
               SET @cUCC = ''
               IF LEN(LTRIM(RTRIM(@cBarcode))) <= 20
               BEGIN
                  SET @cUCC = LTRIM(RTRIM(@cBarcode))
                  SET @cLabelNo = @cUCC
                  GOTO Quit
               END

               IF LEN(LTRIM(RTRIM(@cBarcode))) <> 40
               BEGIN
                  SET @nErrNo = 227001
                  SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') -- Invalid UCC(40 digit)
                  GOTO Quit
               END
               
               SET @cUCC = RIGHT(LTRIM(RTRIM(@cBarcode)), 20)
               SET @cLabelNo = @cUCC
               GOTO Quit

            END

            GOTO Quit
         END
      END
   END
Quit:

END

GO