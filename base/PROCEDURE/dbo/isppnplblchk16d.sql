SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispPnPLBLChk16d                                     */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Label No format check for label with 20 digits              */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2014-04-02 1.0  James    SOS307345 Created                           */   
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispPnPLBLChk16d]  
   @nMobile       INT,   
   @nFunc         INT,   
   @cLangCode     NVARCHAR(3),  
   @cLoadKey      NVARCHAR(10),  
   @cConsigneeKey NVARCHAR(15),  
   @cStorerKey    NVARCHAR(15),  
   @cSKU          NVARCHAR(20),  
   @cLabelNo      NVARCHAR(20),  
   @nErrNo        INT      OUTPUT,   
   @cErrMsg       NVARCHAR(20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @cSUSR1         NVARCHAR(20), 
           @cFacility      NVARCHAR(5)  
  
   IF LEN(RTRIM(@cLabelNo)) <> 16   
   BEGIN
      SET @nErrNo = 1  
      GOTO Quit
   END

   SELECT @cFacility = Facility 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   SELECT @cSUSR1 = ISNULL(UDF01, '') 
   FROM dbo.CODELKUP WITH (NOLOCK) 
   WHERE ListName = 'ITXWH'
   AND   Code = @cFacility
   AND StorerKey = @cStorerKey
   
   IF SUBSTRING( RTRIM(LTRIM(@cLabelNo)), 1, 4) <> RIGHT( '0000' + RTRIM(LTRIM(@cSUSR1)), 4) OR 
      SUBSTRING( RTRIM(LTRIM(@cLabelNo)), 5, 4) <> RIGHT( '0000' + RTRIM(LTRIM(@cConsigneeKey)), 4) 
   BEGIN  
      SET @nErrNo = 1  
      GOTO Quit
   END  
QUIT:  
END -- End Procedure  

GO