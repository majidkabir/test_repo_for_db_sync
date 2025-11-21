SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtValid13                                   */
/* Purpose: Check duplicate PackDetailInfo.UserDefine01                 */
/*                                                                      */
/* Called By: RDT Pack By Track No                                      */ 
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-03-18 1.0  James      WMS-19123. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtValid13] (
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cOrderKey                 NVARCHAR( 10),
   @cPickSlipNo               NVARCHAR( 10),
   @cTrackNo                  NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nCartonNo                 INT,
   @cCtnType                  NVARCHAR( 10),
   @cCtnWeight                NVARCHAR( 10),
   @cSerialNo                 NVARCHAR( 30), 
   @nSerialQTY                INT,   
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cData1      NVARCHAR( 60) = ''
   
   SELECT @cData1 = I_Field02
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @nErrNo = 0

   IF @nStep = 9
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS ( SELECT 1 
                     FROM dbo.PackDetailInfo WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   UserDefine01 = @cData1)
         BEGIN
            SET @nErrNo = 179101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Code Exists
            INSERT INTO traceinfo(TraceName, TimeIn, Col1, Col2) VALUES ('rdt_840ExtValid13', GETDATE(), @cData1, @cPickSlipNo)
            GOTO Quit
         END
      END
   END
      
   Quit:
   
   
SET QUOTED_IDENTIFIER OFF

GO