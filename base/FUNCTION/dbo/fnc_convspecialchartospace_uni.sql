SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Function:  fnc_ConvSpecialCharToSpace_uni                            */  
/* Creation Date: 29-Jan-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Convert Special Character to space.                         */  
/*                                                                      */  
/* Called By:  Any Stored Procedures.                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* DD-MMM-YYYY                                                          */  
/************************************************************************/  
  
CREATE FUNCTION [dbo].[fnc_ConvSpecialCharToSpace_uni] (@cString NVARCHAR(1024))  
RETURNS NVARCHAR(1024)  
AS  
BEGIN  
   DECLARE @cOutString   NVARCHAR(1024),  
           @nPosition    INT,  
           @cChar        NVARCHAR(1),  
           @cPrevChar    NVARCHAR(1),  
           @nNoOfSpace   INT,  
           @nDblByteChar INT  
  
   SET @nPosition = 1  
   SET @cOutString = ''  
   SET @cPrevChar = ''  
   SET @nNoOfSpace = 0  
   SET @nDblByteChar = 0 -- False  
  
   /* UNICODE Code:  
      124 - |  
       13 - Carrriage Return  
       10 - Line Feed  
        9 - Tab  
   */  
  
   WHILE @nPosition <= LEN(@cString)  
   BEGIN  
      SET @cChar = SUBSTRING(@cString, @nPosition, 1)  
  
      IF UNICODE(@cChar) BETWEEN 0 AND 127  
      BEGIN  
         IF UNICODE(@cChar) = 124 -- |  
         BEGIN  
            SET @cChar = REPLACE (UNICODE(@cChar), UNICODE(@cChar), ' ')  
         END  
  
         IF UNICODE(@cChar) = 63 -- ?  
         BEGIN  
            SET @cChar = REPLACE (UNICODE(@cChar), UNICODE(@cChar), ' ')  
         END  
  
         IF UNICODE(@cChar) = 13 OR UNICODE(@cChar) = 10 OR UNICODE(@cChar) = 9 -- Enter / Tab  
         BEGIN  
            SET @cChar = REPLACE (UNICODE(@cChar), UNICODE(@cChar), ' ')  
         END  
  
         IF @nDblByteChar = 1  
         BEGIN  
            SET @cOutString = RTRIM(@cOutString) + REPLICATE(CHAR(32), @nNoOfSpace) + @cPrevChar + @cChar  
            SET @cPrevChar = ''  
            SET @nDblByteChar = 0  
         END  
         ELSE  
         BEGIN  
            IF UNICODE(@cChar) = 32 -- Space  
            BEGIN  
               SET @nNoOfSpace = @nNoOfSpace + 1  
            END  
            ELSE  
            BEGIN  
               SET @cOutString = RTRIM(@cOutString) + REPLICATE(CHAR(32), @nNoOfSpace) + @cChar  
               SET @cPrevChar = ''  
               SET @nNoOfSpace = 0  
            END  
         END  
      END  
      ELSE  
      BEGIN  
         IF @nDblByteChar = 0  
         BEGIN  
            SET @nDblByteChar = 1  
            SET @cPrevChar = @cChar  
         END  
         ELSE  
         BEGIN  
            SET @cOutString = RTRIM(@cOutString) + REPLICATE(CHAR(32), @nNoOfSpace) + @cPrevChar + @cChar  
            SET @cPrevChar = ''  
            SET @nNoOfSpace = 0  
            SET @nDblByteChar = 0  
         END  
      END  
  
      SET @nPosition = @nPosition + 1  
   END  
  
   ReturnValue:  
   RETURN (@cOutString)  
END  

GO