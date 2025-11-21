SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_855ExtValid03                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Check user input qty vs system qty. If both value not same  */  
/*          prompt screen to alert user                                 */
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2019-04-17  1.0  James    WMS-7983 Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_855ExtValid03] (  
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @cStorer        NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cRefNo         NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cDropID        NVARCHAR( 20),
   @cLoadKey       NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cID            NVARCHAR( 18) = '',
   @cTaskDetailKey NVARCHAR( 10) = '',
   @tExtValidate   VariableTable READONLY

) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nInputKey      INT,
           @nQTY           INT,
           @nQTY_PPA       INT,
           @nQTY_CHK       INT,
           @cErrMsg1       NVARCHAR( 20)

   -- Variable mapping
   SELECT @nQTY = Value FROM @tExtValidate WHERE Variable = '@nQTY'
   SELECT @nQTY_PPA = Value FROM @tExtValidate WHERE Variable = '@nQTY_PPA'
   SELECT @nQTY_CHK = Value FROM @tExtValidate WHERE Variable = '@nQTY_CHK'
   SELECT @nInputKey = Value FROM @tExtValidate WHERE Variable = '@nInputKey'

   IF @nFunc = 855   -- Drop ID
   BEGIN
      IF @nStep = 3  -- SKU/UPC, Qty
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF ( @nQTY + @nQTY_CHK) <> @nQTY_PPA
            BEGIN
               SET @cErrMsg1 = rdt.rdtgetmessage( 137651, @cLangCode, 'DSP') --DISCREPANCY FOUND:
            
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1

               SET @nErrNo = 0
               SET @cErrMsg = ''
            END
         END
      END
   END

   Quit:      

END  


GO