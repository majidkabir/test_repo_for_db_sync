SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_760GetTaskSP03                                  */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2016-07-25  1.0  ChewKP   Created                                    */  
/************************************************************************/  
CREATE PROC [RDT].[rdt_760GetTaskSP03] (  
   @nMobile        INT,                
   @nFunc          INT,                
   @cLangCode      NVARCHAR(3),        
   @nStep          INT,                
   @cUserName      NVARCHAR( 18),       
   @cFacility      NVARCHAR( 5),        
   @cStorerKey     NVARCHAR( 15),       
   @cDropID        NVARCHAR( 20),       
   @cSKU           NVARCHAR( 20),       
   @nQty           INT,                 
   @cLabelNo       NVARCHAR( 20),    
   @cPTSPosition   NVARCHAR( 20),   
   @cPTSLogKey     NVARCHAR( 20) OUTPUT, 
   @cScnLabel      NVARCHAR( 20) OUTPUT,
   @cScnText       NVARCHAR( 20) OUTPUT,  
   @nErrNo         INT OUTPUT,   
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE  @nTranCount        INT  
          , @cOrderKey             NVARCHAR(10)
          , @cLoc                  NVARCHAR(10) 
          , @nExpectedQty          INT
          , @cLot                  NVARCHAR(10)
          , @cConsigneeKey         NVARCHAR(15)
          , @cCondition            INT
          , @cPacKKey              NVARCHAR(10) 
          , @nCaseCNT              INT

   SET @nErrNo                = 0  
   SET @cErrMsg               = '' 
  
   SET @nTranCount = @@TRANCOUNT
   
   BEGIN TRAN
   SAVE TRAN rdt_760GetTaskSP03
   
   IF @nFunc = 760
   BEGIN
      
      IF @nStep = 1
      BEGIN
          SET @cPTSLogKey = ''
          SET @cScnText = ''
          
          IF @cCondition = '1' 
          BEGIN
             
            DECLARE CursorPTSLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR          
            
            SELECT DropID, SKU, SUM(QTY)  FROM rdt.rdtPTSLog WITH (NOLOCK) 
            GROUP BY DropID , StorerKey , SKU, AddWho, Status
            HAVING StorerKey = @cStorerKey 
            AND COUNT(DISTINCT ORDERKEY) = 1 
            AND AddWho = @cUserName  
            AND Status = '0'  
            
             
            OPEN  CursorPTSLog      
         
            FETCH NEXT FROM CursorPTSLog INTO @cDropID, @cSKU, @nQty  
            
            WHILE @@FETCH_STATUS <> -1           
            BEGIN      
               
               SELECT @cPacKKey = PacKKey 
               FROM dbo.SKU WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
               AND SKU = @cSKU 
               
               SELECT @nCaseCNT = CaseCNT
               FROM dbo.Pack WITH (NOLOCK) 
               WHERE PacKKey = @cPacKKey 
               
               IF @nQty = @nCaseCNT 
               BEGIN 
                  
                  SELECT TOP 1   
                         @cScnText         = PTSLOG.ConsigneeKey  
                       , @cPTSLogKey       = PTSLog.PTSLogKey  
                  FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)   
                  WHERE PTSLOG.StorerKey = @cStorerKey  
                  AND PTSLOG.AddWho = @cUserName  
                  AND Status = '0'  
                  AND DropID = @cDropID
                  
                  BREAK
               END
               
               FETCH NEXT FROM CursorPTSLog INTO @cDropID, @cSKU, @nQty     
            END
            CLOSE CursorPTSLog               
            DEALLOCATE CursorPTSLog   
            
          END          
          
          IF ISNULL(@cPTSLogKey,'')  = '' 
          BEGIN
             SELECT TOP 1   
                        @cScnText         = PTSLOG.ConsigneeKey  
                      , @cPTSLogKey       = PTSLog.PTSLogKey  
             FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)   
             WHERE PTSLOG.StorerKey = @cStorerKey  
             AND PTSLOG.AddWho = @cUserName  
             AND Status = '0'  
             ORDER BY PTSLOG.PTSPosition, PTSLOG.SKU, PTSLOG.PTSLOGKEY    
          END
          
          IF ISNULL(@cPTSLogKey,'')  = ''
          BEGIN
            
            SET @cScnLabel = ''
            SET @cScnText  = ''
            
            SET @nErrNo = 1
            --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoTask'
            GOTO RollBackTran
          END
          ELSE
          BEGIN
            SET @cScnLabel = 'CONSIGNEEKEY:'
            
          END
         
      END
      
      IF @nStep = 4
      BEGIN
          SET @cPTSLogKey = ''
          SET @cScnText = ''
          
          SELECT TOP 1   
                     @cScnText         = PTSLOG.ConsigneeKey  
                   , @cPTSLogKey       = PTSLog.PTSLogKey  
          FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)   
          WHERE PTSLOG.StorerKey = @cStorerKey  
          AND PTSLOG.AddWho = @cUserName  
          AND Status = '0'  
          AND PTSPosition = @cPTSPosition 
          ORDER BY PTSLOG.PTSPosition, PTSLOG.SKU, PTSLOG.PTSLOGKEY    

          IF ISNULL(@cPTSLogKey,'' )  = ''
          BEGIN
             SELECT TOP 1   
                        @cScnText         = PTSLOG.ConsigneeKey  
                      , @cPTSLogKey       = PTSLog.PTSLogKey  
             FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)   
             WHERE PTSLOG.StorerKey = @cStorerKey  
             AND PTSLOG.AddWho = @cUserName  
             AND Status = '0'  
             ORDER BY PTSLOG.PTSPosition, PTSLOG.SKU, PTSLOG.PTSLOGKEY    
          END
         
      END
      
   END   



   GOTO QUIT 
   
RollBackTran:
   ROLLBACK TRAN rdt_760GetTaskSP03 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_760GetTaskSP03
  

END  


GO