SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/
/* Store procedure: rdt_1653ExtValid10                                  */
/* Copyright      : MAERSK                                              */
/*                                                                      */
/* Date        Rev    Author  Purposes                                  */
/* 2024-10-08  1.0    NLT013  FCR-950 Created                           */
/* 2025-02-20  1.1.0  NLT013  UWP-30312 Performance Tune                */
/************************************************************************/
        
CREATE   PROC [RDT].[rdt_1653ExtValid10] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTrackNo       NVARCHAR( 40),
   @cOrderKey      NVARCHAR( 20),
   @cPalletKey     NVARCHAR( 20),
   @cMBOLKey       NVARCHAR( 10),
   @cLane          NVARCHAR( 30),
   @tExtValidVar   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @cPackStatus                     NVARCHAR(20),
      @cLabelNo                        NVARCHAR(20),
      @cMBOLStatus                     NVARCHAR(10)

   IF @nFunc = 1653
   BEGIN
      IF @nStep = 1
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SELECT @cLabelNo = Value FROM @tExtValidVar WHERE Variable = '@cLabelNo'
            -- FCR-950
            IF ISNULL(@cLabelNo, '') <> ''
            BEGIN
               SELECT @cPackStatus = CartonStatus 
               FROM dbo.PackInfo WITH(NOLOCK) 
               WHERE RefNo IS NOT NULL
                  AND RefNo = @cLabelNo

               IF @cPackStatus IS NULL OR TRIM(@cPackStatus) <> 'PACKED'
               BEGIN
                  SET @nErrNo = 225501
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonNotPacked
                  GOTO Quit
               END

               SELECT TOP 1 @cMBOLStatus = MB.Status
               FROM dbo.MBOL MB WITH(NOLOCK)
               INNER JOIN dbo.MBOLDETAIL MBD WITH(NOLOCK)
                  ON MB.MbolKey = MBD.MbolKey
               WHERE MBD.OrderKey = @cOrderKey

               IF @cMBOLStatus IS NOT NULL AND @cMBOLStatus = '9'
               BEGIN
                  SET @nErrNo = 225502
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOLFinished
                  GOTO Quit
               END
            END
         END
      End
   END
   Quit:
END

GO