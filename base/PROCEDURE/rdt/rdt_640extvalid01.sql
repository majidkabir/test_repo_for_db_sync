SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_640ExtValid01                                   */  
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Disable qty field based on product type                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2020-06-20   James     1.0   WMS-12055 Created                       */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_640ExtValid01]  
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,         
   @nInputKey      INT,         
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cGroupKey      NVARCHAR( 10),
   @cTaskDetailKey NVARCHAR( 10),
   @cCartId        NVARCHAR( 10),
   @cFromLoc       NVARCHAR( 10),
   @cCartonId      NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @nQty           INT,         
   @cOption        NVARCHAR( 1),
   @tExtValidate   VariableTable READONLY, 
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cErrMsg1       NVARCHAR( 20)
   DECLARE @cErrMsg2       NVARCHAR( 20)
   
   SELECT @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF @nStep = 10
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Something already picked, cannot abort. Must continue
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                     WHERE Groupkey = @cGroupKey
                     AND   DeviceID = @cCartId
                     AND   TaskType = 'CPK'
                     AND   UserKeyOverRide = @cUserName
                     AND   [Status] = '5')
         BEGIN
            SET @cErrMsg1 = rdt.rdtgetmessage( 156901, @cLangCode, 'DSP') 
            SET @cErrMsg2 = rdt.rdtgetmessage( 156902, @cLangCode, 'DSP') 
            
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg1, 
               '', 
               @cErrMsg2

            SET @nErrNo = 156901
            SET @cErrMsg = @cErrMsg2
         END
                     
      END
   END
END  
SET QUOTED_IDENTIFIER OFF 

GO