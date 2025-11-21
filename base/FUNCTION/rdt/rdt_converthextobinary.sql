SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_ConvertHexToBinary                                 */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:  Convert Hex to Binary                                         */
/*                                                                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2023-06-01 1.0  yeekung  WMS-22626 Created                               */
/***************************************************************************/

CREATE   FUNCTION [RDT].[rdt_ConvertHexToBinary] (
   @cHexString       NVARCHAR(1000)
)
RETURNS NVARCHAR(4000)  
AS
BEGIN

   DECLARE @binaryNumber NVARCHAR(4000)
   DECLARE @index INT = 1
   DECLARE @length INT = LEN(@cHexString)

   WHILE @index <= @length
   BEGIN
       DECLARE @char NVARCHAR(1) = SUBSTRING(@cHexString, @index, 1)
       DECLARE @charBinary VARCHAR(MAX) = ''

       DECLARE @charInt INT = UNICODE(@char)
       -- Handle special case for character 'A'
       IF @char = 'A'
       BEGIN
           SET @charBinary = '1010'
       END
       ELSE IF @char = 'B'
       BEGIN
           SET @charBinary = '1011'
       END
       ELSE IF @char = 'C'
       BEGIN
           SET @charBinary = '1100'
       END
       ELSE IF @char = 'D'
       BEGIN
           SET @charBinary = '1101'
       END
       ELSE IF @char = 'E'
       BEGIN
           SET @charBinary = '1110'
       END
       ELSE IF @char = 'F'
       BEGIN
           SET @charBinary = '1111'
       END
       ELSE
       BEGIN
           WHILE @charInt > 0
           BEGIN
               SET @charBinary = CONVERT(VARCHAR(1), @charInt % 2) + @charBinary
               SET @charInt = @charInt / 2
           END
       END

       SET @binaryNumber = @binaryNumber + RIGHT( @charBinary, 4)

       SET @index = @index + 1
   END

   RETURN @binaryNumber
END


GO