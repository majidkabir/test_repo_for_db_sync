SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal02                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 24-05-2017 1.0  Ung         WMS-1919 Created                         */
/* 04-04-2019 1.1  Ung         WMS-8134 Add PackData1..3 parameter      */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtVal02] (
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

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Current carton
            IF @nCartonNo > 0
            BEGIN
               -- Get SKU info
               DECLARE @cSerialNoCapture NVARCHAR( 1)
               SELECT @cSerialNoCapture = SerialNoCapture 
               FROM SKU WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
                  AND SKU = @cSKU
               
               -- Non-serial SKU
               IF @cSerialNoCapture <> '1'
               BEGIN
                  -- Get packed SKU info
                  DECLARE @cPackedSKU NVARCHAR( 20)
                  DECLARE @cPackedDropID NVARCHAR( 20)
                  SELECT TOP 1 
                     @cPackedSKU = SKU, 
                     @cPackedDropID = DropID
                  FROM PackDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo 
                     AND CartonNo = @nCartonNo

                  SELECT @cSerialNoCapture = SerialNoCapture 
                  FROM SKU WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey 
                     AND SKU = @cPackedSKU 
               
                  -- Check mix non-serial with serial
                  IF @cSerialNoCapture = '1'
                  BEGIN
                     SET @nErrNo = 109951
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mix SNO SKU
                     GOTO Quit
                  END
                  
                  -- Check mix drop ID
                  IF @cFromDropID <> @cPackedDropID
                  BEGIN
                     SET @nErrNo = 109952
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mix DropID
                     GOTO Quit
                  END
               END
            END
         END
      END
      
      IF @nStep = 5 -- Print label
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOption = '1' -- Yes
            BEGIN
               IF @cFromDropID <> ''
               BEGIN
                  -- Check DropID
                  DECLARE @nPickQTY INT
                  DECLARE @nPackQTY INT
                  
                  SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
                  FROM PickDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo 
                     AND DropID = @cFromDropID
                     AND Status <= '5'
                     AND Status <> '4'
                     
                  SELECT @nPackQTY = ISNULL( SUM( QTY), 0)
                  FROM PackDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo 
                     AND DropID = @cFromDropID
   
                  -- Check DropID not fully packed
                  IF @nPickQTY <> @nPackQTY
                  BEGIN
                     SET @nErrNo = 109953
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotFullPack
                     GOTO Quit
                  END
               END
            END
         END
      END      
   END

Quit:

END

GO