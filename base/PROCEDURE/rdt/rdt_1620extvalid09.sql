SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1620ExtValid09                                  */  
/* Purpose: DropID must be in ID + Orderkey format                      */  
/*                                                                      */  
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 2020-08-27  1.0  James      INC1237019. Created                      */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1620ExtValid09] (  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,  
   @nInputKey        INT,  
   @cStorerkey       NVARCHAR( 15),  
   @cWaveKey         NVARCHAR( 10),  
   @cLoadKey         NVARCHAR( 10),  
   @cOrderKey        NVARCHAR( 10),  
   @cLoc             NVARCHAR( 10),  
   @cDropID          NVARCHAR( 20),  
   @cSKU             NVARCHAR( 20),  
   @nQty             INT,  
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)  
AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   SET @nErrNo = 0  
  
   IF @nFunc = 1620  
   BEGIN  
      IF @nStep = 7  
      BEGIN  
         IF @nInputKey = 1  
         BEGIN  
            IF SUBSTRING( @cDropID, 3, 10) <> @cOrderKey  
            BEGIN  
               SET @nErrNo = 158101  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDNotMatch=C  
               GOTO Quit  
            END  
         END  
      END  
   END  
  
QUIT:  

GO