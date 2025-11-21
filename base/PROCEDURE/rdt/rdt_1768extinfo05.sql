SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/            
/* Store procedure: rdt_1768ExtInfo05                                   */            
/* Copyright      : Maersk                                              */            
/*                                                                      */            
/* Purpose: Prompt msg when systemqty <> user scanned qty               */            
/*                                                                      */            
/* Called from: rdtfnc_TM_CycleCount_SKU                                */            
/*                                                                      */            
/* Modifications log:                                                   */            
/*                                                                      */            
/* Date       Rev  Author   Purposes                                    */            
/* 2023-08-03 1.0  James    WMS-23166. Created                          */            
/************************************************************************/            
            
CREATE   PROCEDURE [RDT].[rdt_1768ExtInfo05]            
   @nMobile          INT,         
   @nFunc            INT,         
   @cLangCode        NVARCHAR( 3),         
   @nStep            INT,         
   @nInputKey        INT,         
   @cStorerKey       NVARCHAR( 15),         
   @cTaskDetailKey   NVARCHAR( 10),         
   @cCCKey           NVARCHAR( 10),         
   @cCCDetailKey     NVARCHAR( 10),         
   @cLoc             NVARCHAR( 10),         
   @cID              NVARCHAR( 18),         
   @cSKU             NVARCHAR( 20),         
   @nActQTY          INT,          
   @cLottable01      NVARCHAR( 18),         
   @cLottable02      NVARCHAR( 18),         
   @cLottable03      NVARCHAR( 18),         
   @dLottable04      DATETIME,         
   @dLottable05      DATETIME,         
   @cLottable06      NVARCHAR( 30),         
   @cLottable07      NVARCHAR( 30),         
   @cLottable08      NVARCHAR( 30),         
   @cLottable09      NVARCHAR( 30),         
   @cLottable10      NVARCHAR( 30),         
   @cLottable11      NVARCHAR( 30),         
   @cLottable12      NVARCHAR( 30),         
   @dLottable13      DATETIME,         
   @dLottable14      DATETIME,         
   @dLottable15      DATETIME,        
   @cExtendedInfo    NVARCHAR( 20) OUTPUT         
        
AS            
BEGIN            
   SET NOCOUNT ON            
   SET QUOTED_IDENTIFIER OFF            
   SET ANSI_NULLS OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
               
   DECLARE @cErrMsg01        NVARCHAR( 20),  
           @cErrMsg02        NVARCHAR( 20),  
           @cErrMsg03        NVARCHAR( 20),
           @cTaskType        NVARCHAR( 10),
           @nErrNo           INT,
           @cErrMsg          NVARCHAR( 20)

   DECLARE @nCC_Qty  INT
              
   IF @nStep = 2  
   BEGIN          
   	IF @nInputKey = 1
   	BEGIN
         SELECT @nCC_Qty = ISNULL( SUM( Qty), 0)
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCSheetNo = @cTaskdetailkey
         AND   Loc = @cLoc

         SET @cExtendedInfo = 'TTL QTY: ' + CAST( @nCC_Qty AS NVARCHAR( 5))
   	END
   	
      IF @nInputKey = 0
      BEGIN
      	SELECT @cTaskType = TaskType
      	FROM dbo.TaskDetail WITH (NOLOCK)
      	WHERE TaskDetailKey = @cTaskDetailKey
      	
      	-- If existing any SKU in one Loc system qty <> actual CC qty  
      	IF EXISTS ( SELECT 1 
      	            FROM dbo.CCDetail CC WITH (NOLOCK)
      	            WHERE CC.Storerkey = @cStorerKey
      	            AND   CC.Loc = @cLoc
      	            AND   CC.SystemQty <> CC.Qty
      	            --AND   CC.[Status] IN ( '2', '4')
      	            AND   CC.CCSheetNo = @cTaskDetailKey
      	            AND   EXISTS ( SELECT 1
      	                           FROM dbo.TaskDetail TD WITH (NOLOCK)
      	                           WHERE CC.CCSheetNo = TD.TaskDetailKey
      	                           AND   CC.Storerkey = TD.Storerkey
      	                           AND   TD.TaskType = @cTaskType
      	                           AND   TD.[Status] > '0'
      	                           AND   TD.[Status] < '9'))
         BEGIN
         	SET @cErrMsg01 = rdt.rdtgetmessage( 204851, @cLangCode, 'DSP')  -- SYSTEM QTY
         	SET @cErrMsg02 = rdt.rdtgetmessage( 204852, @cLangCode, 'DSP')  -- NOT TALLY WITH
         	SET @cErrMsg03 = rdt.rdtgetmessage( 204853, @cLangCode, 'DSP')  -- ACTUAL CC QTY

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
            @cErrMsg01, @cErrMsg02, @cErrMsg03  

            SET @nErrNo = 0   -- Reset error no 
         END
      END	
   END
     
QUIT:            
END -- End Procedure 

GO