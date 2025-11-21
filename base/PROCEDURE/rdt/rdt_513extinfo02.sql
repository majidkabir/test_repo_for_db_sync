SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_513ExtInfo02                                          */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Display SKU pack configuration                                    */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 2020-04-02   YeeKung   1.0   WMS-12739 Created                             */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_513ExtInfo02]  
      @nMobile         INT,  
      @nFunc           INT,  
      @cLangCode       NVARCHAR( 3),  
      @nStep           INT,  
      @nInputKey       INT,  
      @cStorerKey      NVARCHAR( 15),  
      @cFacility       NVARCHAR(  5),  
      @tExtInfo       VariableTable READONLY,    
      @cExtendedInfo  NVARCHAR( 20) OUTPUT   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cSKU           NVARCHAR( 20)  
   DECLARE @cSUSR3         NVARCHAR( 20)  
  
   -- Variable mapping  
   SELECT @cSKU = Value FROM @tExtInfo WHERE Variable = '@cSKU'  
  
  
   IF @nStep in(3,10) -- SKU  
   BEGIN  
      IF @nInputKey = 1 -- Enter  
      BEGIN  
         SELECT @cSUSR3 = SUSR3  
         FROM dbo.SKU WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   SKU = @cSKU  
  
         SET @cExtendedInfo = @cSUSR3  
      END  
   END  
  
END  
GOTO Quit  
  
Quit:  

GO