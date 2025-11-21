SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_540ExtValid01                                   */    
/* Purpose: Make sure labelno = loadkey user scanned                    */
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2018-03-28 1.0  James      WMS4203. Created                          */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_540ExtValid01] (    
   @nMobile       INT,    
   @nFunc         INT,     
   @cLangCode     NVARCHAR( 3),     
   @nStep         INT,    
   @cUserName     NVARCHAR( 18), 
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),     
   @cSKU          NVARCHAR( 20),  
   @cLoadKey      NVARCHAR( 10),     
   @cConsigneeKey NVARCHAR( 15),     
   @cPickSlipNo   NVARCHAR( 10),  
   @cOrderKey     NVARCHAR( 10),  
   @cLabelNo      NVARCHAR( 20),  
   @nErrNo        INT           OUTPUT,     
   @cErrMsg       NVARCHAR( 20) OUTPUT  
)    
AS    
BEGIN

   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    

   DECLARE @nInputKey      INT,
           @cCheckSKU      NVARCHAR( 20)

   SELECT @nInputKey = InputKey ,
          @cCheckSKU = V_SKU
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nFunc <> 540 GOTO Quit

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3
      BEGIN    
         IF NOT EXISTS ( SELECT 1 
                         FROM rdt.rdtSortAndPackLog SAP WITH (NOLOCK)
                         WHERE LoadKey = @cLabelNo
                         AND   UserName = @cUserName
                         AND   Status = '0')
         BEGIN
            SET @nErrNo = 121901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lbl No
            GOTO Quit
         END -- IF NOT EXISTS
      END -- IF @nStep = 3

      IF @nStep = 4
      BEGIN 
         IF @cCheckSKU <> @cSKU
         BEGIN
            SET @nErrNo = 121902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Different
            GOTO Quit
         END -- IF @cCheckSKU <> @cSKU
      END
   END -- IF @nInputKey = 1 

QUIT:
END

GO