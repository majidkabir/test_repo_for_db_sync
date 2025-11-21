SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/ 
/* Store procedure: rdt_1836ExtInfo01                                   */   
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2020-07-29   YeeKung   1.0   WMS-14059 Created                       */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1836ExtInfo01]  
  @nMobile         INT,          
  @nFunc           INT,          
  @cLangCode       NVARCHAR( 3), 
  @nStep           INT,          
  @nAfterStep      INT,          
  @nInputKey       INT,           
  @cTaskdetailKey  NVARCHAR( 10),
  @cFinalLOC       NVARCHAR( 10),
  @cExtendedInfo   NVARCHAR( 20) OUTPUT,
  @nErrNo          INT           OUTPUT,
  @cErrMsg         NVARCHAR( 20) OUTPUT 
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   declare @cFromID nvarchar(20)

   SELECT 
      @cFromID  = fromid    
   FROM Taskdetail (Nolock)
   WHERE taskdetailkey=@ctaskdetailkey

   SET @cExtendedInfo= 'ID:' + @cFromID

END  

GO