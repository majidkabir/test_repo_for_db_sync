SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispPnPLBLChk01                                      */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Label No format check                                       */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2013-08-27 1.0  James    SOS287522 Created                           */   
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispPnPLBLChk01]  
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
   /*
   SET @cSUSR1 = '' 
   SELECT @cSUSR1 = ISNULL(SUSR1, '') 
   FROM dbo.Storer WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   */
   
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