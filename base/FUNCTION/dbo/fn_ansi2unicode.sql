SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store Procedure:  fn_ANSI2UNICODE                                    */  
/* Creation Date: 21-Nov-2008                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Michael Lam                                              */  
/*                                                                      */  
/* Purpose:  To convert string from Non-Unicode to Unicode              */  
/*              CHT = Chinese (Traditional)                             */  
/*              CHS = Chinese (Simplified)                              */  
/*              JPN = Japanese                                          */  
/*              KOR = Korean                                            */
/*              THI = Thailand                                          */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 08-Dec-2010  Shong     Added THI Unicode Support                     */
/************************************************************************/  
CREATE FUNCTION [dbo].[fn_ANSI2UNICODE] (  
   @c_Str      NVARCHAR(MAX),  
   @c_Lang     NVARCHAR(3) = 'CHT'  
)  
RETURNS NVARCHAR(MAX)  
AS  
BEGIN  
   DECLARE @result NVARCHAR(MAX)  
   DECLARE @tmpTable TABLE (  
      StrCHT NVARCHAR(MAX) COLLATE Chinese_Taiwan_Stroke_CI_AS NULL,  
      StrCHS NVARCHAR(MAX) COLLATE Chinese_PRC_CS_AS           NULL,  
      StrJPN NVARCHAR(MAX) COLLATE Japanese_CI_AS              NULL,  
      StrKOR NVARCHAR(MAX) COLLATE Korean_Wansung_CI_AS        NULL, 
      StrTHI NVARCHAR(MAX) COLLATE Thai_CI_AS                  NULL 
   );  
  
   IF @c_Lang = 'CHT'  
   BEGIN  
      INSERT INTO @tmpTable (StrCHT) VALUES(CONVERT(VARBINARY(MAX),@c_Str))  
      SELECT TOP 1 @result = StrCHT FROM @tmpTable  
   END  
   ELSE IF @c_Lang = 'CHS'  
   BEGIN  
      INSERT INTO @tmpTable (StrCHS) VALUES(CONVERT(VARBINARY(MAX),@c_Str))  
      SELECT TOP 1 @result = StrCHS FROM @tmpTable  
   END  
   ELSE IF @c_Lang = 'JPN'  
   BEGIN  
      INSERT INTO @tmpTable (StrJPN) VALUES(CONVERT(VARBINARY(MAX),@c_Str))  
      SELECT TOP 1 @result = StrJPN FROM @tmpTable  
   END  
   ELSE IF @c_Lang = 'KOR'  
   BEGIN  
      INSERT INTO @tmpTable (StrKOR) VALUES(CONVERT(VARBINARY(MAX),@c_Str))  
      SELECT TOP 1 @result = StrKOR FROM @tmpTable  
   END  
   ELSE IF @c_Lang = 'THI'  
   BEGIN  
      INSERT INTO @tmpTable (StrTHI) VALUES(CONVERT(VARBINARY(MAX),@c_Str))  
      SELECT TOP 1 @result = StrTHI FROM @tmpTable  
   END    
   ELSE  
   BEGIN  
      SET @result = @c_Str  
   END  
  
   RETURN @result  
END  


GO