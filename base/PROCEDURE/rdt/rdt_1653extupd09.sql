SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************************/  
/* Store procedure: rdt_1653ExtUpd09                                                */  
/* Copyright      : Maersk                                                          */  
/* Customer       : Granite                                                         */  
/*                                                                                  */  
/* Called from: rdtfnc_TrackNo_SortToPallet                                         */  
/*                                                                                  */  
/* Purpose: Prompt a screen to display message: Pallet Closed                       */  
/*                                                                                  */  
/* Modifications log:                                                               */  
/* Date        Rev    Author   Purposes                                             */  
/* 2024-12-19  1.0.0  NLT013   FCR-1316 Created                                     */  
/************************************************************************************/  
  
CREATE   PROC [RDT].[rdt_1653ExtUpd09] (  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cTrackNo       NVARCHAR( 40),  
   @cOrderKey      NVARCHAR( 20),  
   @cPalletKey     NVARCHAR( 20),  
   @cMBOLKey       NVARCHAR( 10),  
   @cLane          NVARCHAR( 30),  
   @tExtValidVar   VariableTable READONLY,  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE
      @cPalletCloseStatus           NVARCHAR(10)

   SET @cPalletCloseStatus = rdt.RDTGetConfig( @nFunc, 'PalletCloseStatus', @cStorerkey)
   IF @cPalletCloseStatus = '0'
      SET @cPalletCloseStatus = '9'
  
   IF @nFunc = 1653
   BEGIN
      IF @nStep = 4
      BEGIN  
         IF @nInputKey = 1  
         BEGIN  
            IF EXISTS(SELECT 1 
                     FROM dbo.Pallet WITH(NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND PalletKey = @cPalletKey 
                        AND Status = @cPalletCloseStatus)
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile = @nMobile, 
                     @nErrNo = @nErrNo OUTPUT, 
                     @cErrMsg = @cErrMsg OUTPUT, 
                     @cLine01 = @cPalletKey, 
                     @cLine02 = 'Pallet Closed', 
                     @nDisplayMsg = 0

               SET @nErrNo = 0
               SET @cErrMsg = ''
            END
         END  
      END  
   END
  
   GOTO Quit  

   Quit:  
END  

GO