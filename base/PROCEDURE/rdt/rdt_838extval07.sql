SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal07                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2019-12-05 1.0  James       WMS-10890 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtVal07] (
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
   
   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 1 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cLoadKey = ExternOrderKey
            FROM dbo.PickHeader WITH (NOLOCK)     
            WHERE PickHeaderKey = @cPickSlipNo

            IF ISNULL( @cLoadKey, '') <> ''
            BEGIN
               -- One pickslipno One load, check all orders in the load, Orders.Doctype=N
               IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                           WHERE LoadKey = @cLoadKey
                           AND   DocType <> 'N')
               BEGIN  
                  SET @nErrNo = 146851  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Doctype<>N
                  GOTO Quit  
               END 
               
               -- Check all Orders in the load, Orders.Mbolkey<>Blank
               IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                           WHERE LoadKey = @cLoadKey
                           AND   Mbolkey = '')
               BEGIN  
                  SET @nErrNo = 146852  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mbolkey blank  
                  GOTO Quit  
               END 
            END
         END
      END    
   END

Quit:

END

GO