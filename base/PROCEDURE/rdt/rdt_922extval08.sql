SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtVal08                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check mbol status. If mbol.status = 5 then error.           */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-05-20 1.0  James      SOS368201 Created                         */
/* 2016-10-31 1.1  James      WMS582 Prompt error if label scanned      */
/*                            before even in other mbol (james01)       */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtVal08] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT, 
   @cStorerKey  NVARCHAR( 15),
   @cType       NVARCHAR( 1),
   @cMBOLKey    NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10),
   @cLabelNo    NVARCHAR( 20),
   @cPackInfo   NVARCHAR( 3),
   @cWeight     NVARCHAR( 10),
   @cCube       NVARCHAR( 10),
   @cCartonType NVARCHAR( 10),
   @cDoor       NVARCHAR( 10),
   @cRefNo      NVARCHAR( 40), 
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @cStatus        NVARCHAR( 10),
        @cErrMsg1       NVARCHAR( 20),
        @cErrMsg2       NVARCHAR( 20),
        @cErrMsg3       NVARCHAR( 20),
        @cErrMsg4       NVARCHAR( 20),
        @cOtherMbolKey  NVARCHAR( 10),
        @cChk_MbolKey   NVARCHAR( 10),
        @cChk_OrderKey  NVARCHAR( 10)


IF @nFunc = 922
BEGIN
   IF @nStep = 1 -- MbolKey
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @cStatus = [Status]
         FROM dbo.MBOL WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLKey

         IF ISNULL( @cStatus, '') = ''
         BEGIN
            SET @nErrNo = 100801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid mbol
            GOTO Quit
         END  

         IF @cStatus >= '5'
         BEGIN  
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 100802, @cLangCode, 'DSP'), 7, 14) --MBOL CLOSED
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 100803, @cLangCode, 'DSP'), 7, 14) --AND MANIFEST
            SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 100804, @cLangCode, 'DSP'), 7, 14) --PRINTED
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
            END         

            GOTO Quit
         END  
      END
   END

   IF @nStep = 2  -- LabelNo/DropID
   BEGIN
      -- Check if the orders the label nelongs to exist in another mbol
      SET @cOtherMbolKey = ''
      SELECT TOP 1 @cOtherMbolKey = MBOLKey
      FROM rdt.rdtScanToTruck WITH (NOLOCK)
      WHERE URNNo = @cLabelNo

      -- This label scanned before in another mbolkey (duplicate check is @ step2 main script)
      IF ISNULL( @cOtherMbolKey, '') <> '' AND @cOtherMbolKey <> @cMbolKey
      BEGIN
         SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 100805, @cLangCode, 'DSP'), 7, 14) --LABEL SCANNED
         SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 100806, @cLangCode, 'DSP'), 7, 14) --BEFORE IN 
         SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 100807, @cLangCode, 'DSP'), 7, 14) --MBOLKEY
         SET @cErrMsg4 = @cOtherMbolKey
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
         END         

         GOTO Quit
      END

      -- Check if the orders the label nelongs to exist in another mbol
      SET @cChk_OrderKey = ''
      SELECT TOP 1 @cChk_OrderKey = PH.OrderKey
      FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
      WHERE PH.StorerKey = @cStorerKey
      AND   PD.LabelNo = @cLabelNo

      SET @cChk_MbolKey = ''
      SELECT @cChk_MbolKey = MbolKey
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cChk_OrderKey

      -- This label scanned before in another mbolkey (duplicate check is @ step2 main script)
      IF ISNULL( @cChk_MbolKey, '') <> '' AND @cChk_MbolKey <> @cMbolKey
      BEGIN
         SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 100808, @cLangCode, 'DSP'), 7, 14) --LABEL SCANNED
         SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 100809, @cLangCode, 'DSP'), 7, 14) --BEFORE IN 
         SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 100810, @cLangCode, 'DSP'), 7, 14) --MBOLKEY
         SET @cErrMsg4 = @cChk_MbolKey
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
         END         

         GOTO Quit
      END
   END
Quit:

END

GO