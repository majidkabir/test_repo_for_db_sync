SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: isp_JACKWExtInfoSP03                                */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: JACKW Int order tote sort to show qty 2 move in whole tote  */    
/*                                                                      */    
/* Called from: rdtfnc_ToteConsolidation                                */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2014-09-05 1.0  James    SOS319877 Created                           */    
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_JACKWExtInfoSP03]    
   @nMobile       INT, 
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT, 
   @nInputKey     INT, 
   @cStorerKey    NVARCHAR( 15), 
   @cFromTote     NVARCHAR (18), 
   @cSKU          NVARCHAR( 20), 
   @nQtyMv        INT, 
   @cToTote       NVARCHAR( 18), 
   @cConsoOption  NVARCHAR( 1), 
   @c_oFieled01   NVARCHAR( 20) OUTPUT 
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @nQtyAvl INT 
   
   IF @nStep = 10 AND @nInputKey = 1
   BEGIN
      SELECT @nQtyAvl = ISNULL( SUM( PD.Qty), 0)      
      FROM dbo.PickDetail PD WITH (NOLOCK)     
      JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = PD.OrderKey     
      JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   
      JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  
      WHERE PD.StorerKey = @cStorerKey                  
      AND   PD.DropID = @cFromTote                  
      AND   PD.Status >= '5'                  
      AND   PD.Status < '9'    
      AND   PD.Qty > 0          
      AND   TD.PickMethod = 'PIECE'        
      AND   TD.Status = '9'       
      AND   O.Status < '9'   
      AND   TD.SKU = @cSKU  
     
     insert into traceinfo (tracename, timein, col1) values ('totec', getdate(), @nQtyAvl)
      SET @c_oFieled01 = 'QTY MV: ' + CAST( @nQtyAvl AS NVARCHAR( 5))
   END
     
QUIT:    
END -- End Procedure  

GO