SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: rdt_TM_ExtDyPickJW                                       */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: SOS#315989 - Jack Will TM Dynamic Picking Ext update             */  
/*                     - Called By rdtfnc_TM_DynamicPick                     */  
/*                     - Call diff extended sp based on task type            */
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2014-07-24 1.0  James    Created                                          */  
/*****************************************************************************/  
CREATE PROC [RDT].[rdt_TM_ExtDyPickJW](  
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT, 
   @nInputKey       INT, 
   @cDropID         NVARCHAR( 20), 
   @cToToteno       NVARCHAR( 20), 
   @cLoadkey        NVARCHAR( 10), 
   @cTaskStorer     NVARCHAR( 15), 
   @cSKU            NVARCHAR( 20), 
   @cFromLoc        NVARCHAR( 10), 
   @cID             NVARCHAR( 18), 
   @cLot            NVARCHAR( 10), 
   @cTaskdetailkey  NVARCHAR( 10), 
   @nPrevTotQty     INT, 
   @nBoxQty         INT, 
   @nTaskQty        INT, 
   @nTotPickQty     INT   OUTPUT, 
   @nErrNo          INT   OUTPUT, 
   @cErrMsg         NVARCHAR( 20)  OUTPUT 
) AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cTaskType      NVARCHAR( 10)

   SELECT @cTaskType = TaskType FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskdetailkey

   IF ISNULL( @cTaskType, '') NOT IN ('DPK', 'DRP')
      GOTO QUIT

   IF @cTaskType = 'DPK'
   BEGIN
      EXEC [RDT].[rdt_TM_DyLogPickJW01] 
         @nMobile         , 
         @nFunc           , 
         @cLangCode       , 
         @nStep           , 
         @nInputKey       , 
         @cDropID         , 
         @cToToteno       , 
         @cLoadkey        , 
         @cTaskStorer     , 
         @cSKU            , 
         @cFromLoc        , 
         @cID             , 
         @cLot            , 
         @cTaskdetailkey  , 
         @nPrevTotQty     , 
         @nBoxQty         , 
         @nTaskQty        , 
         @nTotPickQty     OUTPUT, 
         @nErrNo          OUTPUT, 
         @cErrMsg         OUTPUT    
   END
   ELSE
   BEGIN
      EXEC [RDT].[rdt_TM_DyReplenJW01] 
         @nMobile         , 
         @nFunc           , 
         @cLangCode       , 
         @nStep           , 
         @nInputKey       , 
         @cDropID         , 
         @cToToteno       , 
         @cLoadkey        , 
         @cTaskStorer     , 
         @cSKU            , 
         @cFromLoc        , 
         @cID             , 
         @cLot            , 
         @cTaskdetailkey  , 
         @nPrevTotQty     , 
         @nBoxQty         , 
         @nTaskQty        , 
         @nTotPickQty     OUTPUT, 
         @nErrNo          OUTPUT, 
         @cErrMsg         OUTPUT 
   END

   Quit:

GO