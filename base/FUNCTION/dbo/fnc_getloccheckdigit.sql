SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function       : fnc_GetLocCheckDigit                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Calculate Location 2 Numeric Check Digit                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2012-04-13   1.0  Shong      Created                                 */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_GetLocCheckDigit]   
(  
  @cLocationCode NVARCHAR(10) 
)  
RETURNS NVARCHAR(2)   
AS  
BEGIN  
   
   DECLARE @nTotal      INT
         , @nIdx        INT
         , @nASCIIValue INT
         , @nPrimeNo    INT
         , @nCheckDigit INT
         , @nLength     INT
         , @cLast2Digit NVARCHAR(2) 
         , @dResult     DECIMAL(15,2)
      
   SET @cLocationCode = UPPER(@cLocationCode) 
   SET @nTotal = 0

   SET @nLength = LEN(@cLocationCode)
   SET @nIdx = 1
   
   WHILE @nIdx <= @nLength
   BEGIN
      SET @nASCIIValue = ASCII(SUBSTRING(@cLocationCode ,@nIdx ,1)) 
      
      SET @nPrimeNo = 
         CASE @nIdx 
            WHEN 1  THEN 37
            WHEN 2  THEN 41
            WHEN 3  THEN 43
            WHEN 4  THEN 47
            WHEN 5  THEN 53
            WHEN 6  THEN 59
            WHEN 7  THEN 67
            WHEN 8  THEN 73
            WHEN 9  THEN 79
            WHEN 10 THEN 83
         END       
         
      SET @nTotal = @nTotal + (@nPrimeNo * @nASCIIValue)
      
      --SELECT @nTotal '@nTotal', @nASCIIValue '@nASCIIValue',  @nPrimeNo '@nPrimeNo', @nPrimeNo * @nASCIIValue '@nPrimeNo * @nASCIIValue'

      SET @nIdx = @nIdx + 1    
   END 
   
   SET @dResult = CAST((@nTotal / 97.000) AS DECIMAL(15,2))
 
    
   SET @cLast2Digit = RIGHT(RTRIM(CAST(@dResult as VARCHAR(20))),2)

   IF CAST( @cLast2Digit AS INT) > 97 
      SET @nCheckDigit = (97 * 2) - CAST( @cLast2Digit AS INT)
   ELSE
      SET @nCheckDigit = 97 - CAST( @cLast2Digit AS INT)
      

   RETURN  RIGHT(N'00' + CAST(@nCheckDigit AS VARCHAR(2)), 2)
END



GO