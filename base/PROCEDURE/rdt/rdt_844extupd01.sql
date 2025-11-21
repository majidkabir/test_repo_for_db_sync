SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_844ExtUpd01                                     */  
/* Purpose: Check if user login with printer                            */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2018-11-19 1.0  Ung       WMS-6932 Created                           */  
/* 2819-01-03 1.1  Ung       WMS-6932 Fix ID param optional             */
/* 2019-03-29 1.2  James     WMS-8002 Add TaskDetailKey param (james02) */		
/* 2021-07-06 1.3  YeeKung   WMS-17278 Add Reasonkey (yeekung01)        */																	
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_844ExtUpd01] (  
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT,          
   @nInputKey    INT,          
   @cStorerKey   NVARCHAR( 15),
   @cRefNo       NVARCHAR( 10),
   @cPickSlipNo  NVARCHAR( 10),
   @cLoadKey     NVARCHAR( 10),
   @cOrderKey    NVARCHAR( 10),
   @cDropID      NVARCHAR( 20),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,          
   @cOption      NVARCHAR( 1), 
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT,
   @cID          NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 10) = '',
   @cReasonCode  NVARCHAR(20) OUTPUT 										  
)  
AS  
  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 844 -- Post pick audit (Pallet ID)
   BEGIN
      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN  
            -- Check pallet at stage
            IF EXISTS( SELECT TOP 1 1 
               FROM rdt.rdtPPA WITH (NOLOCK)
               WHERE SKU = @cSKU
                  AND StorerKey = @cStorerKey
                  AND ID = @cID
                  AND PQTY <> CQTY)
            BEGIN
               SET @nErrNo = 132201
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not match
               GOTO Quit
            END            
         END
      END
   END
   
Quit:  
 

GO