SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_ConvertBinaryToHex                                 */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:  Convert Binary to Hex                                         */
/*                                                                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2023-06-01 1.0  yeekung  WMS-22626 Created                               */
/***************************************************************************/

CREATE   FUNCTION [RDT].[rdt_ConvertBinaryToHex] (
   @cBinaryNumber       NVARCHAR(4000)
)RETURNS NVARCHAR(1000)  
AS
BEGIN

   DECLARE @Result NVARCHAR(1000);

   DECLARE @Index INT = 1;

   WHILE @Index <= LEN(@cBinaryNumber)
   BEGIN
       -- Extract the next 4 bits
       DECLARE @FourBits VARCHAR(4) = SUBSTRING(@cBinaryNumber, @Index, 4);

       -- Pad the four bits with leading zeros if necessary

       -- Multiply the decimal number by the corresponding power of 16 and add to the result
       SET @Result = @Result +   CASE @FourBits
                       WHEN '0000' THEN N'0'
                       WHEN '0001' THEN N'1'
                       WHEN '0010' THEN N'2'
                       WHEN '0011' THEN N'3'
                       WHEN '0100' THEN N'4'
                       WHEN '0101' THEN N'5'
                       WHEN '0110' THEN N'6'
                       WHEN '0111' THEN N'7'
                       WHEN '1000' THEN N'8'
                       WHEN '1001' THEN N'9'
                       WHEN '1010' THEN N'A'
                       WHEN '1011' THEN N'B'
                       WHEN '1100' THEN N'C'
                       WHEN '1101' THEN N'D'
                       WHEN '1110' THEN N'E'
                       WHEN '1111' THEN N'F'
                  END

       -- Decrement the index to move to the previous 4 bits
       SET @Index = @Index + 4;
   END
   RETURN @Result
END


GO