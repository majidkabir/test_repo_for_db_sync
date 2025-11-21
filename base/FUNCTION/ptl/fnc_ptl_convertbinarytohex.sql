SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [PTL].[fnc_PTL_ConvertBinaryToHex]
( @c_Binary VARCHAR(20) )
RETURNS NVARCHAR(10)
AS
BEGIN   
   DECLARE @c_HexDecimal VARCHAR(10)
           
   SELECT @c_HexDecimal = 
               CASE @c_Binary
                  WHEN '0000' THEN '0'
                  WHEN '0001' THEN '1'
                  WHEN '0010' THEN '2'
                  WHEN '0011' THEN '3'
                  WHEN '0100' THEN '4'
                  WHEN '0101' THEN '5'
                  WHEN '0110' THEN '6'
                  WHEN '0111' THEN '7'
                  WHEN '1000' THEN '8'
                  WHEN '1001' THEN '9'
                  WHEN '1010' THEN 'A'
                  WHEN '1011' THEN 'B'
                  WHEN '1100' THEN 'C'
                  WHEN '1101' THEN 'D'
                  WHEN '1110' THEN 'E'
                  WHEN '1111' THEN 'F'
                  ELSE ''
               END             

   RETURN @c_HexDecimal
END
   
GO