SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_1855ExtInfo01                                      */  
/* Copyright: LF logistics                                                 */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author     Purposes                                     */  
/* 2022-02-10 1.0  Ung        WMS-18884 Created                            */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_1855ExtInfo01] (  
   @nMobile        INT,            
   @nFunc          INT,            
   @cLangCode      NVARCHAR( 3),   
   @nStep          INT,            
   @nAfterStep     INT,            
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
   @tExtInfo       VariableTable READONLY,    
   @cExtendedInfo  NVARCHAR( 20) OUTPUT    
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   IF @nFunc = 1855 -- TM assist cluster pick
   BEGIN
      IF @nAfterStep = 4 -- SKU, QTY
      BEGIN  
         -- Get position
         DECLARE @cPosition NVARCHAR( 20)
         SELECT @cPosition = StatusMsg
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
      
         SET @cExtendedInfo = LEFT( 'POSITION: ' + @cPosition, 20)
      END
   END
   
Quit:


GO