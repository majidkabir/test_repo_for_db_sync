SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*******************************************************************************************************************************/
/* Store procedure: rdt_922ExtVal08_NLRT                                                                                       */
/* Copyright      : Maersk                                                                                                     */
/* Customer       : NLRT facilty with same XDock config as AMZ                                                                 */
/*                                                                                                                             */
/* Purpose: Check mbol status. If mbol.status = 5 then error.                                                                  */
/*                                                                                                                             */
/* Date       Rev    Author     Purposes                                                                                       */
/* 2024-10-18 1.0    VJI011     none packing process enhancement for JCB                                                       */
/* 2024-12-05 1.1.0  NLT013     UWP-28007 Merge Code                                                                           */
/* 2024-12-20 1.1.1  JCH507     UWP-28603 Issue fix                                                                            */
/* 2025-02-05 2.0    AGA399     Copy SP version for Amazon rdt_922ExtVal08_AMZ to All customer of NLRT with same config        */
/*******************************************************************************************************************************/

CREATE     PROC [RDT].[rdt_922ExtVal08_NLRT] (
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
        @cChk_OrderKey  NVARCHAR( 10),
        @cChk_ExMbolKey NVARCHAR( 10),
        @nLabelCount    INT


IF @nFunc = 922
BEGIN
   IF @nStep = 1
   BEGIN
      IF @cType = 'R' -- MbolKey
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

      IF @cType = 'L' --Loadkey
      BEGIN
         SET @nErrNo = 100801
         SET @cErrMsg = 'Loadkey not allowed' -- Invalid mbol
         GOTO Quit
      END
   END

   IF @nStep = 2  -- LabelNo/DropID
   BEGIN
      IF @cType = 'R' --Refno
      BEGIN
         --check if scanned drop id belongs to MBOL not allow to split
         SET @cChk_ExMbolKey = ''
         SET @cChk_MbolKey = ''
         
         SELECT TOP 1 @cChk_ExMbolKey = M.ExternMbolKey, @cChk_MbolKey = M.MbolKey
         FROM MBOL M WITH (NOLOCK)
         INNER JOIN MBOLDETAIL MD WITH (NOLOCK) ON MD.MbolKey = M.MbolKey
         INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
         WHERE PD.StorerKey = @cStorerKey
            AND PD.Status = '5'
            AND PD.DropID = @cLabelNo

         --SELECT @cStorerKey,@cLabelNo, @cChk_MbolKey, @cChk_ExMbolKey
         IF ISNULL(@cChk_MbolKey,'') <> '' AND ISNULL(@cChk_ExMbolKey, '') = ''
         BEGIN
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 100808, @cLangCode, 'DSP'), 7, 14) --LABEL SCANNED
            SET @cErrMsg2 = 'NOT ALLOW' 
            SET @cErrMsg3 = 'TO SPLIT'
            SET @cErrMsg4 = 'ON MBOL-' + @cChk_MbolKey
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
         SET @cOtherMbolKey = ''

         SELECT TOP 1 @cOtherMbolKey = RT.MBOLKey
         FROM rdt.rdtScanToTruck RT WITH (NOLOCK)
         LEFT JOIN MBOL M WITH (NOLOCK) ON RT.MBOLKey = M.MbolKey
         WHERE RT.URNNo = @cLabelNo
            AND M.Status < '9'

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

         -- Check if the label is not be shipped
         SET @nLabelCount = 0

         SELECT @nLabelCount = COUNT(1) 
         FROM PICKDETAIL (NOLOCK) PD
         WHERE PD.Storerkey = @cStorerKey
            AND PD.Status = '5'
            AND PD.DropID = @cLabelNo

         IF @nLabelCount = 0
         BEGIN
            SET @cErrMsg1 = 'LABEL CANNOT' --LABEL CANNOT
            SET @cErrMsg2 = 'BE SCANNED' --BE SCANNED
            SET @cErrMsg3 = 'SHIPPED ALREADY' --SHIPPED ALREADY
            SET @cErrMsg4 = @cLabelNo
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
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
         WHERE PH.StorerKey = @cStorerKey
            AND PD.LabelNo = @cLabelNo
         
         SET @cChk_MbolKey = ''

         SELECT @cChk_MbolKey = MbolKey
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cChk_OrderKey
        
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
      
      IF @cType = 'M' --MBOL
      BEGIN
         -- Check ID in MBOL
         IF NOT EXISTS( SELECT 1
            FROM dbo.MBOLDetail MD WITH (NOLOCK)
            WHERE MD.MbolKey = @cMBOLKey
               AND EXISTS( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) WHERE PD.OrderKey = MD.OrderKey AND PD.DropID = @cLabelNo))
         BEGIN
            SET @nErrNo = 79320
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotInMBOL
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- RefNo1
         END
         GOTO Quit
      END
   END

   IF @nStep = 4 -- DOOR, REFNO From MBOL
   BEGIN
      IF @cType = 'M' OR @cType = 'O' -- DOOR, REFNO From MBOL or Order
      BEGIN
         DECLARE @cChkDoor NVARCHAR(10) = ''
                  ,@cPlaceOfLoading NVARCHAR(10) = ''
      
         -- get Place of Loading
         SELECT @cPlaceOfLoading = PlaceOfLoading
         FROM mbol WITH (NOLOCK)
         WHERE MBOLKey IN
         (
               SELECT MbolKey
               FROM MBOLDETAIL WITH (NOLOCK)
               WHERE (
                        (MBOLKey = @cMBOLKey AND @cType = 'M') --V1.1.1
                        OR (LoadKey = @cLoadKey AND @cType = 'L')--V1.1.1
                        OR (OrderKey = @cOrderKey AND @cType = 'O')--V1.1.1
                     )
         )
         -- Get door
         IF @cMBOLKey  <> ''
            SELECT @cChkDoor = Door FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey
         
         ELSE IF @cLoadKey <> ''
            SELECT @cChkDoor = Door FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE OrderKey = @cLoadKey
         
         ELSE IF @cOrderKey <> ''
            SELECT @cChkDoor = Door FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      
      -- Check different door
         IF @cChkDoor <> '' AND @cChkDoor <> @cDoor
         BEGIN
            SET @nErrNo = 205051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Door
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- RefNo1
            GOTO Quit
         END 
         -- Check if RefNo is Empty ->  door (WS- test)
         IF  ISNULL( @cDoor , '') = ''
         BEGIN
               SET @nErrNo = 218036
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Missing Door Entry
               GOTO Quit
         END
      
         -- check Place of Loading
         IF @cPlaceOfLoading = '' or @cPlaceOfLoading <> @cDoor
         BEGIN
            SET @nErrNo = 218037
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Door Mismatch
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- RefNo1
            GOTO Quit
         END
      END
   END

Quit:

END

GO