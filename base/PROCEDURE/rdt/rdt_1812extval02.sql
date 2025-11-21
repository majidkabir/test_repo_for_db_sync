SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1812ExtVal02                                    */  
/* Purpose: Validate DropID                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2020-02-01   YeeKung   1.0   WMS-12082 Create                        */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1812ExtVal02]  
    @nMobile         INT   
   ,@nFunc           INT   
   ,@cLangCode       NVARCHAR( 3)   
   ,@nStep           INT   
   ,@nInputKey       INT  
   ,@cTaskdetailKey  NVARCHAR( 10)  
   ,@cDropID         NVARCHAR( 20)  
   ,@nQTY            INT  
   ,@cToLOC          NVARCHAR( 10)  
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cPickQty int,  
           @cFROMLOCCATEGORY NVARCHAR(20),  
           @cStorerkey NVARCHAR( 20),  
           @cSku NVARCHAR( 20),  
           @cTaskSKU NVARCHAR( 20),  
           @cTotalSKUCBM FLOAT=0.0,  
           @cSKUSTDCube FLOAT,  
           @cMaxVolCBM  INT  
  
   -- TM Pallet Pick  
   IF @nFunc = 1812  
   BEGIN  
      IF @nStep = 4 --SKU  
      BEGIN  
  
         SELECT @cStorerkey=storerkey  
         FROM RDT.RDTMOBREC (NOLOCK)  
         WHERE mobile =@nMobile  
  
         DECLARE TotalCBM CURSOR LOCAL FOR   
         SELECT SUM(Qty),sku  
         FROM PickDetail (NOLOCK)  
         WHERE DropID=@cDropID  
         AND status='5'  
         GROUP BY Sku  
         
         SET @cPickQty=ISNULL(@cPickQty,0)  
  
         SELECT @cFROMLOCCATEGORY=LOC.LOCATIONCATEGORY,@cTaskSKU=SKU  
         FROM TASKDETAIL TD (NOLOCK) JOIN LOC LOC (NOLOCK)  
         ON TD.FROMLOC=LOC.LOC  
         WHERE TD.TASKDETAILKEY=@cTaskdetailKey  
  
         IF (@cFROMLOCCATEGORY='BULK')  
         BEGIN  
            IF (@cPickQty+@nQTY >4)  
            BEGIN  
               SET @nErrNo = 148601     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Exceed Pick Qty  
               GOTO Quit    
            END  
         END  
         ELSE  
         BEGIN  
            IF (@cTaskSKU<>@cSku)  
            BEGIN  
                 
               OPEN TotalCBM;  
  
               FETCH NEXT FROM TotalCBM INTO @cPickQty,@cSku;  
  
               WHILE @@FETCH_STATUS = 0  
               BEGIN  
                  SELECT @cSKUSTDCube=stdcube   
                  FROM SKU WITH (NOLOCK)  
                  WHERE SKU=@cSku  
  
                  SET @cTotalSKUCBM=@cTotalSKUCBM+@cSKUSTDCube*@cPickQty  
                    
                  FETCH NEXT FROM TotalCBM INTO @cPickQty,@cSku;  
               END;  
  
               CLOSE TotalCBM;  
               DEALLOCATE TotalCBM;  
  
               SELECT @cSKUSTDCube=stdcube   
               FROM SKU WITH (NOLOCK)  
               WHERE SKU=@cTaskSKU  
  
               SET @cTotalSKUCBM=@cTotalSKUCBM+@cSKUSTDCube*@nQTY  
  
               SET @cMaxVolCBM = rdt.RDTGetConfig( @nFunc, 'MaxVolCBM', @cStorerKey)   
  
               IF (@cMaxVolCBM <>'')  
               BEGIN   
                  IF @cTotalSKUCBM > @cMaxVolCBM  
                  BEGIN  
                     SET @nErrNo = 148602     
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Exceed PalletVol  
                     GOTO Quit   
                  END  
               END  
  
            END  
         END  
  
      END  
   END  
   GOTO Quit  
  
Quit:  
  
END  

GO