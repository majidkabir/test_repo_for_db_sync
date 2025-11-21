SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
    
/************************************************************************/    
/* Store procedure: rdt_1812ExtInfo05                                   */    
/* Purpose: Display custom info                                         */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date         Author    Ver.  Purposes                                */    
/* 2020-02-14   YeeKung   1.0  WMS-12082 Created                        */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1812ExtInfo05]    
    @nMobile         INT     
   ,@nFunc           INT     
   ,@cLangCode       NVARCHAR( 3)     
   ,@nStep           INT     
   ,@cTaskdetailKey  NVARCHAR( 10)    
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT    
   ,@nErrNo          INT           OUTPUT     
   ,@cErrMsg         NVARCHAR( 20) OUTPUT    
   ,@nAfterStep      INT     
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @cPickMethod NVARCHAR(10)  
  
   DECLARE @cErrMsg01         NVARCHAR( 20)    
   DECLARE @cErrMsg02         NVARCHAR( 20)    
   DECLARE @cErrMsg03         NVARCHAR( 20)    
   DECLARE @cErrMsg04         NVARCHAR( 20)    
   DECLARE @cErrMsg05         NVARCHAR( 20)  
   DECLARE @cStorerCompany    NVARCHAR( 40)  
   DECLARE @cStorerCompany1   NVARCHAR( 20)  
   DECLARE @cStorerCompany2   NVARCHAR( 20)   
   DECLARE @cStorerCity       NVARCHAR( 20)     
    
   -- Get TaskDetail info    
   SELECT @cPickMethod = PickMethod    
   FROM TaskDetail WITH (NOLOCK)    
   WHERE TaskDetailKey = @cTaskDetailKey             
    
   -- TM Pallet Pick    
   IF @nFunc = 1812    
   BEGIN    
      IF @nAfterStep = 2 -- Next task     
      BEGIN   
         DECLARE @cSKU NVARCHAR(20)    
         DECLARE @cSKUDESC NVARCHAR(60)    
         DECLARE @cQty INT   
  
         SELECT @cSKU = SKU,@cQty=SystemQty FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey   
  
         SELECT @cSKUDESC=DESCR FROM SKU WITH (NOLOCK) WHERE SKU=@cSKU  
  
         SET @nErrNo = ''  
         SET @cErrMsg01=@cSKU  
         SET @cErrMsg02=SUBSTRING( @cSKUDESC, 1, 20)  
         SET @cErrMsg03=SUBSTRING( @cSKUDESC, 21, 40)  
         SET @cErrMsg04=@cQty  
    
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,  
         'SKU:',      
         @cErrMsg01,  
         'SKU DESC:',   
         @cErrMsg02,   
         @cErrMsg03,   
         'QTY:',   
         @cErrMsg04  
  
         SET @nErrNo = 0     
           
   
      END   
          
      IF @nAfterStep = 7 -- Next task     
      BEGIN    
         -- Get LoadKey    
         DECLARE @cLoadKey NVARCHAR(10)    
         DECLARE @nBookingNo INT    
             
         SELECT @cLoadKey = LoadKey FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey    
         SELECT @nBookingNo = BookingNo FROM LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey    
         SELECT @cStorerCompany = O.C_Company,@cStorerCity=O.C_City 
         FROM TaskDetail TD WITH (NOLOCK) JOIN  PickDetail PD WITH (NOLOCK)  
         ON PD.taskdetailkey=TD.taskdetailkey JOIN ORDERS O WITH (NOLOCK) 
         ON O.ORDERKEY=PD.ORDERKEY
         WHERE TD.TaskDetailkey=@cTaskDetailKey 
  
         SET  @cStorerCompany1=SUBSTRING( @cStorerCompany, 1, 20)   
         SET  @cStorerCompany2=SUBSTRING( @cStorerCompany, 21, 40)   
  
         SET @nErrNo = ''  
         SET @cErrMsg01=@cLoadKey  
         SET @cErrMsg02=@nBookingNo  
         SET @cErrMsg03=@cStorerCompany1  
         SET @cErrMsg04=@cStorerCompany2  
         SET @cErrMsg05=@cStorerCity  
    
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,  
         'Load Key:',      
         @cErrMsg01,  
         'Booking No:',   
         @cErrMsg02,  
         'Consignee Name:',   
         @cErrMsg03,   
         @cErrMsg04,  
         'Consignee City:',   
         @cErrMsg05  
  
         SET @nErrNo = 0    
      END    
   END    
END

GO