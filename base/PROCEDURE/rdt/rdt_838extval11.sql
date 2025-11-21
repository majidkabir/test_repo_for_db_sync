SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal11                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 01-10-2019 1.0  Ung         WMS-10729 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtVal11] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @nPickQTY    INT
   DECLARE @nPackQTY    INT
   DECLARE @dLottable04 DATETIME
   DECLARE @cPickStatus NVARCHAR(1)
   
   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 10 -- Pack data
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check batch no blank
            IF @cPackData1 = ''
            BEGIN
               SET @nErrNo = 182101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need batch no
               EXEC rdt.rdtSetFocusField @nMobile, 2  -- batch no
               GOTO Quit
            END

            -- Check ExpDate blank
            IF @cPackData2 = ''
            BEGIN
               SET @nErrNo = 182102
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedExpiryDate
               EXEC rdt.rdtSetFocusField @nMobile, 4  -- expiry date
               GOTO Quit
            END

            -- Check ExpDate blank
            IF rdt.rdtIsValidDate( @cPackData2) = 0
            BEGIN
               SET @nErrNo = 182103
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid date
               EXEC rdt.rdtSetFocusField @nMobile, 4  -- expiry date
               GOTO Quit
            END

            SET @dLottable04 = rdt.rdtConvertToDate( @cPackData2)
            
            SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerkey)

            -- Get PickHeader info
            SELECT TOP 1
               @cOrderKey = OrderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            -- Get pick QTY
            SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.QTY > 0
               AND PD.Status = @cPickStatus
               AND PD.Status <> '4'
               AND LA.Lottable02 = @cPackData1
               AND LA.Lottable04 = @dLottable04

            -- Get pack QTY
            SELECT @nPackQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.PackDetailInfo WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND UserDefine01 = @cPackData1
               AND UserDefine02 = @cPackData2

            -- Check batch, expdate valid
            IF @nPickQTY = 0
            BEGIN
               SET @nErrNo = 182104
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not In PSNO
               GOTO Quit
            END

            -- Check over pack
            IF @nPackQTY + @nQTY > @nPickQTY
            BEGIN
               SET @nErrNo = 182105
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
               GOTO Quit
            END
         END
      END    
   END

Quit:

END

GO