SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/      
/* Store procedure: rdt_844DecodeSP01                                   */      
/* Purpose: Check if user login with printer                            */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author    Purposes                                   */      
/* 2018-11-19 1.0  Ung       WMS-6932 Created                           */   
/* 2019-03-29 1.2  James     WMS-8002 Add TaskDetailKey param (james02) */     
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_844DecodeSP01] (      
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),     
   @nStep          INT,              
   @nInputKey      INT,              
   @cStorerKey     NVARCHAR( 15),    
   @cFacility      NVARCHAR( 5),     
   @cRefNo         NVARCHAR( 10),    
   @cPickSlipNo    NVARCHAR( 10),    
   @cLoadKey       NVARCHAR( 10),    
   @cOrderKey      NVARCHAR( 10),    
   @cDropID        NVARCHAR( 20),    
   @cID            NVARCHAR( 18),  
   @cTaskDetailKey    NVARCHAR( 10) = '',     
   @cBarcode       NVARCHAR( 60),    
   @cSKU           NVARCHAR( 20) OUTPUT,    
   @nQTY           INT           OUTPUT,    
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT     
)      
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @cItemClass   NVARCHAR( 10)    
   DECLARE @cPQTY        NVARCHAR( 5)    
   DECLARE @cMQTY        NVARCHAR( 5)    
   DECLARE @cInField09   NVARCHAR( 20)    
   DECLARE @cInField10   NVARCHAR( 20)    
   DECLARE @cFieldAttr09 NVARCHAR( 1)    
   DECLARE @cFieldAttr10 NVARCHAR( 1)    
   DECLARE @cOutField09  NVARCHAR( 20)    
   DECLARE @cOutField10  NVARCHAR( 20)    
          
   -- Get session info    
   SELECT     
      @cInField09 = I_Field09, @cOutField09 = O_Field09, @cFieldAttr09 = FieldAttr09,     
      @cInField10 = I_Field10, @cOutField10 = O_Field10, @cFieldAttr10 = FieldAttr10     
   FROM rdt.rdtMobRec WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
       
   SET @cPQTY = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END    
   SET @cMQTY = CASE WHEN @cFieldAttr10 = 'O' THEN @cOutField10 ELSE @cInField10 END    
    
   IF @cPQTY = '' AND @cMQTY = ''    
   BEGIN    
      -- Scan SKU, only allow for POSM    
      SELECT @cItemClass = ItemClass    
      FROM SKU WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
         AND SKU = @cBarcode    
             
      IF @@ROWCOUNT = 1    
      BEGIN    
         IF @cItemClass <> 'POSM'    
         BEGIN    
            SET @nErrNo = 132301    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SCAN UPC    
            GOTO Quit    
         END     
         GOTO Quit    
      END    
          
      -- Scan UPC, only allow for non POSM    
      SELECT @cItemClass = ItemClass    
      FROM SKU WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
         AND @cBarcode IN (AltSKU, RetailSKU, ManufacturerSKU)    
    
      IF @@ROWCOUNT = 1    
      BEGIN    
         IF @cItemClass = 'POSM'    
         BEGIN    
            SET @nErrNo = 132302    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Key-in SKU    
            GOTO Quit    
         END     
         GOTO Quit    
      END    
   END    
       
Quit:      
    
END 

GO