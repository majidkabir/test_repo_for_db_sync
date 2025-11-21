SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1766ExtInfo01                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Show total qty scanned on tm cc sku                         */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2020-01-07 1.0  James    WMS-11550. Created                          */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1766ExtInfo01]    
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 15),
   @cStorerKey      NVARCHAR( 15),
   @cTaskdetailkey  NVARCHAR( 20),
   @cFromLoc        NVARCHAR( 20),
   @cID             NVARCHAR( 20),
   @cPickMethod     NVARCHAR( 20),
   @tExtInfo        VariableTable READONLY,
   @cExtendedInfo   NVARCHAR( 20) OUTPUT

AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @nLLI_Qty     INT
   DECLARE @nCC_Qty      INT
   
   IF @nStep IN ( 1, 2)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @nLLI_Qty = ISNULL( SUM(QTY - QTYPICKED), 0)    
         FROM dbo.LotxLocxID LLI WITH (NOLOCK)    
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)    
         WHERE LLI.Loc = @cFromLoc
         AND   (( ISNULL( @cID, '') = '') OR ( LLI.ID = @cID))    
         AND   LOC.Facility = @cFacility    
         
         SELECT @nCC_Qty = ISNULL( SUM( Qty), 0)
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCSheetNo = @cTaskdetailkey
         
         SET @cExtendedInfo = 'ID QTY:' + CAST( @nCC_Qty AS NVARCHAR( 5)) + '/' + CAST( @nLLI_Qty AS NVARCHAR( 5))
      END
   END
QUIT:    
END -- End Procedure  

GO