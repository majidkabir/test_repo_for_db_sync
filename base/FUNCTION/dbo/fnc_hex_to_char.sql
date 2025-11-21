SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Function:  Fnc_Hex_To_Char                                           */  
/* Creation Date: May 25, 2004                                          */  
/* Copyright:                                                           */  
/* Written by: Gregory A. Larsen                                        */  
/*                                                                      */  
/* Purpose:  This function will take any binary value and return the    */  
/*           hex value AS a character representation.                   */  
/*                                                                      */  
/* Input Parameters: - binary hex value                                 */  
/*                   - number of bytes to convert                       */  
/*                                                                      */  
/* Output Parameters: CHAR value                                        */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: - sp: usp_long_running_jobs                               */  
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
  
CREATE FUNCTION [dbo].[Fnc_Hex_To_Char] (  
   @x VARBINARY(100), -- binary hex value  
   @l INT             -- number of bytes  
) RETURNS VARCHAR(200)  
AS  
BEGIN  
   DECLARE @i      VARBINARY(10)  
   DECLARE @digits CHAR(16)  
  
   SET @digits = '0123456789ABCDEF'  
  
   DECLARE @s VARCHAR(100)  
   DECLARE @h VARCHAR(100)  
   DECLARE @j INT  
  
   SET @j = 0  
   SET @h = ''  
  
   -- process all  bytes  
   WHILE @j < @l  
   BEGIN  
      SET @j= @j + 1  
      -- get first character of byte  
      SET @i = SUBSTRING(CAST(@x AS VARBINARY(100)),@j,1)  
      -- get the first character  
      SET @s = CAST(SUBSTRING(@digits,@i%16+1,1) AS CHAR(1))  
      -- shift over one character  
      SET @i = @i/16  
      -- get the second character  
      SET @s = CAST(SUBSTRING(@digits,@i%16+1,1) AS CHAR(1)) + @s  
      -- build string of hex characters  
      SET @h = @h + @s  
   END  
   RETURN(@h)  
END

GO