SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DisableQTY02                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2020-12-08 1.0  Chermaine   WMS-15727 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838DisableQTY02] (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cFacility           NVARCHAR( 5),
   @cStorerKey          NVARCHAR( 15),
   @cPickSlipNo         NVARCHAR( 10),
   @cFromDropID         NVARCHAR( 20),
   @nCartonNo           INT,
   @cLabelNo            NVARCHAR( 20),
   @cSKU                NVARCHAR( 20),
   @nQTY                INT,
   @cUCCNo              NVARCHAR( 20),
   @cCartonType         NVARCHAR( 10),
   @cCube               NVARCHAR( 10),
   @cWeight             NVARCHAR( 10),
   @cRefNo              NVARCHAR( 20),
   @cSerialNo           NVARCHAR( 30),
   @nSerialQTY          INT,
   @cOption             NVARCHAR( 1),
   @cPackDtlRefNo       NVARCHAR( 20), 
   @cPackDtlRefNo2      NVARCHAR( 20), 
   @cPackDtlUPC         NVARCHAR( 30), 
   @cPackDtlDropID      NVARCHAR( 20), 
   @cPackData1          NVARCHAR( 30), 
   @cPackData2          NVARCHAR( 30), 
   @cPackData3          NVARCHAR( 30),
   @tVarDisableQTYField VARIABLETABLE  READONLY,
   @cDisableQTYField    NVARCHAR( 1)   OUTPUT,
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSerialNoCapture    NVARCHAR( 1)

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT
               @cSerialNoCapture = SerialNoCapture
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU

            IF @cSerialNoCapture = '3'
            BEGIN
               SET @cDisableQTYField = '1'
            END 
            ELSE
            BEGIN
            	SET @cDisableQTYField = '0'
            END
         END
      END    
   END

Quit:

END

GO