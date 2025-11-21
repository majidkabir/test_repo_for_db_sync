SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1863ExtVal01                                          */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date         Rev  Author   Purposes                                        */
/* 2023-07-17   1.0  Ung      WMS-22678 Created                               */
/* 2023-08-11   1.1  Ung      WMS-22678 Change checking to MBOL level         */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_1863ExtVal01](
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cMBOLKey       NVARCHAR( 10),
   @cRefNo         NVARCHAR( 20),
   @cOrderKey      NVARCHAR( 10),
   @cCartonID      NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @cPickSlipNo    NVARCHAR( 20),
   @nCartonNo      INT,
   @cData1         NVARCHAR( 20),
   @cData2         NVARCHAR( 20),
   @cData3         NVARCHAR( 20),
   @cData4         NVARCHAR( 20),
   @cData5         NVARCHAR( 20),
   @cOption        NVARCHAR( 2),
   @cCartonType    NVARCHAR( 10),
   @cUseSequence   NVARCHAR( 10),
   @cCube          NVARCHAR( 10),
   @cWeight        NVARCHAR( 10),
   @cPackInfoRefNo NVARCHAR( 20),
   @cLength        NVARCHAR( 10),
   @cWidth         NVARCHAR( 10),
   @cHeight        NVARCHAR( 10),
   @tExtValVar     VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1863 -- Carton to MBOL
   BEGIN
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            DECLARE @nTotalCarton INT = 0
            DECLARE @nTotalScan   INT = 0

            DECLARE @cCartonIDSP NVARCHAR( 20)
            SET @cCartonIDSP = rdt.RDTGetConfig( @nFunc, 'CartonIDSP', @cStorerKey)
            IF @cCartonIDSP = '0'
               SET @cCartonIDSP = ''
            IF @cCartonIDSP = ''
               SET @cCartonIDSP = 'L' -- L=LabenNo

            -- Check carton ID (PackDetail.LabelNo)
            IF @nTotalCarton = 0 AND CHARINDEX( 'L', @cCartonIDSP) > 0 -- L=LabelNo
            BEGIN
               -- Discrete pack
               SELECT @nTotalCarton = COUNT( DISTINCT PD.LabelNo)
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON (O.OrderKey = PH.OrderKey)
                  JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE O.MBOLKey = @cMBOLKey

               -- Conso pack
               SELECT @nTotalCarton = @nTotalCarton + COUNT( DISTINCT PD.LabelNo)
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON (LPD.LoadKey = PH.LoadKey AND PH.OrderKey = '')
                  JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE O.MBOLKey = @cMBOLKey
            END

            -- Check carton ID (PackDetail.DropID)
            IF @nTotalCarton = 0 AND CHARINDEX( 'D2', @cCartonIDSP) > 0 -- D2=PackDetail.DropID
            BEGIN
               -- Discrete pack
               SELECT @nTotalCarton = COUNT( DISTINCT PD.DropID)
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON (O.OrderKey = PH.OrderKey)
                  JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE O.MBOLKey = @cMBOLKey

               -- Conso pack
               SELECT @nTotalCarton = @nTotalCarton + COUNT( DISTINCT PD.DropID)
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON (LPD.LoadKey = PH.LoadKey AND PH.OrderKey = '')
                  JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE O.MBOLKey = @cMBOLKey
            END
            
            -- Check carton ID (PickDetail.CaseID)
            IF @nTotalCarton = 0 AND CHARINDEX( 'C', @cCartonIDSP) > 0 -- C=CaseID
            BEGIN
               -- Get total carton
               SELECT @nTotalCarton = COUNT( DISTINCT PD.CaseID)
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.MBOLKey = @cMBOLKey
                  AND PD.CaseID <> ''
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
            END

            -- Check carton ID (PickDetail.DropID)
            IF @nTotalCarton = 0 AND CHARINDEX( 'D1', @cCartonIDSP) > 0 -- D1=PickDetail.DropID
            BEGIN
               -- Get total carton
               SELECT @nTotalCarton = COUNT( DISTINCT PD.DropID)
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.MBOLKey = @cMBOLKey
                  AND PD.DropID <> ''
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
            END

            -- Get total scanned
            SELECT @nTotalScan = COUNT( 1) FROM rdt.rdtCartonToMBOLLog WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey
            
            -- Check not all carton scanned
            IF @nTotalCarton > 0 AND @nTotalScan < @nTotalCarton
            BEGIN
               SET @nErrNo = 203851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NOT ALL SCANNED
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               SET @nErrNo = 0
            END
         END
      END
   END

Quit:

END

GO