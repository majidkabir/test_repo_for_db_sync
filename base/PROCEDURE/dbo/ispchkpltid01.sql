SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispChkPltID01                                       */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Pallet ID format check                                      */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2013-09-26 1.0  James    Created                                     */   
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispChkPltID01]  
   @nMobile       INT,   
   @nFunc         INT,   
   @cLangCode     NVARCHAR(3),  
   @cID           NVARCHAR(18),  
   @nErrNo        INT            OUTPUT,   
   @cErrMsg       NVARCHAR(20)   OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   SET @nErrNo = 0
   
   IF LEN(RTRIM(@cID)) <> 10   
   BEGIN
      SET @nErrNo = 1  
      GOTO Quit
   END
   
   IF SUBSTRING( RTRIM(LTRIM(@cID)), 1, 1) <> 'P'
   BEGIN  
      SET @nErrNo = 1  
      GOTO Quit
   END  
QUIT:  
END -- End Procedure  

GO