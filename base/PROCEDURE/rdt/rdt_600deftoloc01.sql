SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_600DefToLoc01                                   */      
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Purpose: Default To Loc based on CODELKUP setup                      */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date         Author    Ver.  Purposes                                */      
/* 2022-04-27   James     1.0   WMS-22265 Created                       */      
/************************************************************************/      
      
CREATE   PROCEDURE [RDT].[rdt_600DefToLoc01]      
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
   @cReceiptKey     NVARCHAR( 10),
   @cPOKey          NVARCHAR( 10),
   @cDefaultToLOC   NVARCHAR( 10)  OUTPUT,
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
   
   DECLARE @cLong          NVARCHAR( 250)
   DECLARE @cDocType       NVARCHAR( 1)
   
   IF @nStep = 1    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
      	SELECT @cDocType = DOCTYPE
      	FROM dbo.RECEIPT WITH (NOLOCK)
      	WHERE StorerKey = @cStorerKey
      	AND   ReceiptKey = @cReceiptKey
      	
         SELECT @cLong = Long
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'CUSTPARAM'
         AND   Code = 'ASNTYPE'
         AND   Storerkey = @cStorerKey
         AND   UDF01 = @cDocType
         
         SET @cDefaultToLOC = SUBSTRING( @cLong, 1, 10)
      END    
   END    
    
   Quit:                   

END      
SET QUOTED_IDENTIFIER OFF 

GO