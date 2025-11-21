SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: LF                                                              */                 
/* Purpose: Ext update                                                        */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-08-28 1.0  YeeKung    WMS-12575 Created                               */                
/******************************************************************************/ 

CREATE PROC [RDT].[rdt_645ExtUpd01] (    
   @nMobile      INT,              
   @nFunc        INT,          
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT,          
   @nInputKey    INT,          
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cSKU         NVARCHAR( 20),
   @cID          NVARCHAR( 20),
   @cBatchCode   NVARCHAR( 60),
   @cCartonSN    NVARCHAR( 60),
   @cBottleSN    NVARCHAR( 100),
   @nQTYPICKED   INT,          
   @nQTYCSN      INT,          
   @cUOM         NVARCHAR(5), 
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   IF @nFunc = 645 
   BEGIN  
      DECLARE @nTranCount    INT

      SET @nTranCount = @@TRANCOUNT    
    
      BEGIN TRAN    
      SAVE TRAN rdt_645ExtUpd01    

      IF @nStep = 6 -- bottleSN
      BEGIN
         IF @cBottleSN='CANC'
         BEGIN
            DELETE TRACKINGID
            where storerkey=@cStorerKey
            AND sku=@cSKU
            AND userdefine01=@cReceiptKey
            AND userdefine02=@cID
            and userdefine03=@cBatchCode
            and parenttrackingid=@cCartonSN

            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 158201    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --@cBottleSNRequire  
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            INSERT INTO TRACKINGID (TrackingID,storerkey,SKU,UOM,QTY,PARENTTRACKINGID,userdefine01,userdefine02,userdefine03)
            VALUES(@cBottleSN,@cStorerKey,@cSKU,@cUOM,'1',@cCartonSN,@cReceiptKey,@cID,@cBatchCode)

            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 158202   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --@cBottleSNRequire  
               GOTO RollBackTran
            END
         END
      END

      GOTO Quit
   END  
RollBackTran:    
   ROLLBACK TRAN rdt_645ExtUpd01    
    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN rdt_645ExtUpd01    

GO