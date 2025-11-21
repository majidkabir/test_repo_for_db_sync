SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Function: fnc_GetNumFromString                                             */
/* Creation Date: 21-Jun-2023                                                 */
/* Copyright: MAERSK                                                          */
/* Written by: NJOW                                                           */
/*                                                                            */
/* Purpose: WMS-22418 SG AESOP - Extract number from string and validate      */
/*                                                                            */
/* Input Parameters: input string                                             */
/*                                                                            */
/* Output Parameters: output string with numeric value only                   */
/*                                                                            */
/* Usage:                                                                     */
/*                                                                            */
/* Called By:                                                                 */
/*                                                                            */
/* Version: 1.0                                                               */    
/*                                                                            */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */
/* Date         Author     Ver   Purposes                                     */
/******************************************************************************/

CREATE    FUNCTION [dbo].[fnc_GetNumFromString] (@c_Input NVARCHAR(4000), @c_CustomOption NVARCHAR(30))
RETURNS NVARCHAR(4000)
AS
BEGIN
  DECLARE @n_AlphabetIndex INT, 
          @c_Result NVARCHAR(4000),
          @c_DateStr NVARCHAR(20), 
          @n_days INT = 0
  
  SET @c_Result = @c_Input
  
  SET @n_AlphabetIndex = PATINDEX('%[^0-9]%', @c_Result)
    
  WHILE @n_AlphabetIndex > 0
  BEGIN
     SET @c_Result = STUFF(@c_Result, @n_AlphabetIndex, 1, '')  
     SET @n_AlphabetIndex = PATINDEX('%[^0-9]%', @c_Result )  
  END  	
  
  IF @c_CustomOption = 'AESOP'
  BEGIN
  	SET @c_DateStr = SUBSTRING(@c_Result,5,2) + SUBSTRING(@c_Result,3,2) + SUBSTRING(@c_Result,1,2)
  	
  	IF ISDATE(@c_DateStr) <> 1
  	BEGIN
  		 SELECT @n_Days = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CAST(CL.Short AS INT) ELSE 0 END
  		 FROM CODELKUP CL (NOLOCK)
  		 WHERE CL.ListName = 'CUSTPARAM'
  		 AND CL.Code = 'SHELFLIFE'
  		 AND CL.Storerkey = @c_CustomOption
  		 
  		 SET @n_Days = @n_Days * -1
  		 
  		 SET @c_DateStr = CONVERT(NVARCHAR(10), DATEADD(day, @n_Days, GETDATE()) + 1, 12)
  	END
  	
  	SET @c_Result = @c_DateStr
  END
    
  RETURN @c_Result
END


GO