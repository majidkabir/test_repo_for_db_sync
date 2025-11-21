SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal21                                     */
/* Copyright      : LF Logistics                                        */
/* CLIENT         : Huda Beauty                                         */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 24-05-2017 1.0  YYS027      FCR-861 Not allow Mix SKU for one carton */
/*                             if orders.userdefine02='G'               */
/************************************************************************/

CREATE   PROC rdt.rdt_838ExtVal21 (
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
               DECLARE @tSKUs    TABLE(SKU NVARCHAR(20))
               DECLARE @nCount   INT
               -- Get SKU info
               INSERT INTO @tSKUs(SKU)
                  SELECT DISTINCT SKU
                  FROM PackDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo 
                     AND CartonNo = @nCartonNo
               IF NOT EXISTS(SELECT 1 from @tSKUs where SKU=@cSKU)
                  INSERT INTO @tSKUs(SKU) VALUES(@cSKU)
               select @nCount = count(1) from @tSKUs
               IF isnull(@nCount,0)>1
               BEGIN
                  EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
                  SET @nErrNo = 225951
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not allow Mix SKU
                  GOTO Quit
               END
            
            END
         END
      END
   END

Quit:

END

GO