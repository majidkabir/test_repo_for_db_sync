SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/  
/* Copyright: Maersk                                                          */  
/*                                                                            */  
/* Purpose: Convert from rdt.scn to rdt.scndetail                             */  
/*                                                                            */  
/* Updates:                                                                   */  
/* Date         Author   Rev  Purposes                                        */  
/* 2023-09-22   YZH230   1.0  initial version                                 */  
/* 2023-10-27   JLC042   2.5  Optimization. Remove WebGroup                   */
/******************************************************************************/  

CREATE   PROC [RDT].[isp_GetFieldAttrs] (
   @cMsg         NVARCHAR(2048),
   @cDataType    NVARCHAR(15)     OUTPUT,
   @cFieldLabel  NVARCHAR(2048)   OUTPUT
   )
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @nDTPos INT = 0

   SET @cDataType = NULL
   SET @cFieldLabel = @cMsg

BEGIN TRY
   ---------^DT:datetime
   SET @nDTPos = CHARINDEX('^DT:', UPPER(@cMsg), 1)

   IF @nDTPos > 0
   BEGIN
      SET @cDataType = SUBSTRING(@cMsg, @nDTPos + 4, (LEN(@cMsg) + 1)  - @nDTPos - 4)
      SET @cFieldLabel = IIF(@nDTPos > 0, SUBSTRING(@cMsg, 1, @nDTPos - 1), @cMsg)
   END
END TRY

BEGIN CATCH
   SET @cDataType = NULL
   SET @cFieldLabel = @cMsg

END CATCH


RETURN
GO