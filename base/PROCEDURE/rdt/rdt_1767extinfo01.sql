SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1767ExtInfo01                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Show total qty scanned on tm cc ucc                         */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2020-05-07 1.0  James    WMS-16965. Created                          */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1767ExtInfo01]    
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
       
   DECLARE @nCC_Qty     INT
   DECLARE @nUCC_Count  INT
   
   SELECT @nCC_Qty = ISNULL( SUM( Qty), 0)
   FROM dbo.CCDetail WITH (NOLOCK)
   WHERE CCSheetNo = @cTaskdetailkey
   AND   Loc = @cLoc

   SELECT @nUCC_Count = COUNT( DISTINCT RefNo)
   FROM dbo.CCDetail WITH (NOLOCK)
   WHERE CCSheetNo = @cTaskdetailkey
   AND   Loc = @cLoc
   AND   RefNo <> ''
   AND   [Status] IN ('2', '4')
   GROUP BY CCSheetNo
   
   SET @cExtendedInfo = 'QTY: ' + CAST( @nCC_Qty AS NVARCHAR( 5)) + 
                        ' UCC: ' + CAST( @nUCC_Count AS NVARCHAR( 5))

QUIT:    
END -- End Procedure  

GO