SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal14                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2022-08-08 1.0  yeekung   WMS-20385 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtVal14] (
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

   DECLARE @cLoadKey NVARCHAR( 10)
   DECLARE @cUPC NVARCHAR(30)

   
   DECLARE @cErrMsg1       NVARCHAR( 20), 
           @cErrMsg2       NVARCHAR( 20) 

   DECLARE @tPickZone TABLE 
   (
      PickZone NVARCHAR( 10) PRIMARY KEY CLUSTERED 
   )

   IF @nFunc = 838 -- Pack
   BEGIN
       IF @nStep = 8
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS (  SELECT 1
                        FROM dbo.UCC WITH (NOLOCK) 
                        JOIN SKU SKU (NOLOCK) ON UCC.SKU=SKU.SKU AND UCC.storerkey=SKU.Storerkey
                        WHERE SKU.StorerKey = @cStorerKey
                           AND uccno = @cUCCNo 
                           AND SKU.SUSR4='AD')
               BEGIN
                  SET @cErrMsg1 = rdt.rdtgetmessage( 189451, @cLangCode, 'DSP') --SKU NEED TO  
                  SET @cErrMsg2 = rdt.rdtgetmessage( 189452, @cLangCode, 'DSP') --Scan SNO  
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2 
                  SET @nErrNo = 189451  
                  GOTO Quit
               END
            END
      END
   END

Quit:

END

GO