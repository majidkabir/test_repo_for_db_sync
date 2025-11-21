SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DataCap06                                    */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 11-04-2023 1.0  Ung         WMS-22287 Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838DataCap06] (
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
   @cPackData1       NVARCHAR( 30)  OUTPUT, 
   @cPackData2       NVARCHAR( 30)  OUTPUT, 
   @cPackData3       NVARCHAR( 30)  OUTPUT,
   @cPackLabel1      NVARCHAR( 20)  OUTPUT,   
   @cPackLabel2      NVARCHAR( 20)  OUTPUT,   
   @cPackLabel3      NVARCHAR( 20)  OUTPUT,  
   @cPackAttr1       NVARCHAR( 1)   OUTPUT,   
   @cPackAttr2       NVARCHAR( 1)   OUTPUT,   
   @cPackAttr3       NVARCHAR( 1)   OUTPUT, 
   @cDataCapture     NVARCHAR( 1)   OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @cPackData1 = '' -- 
   SET @cPackData2 = '' -- Batch no
   SET @cPackData3 = '' -- Expiry date

   -- Get barcode
   DECLARE @cBarcode NVARCHAR( 60)
   SELECT @cBarcode = I_Field03
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- QRCode
   IF CHARINDEX( '|', @cBarcode) > 0
   BEGIN
      SET @cPackData2 = rdt.rdtGetParsedString( @cBarcode, 2, '|')
      SET @cPackData3 = rdt.rdtGetParsedString( @cBarcode, 3, '|')
   END

   -- Not capture data thru fronend, only capture at backend
   SET @cDataCapture = ''
   
END

GO