SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_ConvertBinaryToDec                                 */
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

CREATE   FUNCTION [RDT].[rdt_ConvertBinaryToDec] (
   @cBinaryNumber       NVARCHAR(4000)
)RETURNS BIGINT  
AS
BEGIN
   DECLARE @nBinPos INT = 1 -- Holds the value of the binary position
   DECLARE @Index INT = LEN(@cBinaryNumber) -- Holds the current binary position
   DECLARE @Result BIGINT  = 0 -- Accumulated decimal value

   WHILE @Index > 0
   BEGIN

      -- Add value of the current binary position to the decimal value.
      SET @Result = @Result + (CAST(SUBSTRING(@cBinaryNumber, @Index, 1) AS INT) * 
            @nBinPos)

      -- Go to next binary place and incease the value
      SET @Index = @Index - 1;
      SET @nBinPos = @nBinPos * 2

   END

   RETURN @Result
END


GO