SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_760GetTaskSP05                                  */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2018-04-11  1.0  Ung      WMS-4300 Created                           */ 
/************************************************************************/  
CREATE PROC [RDT].[rdt_760GetTaskSP05] (  
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
   @nErrNo         INT           OUTPUT,   
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   IF @nFunc = 760 -- Sort and pack
   BEGIN
      IF @nStep = 1 -- Drop ID
      BEGIN
         SET @cPTSLogKey = ''
         SET @cScnLabel = ''
         SET @cScnText = ''
          
         SELECT TOP 1   
            @cPTSLogKey = PTSLogKey, 
            @cScnLabel = 'CONSIGNEEKEY:', 
            @cScnText = ConsigneeKey
         FROM rdt.rdtPTSLog WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
            AND AddWho = @cUserName  
            AND Status = '0'  
         ORDER BY PTSPosition, DropID, SKU, LabelNo

         IF @cPTSLogKey = ''
            SET @nErrNo = 1 -- No task
      END
      
      IF @nStep = 4 -- To LabelNo
      BEGIN
          SET @cPTSLogKey = ''
          SET @cScnText = ''
          
          -- Get task in current position
          SELECT TOP 1   
             @cScnText = PTSPosition,   
             @cPTSLogKey = PTSLogKey
          FROM rdt.rdtPTSLog WITH (NOLOCK)   
          WHERE StorerKey = @cStorerKey  
             AND AddWho = @cUserName  
             AND Status = '0'  
             AND PTSPosition = @cPTSPosition 
          ORDER BY PTSPosition, DropID, SKU, LabelNo    

          -- Get task for next position
          IF @cPTSLogKey = ''
             SELECT TOP 1   
                @cScnText = PTSPosition,   
                @cPTSLogKey = PTSLogKey
             FROM rdt.rdtPTSLog WITH (NOLOCK)   
             WHERE StorerKey = @cStorerKey  
                AND AddWho = @cUserName  
                AND Status = '0'  
             ORDER BY PTSPosition, DropID, SKU, LabelNo    
      END
   END   
END  

GO