SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal05                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 14-05-2019 1.0  Ung         WMS-9050 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtVal05] (
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
            -- Check LOT# is blank
            IF @cPackData1 = ''
            BEGIN
               DECLARE @cCurrStyle NVARCHAR(20) = ''
               DECLARE @cPrevStyle NVARCHAR(20) = ''
               
               -- Get packed SKU
               SELECT TOP 1 
                  @cPrevStyle = SKU.Style
               FROM PackDetail PD WITH (NOLOCK) 
                  JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
               WHERE PD.PickSlipNo = @cPickSlipNo 
                  AND PD.CartonNo = @nCartonNo
                  AND PD.QTY > 0
               ORDER BY PD.EditDate DESC

               -- Get SKU info
               SELECT @cCurrStyle = Style FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
               
               -- Different style
               IF @cPrevStyle <> '' AND @cPrevStyle <> @cCurrStyle
               BEGIN
                  DECLARE @cOrderKey NVARCHAR( 10)
                  DECLARE @nPrevStylePickQTY INT = 0
                  DECLARE @nPrevStylePackQTY INT = 0
                  
                  -- Get pick slip info
                  SELECT @cOrderKey = OrderKey FROM PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo
                  
                  -- Get previous style pick QTY
                  SELECT @nPrevStylePickQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM PickDetail PD WITH (NOLOCK)
                     JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)                  
                  WHERE PD.OrderKey = @cOrderKey
                     AND SKU.Style = @cPrevStyle
                     AND PD.Status <> '4'
                     AND PD.UOM = '7' -- Exclude full carton

                  -- Get previous style pick QTY
                  SELECT @nPrevStylePackQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM PackDetail PD WITH (NOLOCK)
                     JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)                  
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND SKU.Style = @cPrevStyle
                     AND PD.RefNo = '' -- Exclude full carton
                  
                  -- Style not yet pack before
                  IF @nPrevStylePickQTY <> @nPrevStylePackQTY
                  BEGIN
                     DECLARE @cMsg1 NVARCHAR(20) = ''
                     DECLARE @cMsg2 NVARCHAR(20) = ''
                     DECLARE @cMsg3 NVARCHAR(20) = ''
                     DECLARE @cMsg4 NVARCHAR(20) = ''

                     SET @cMsg1 = rdt.rdtgetmessage( 138401, @cLangCode, 'DSP') --PREVIOUS STYLE
                     SET @cMsg2 = rdt.rdtgetmessage( 138402, @cLangCode, 'DSP') --NOT YET FINISH
                     SET @cMsg3 = rdt.rdtgetmessage( 138403, @cLangCode, 'DSP') --PICK QTY:
                     SET @cMsg4 = rdt.rdtgetmessage( 138404, @cLangCode, 'DSP') --PACK QTY:
                     
                     SET @cMsg3 = RTRIM( @cMsg3) + ' ' + CAST( @nPrevStylePickQTY AS NVARCHAR(5))
                     SET @cMsg4 = RTRIM( @cMsg4) + ' ' + CAST( @nPrevStylePackQTY AS NVARCHAR(5))

                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '', @cMsg1, @cMsg2, '', @cMsg3, @cMsg4
                     SET @nErrNo = 0

                     -- EXEC rdt.rdtSetFocusField @nMobile, 3  -- SKU
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