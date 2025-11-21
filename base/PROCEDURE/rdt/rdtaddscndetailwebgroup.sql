SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: rdtAddScnDetailWebGroup                                */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Date         Ver. Author   Purposes                                     */
/* 2023-10-12   1.0  JLC042   Add WebGroup to Screen Detail Table          */
/***************************************************************************/

CREATE   PROC [RDT].[rdtAddScnDetailWebGroup]
(
   @nScn       INT,
   @cLang_Code NVARCHAR( 3), 
   @cWebGroup  NVARCHAR(255) = ''
)
AS
BEGIN

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @WebGroupJson  TABLE (  
         [WebGroup] [NVARCHAR] (20) NULL DEFAULT '',
         [LineNo] INT  
        )  
  
SELECT @cWebGroup = WebGroup  
FROM   rdt.RDTScn WITH (NOLOCK)  
WHERE  Scn =@nScn  
   AND Lang_Code = @cLang_Code  
  
INSERT INTO @WebGroupJson  
SELECT j.[key] AS WebGroup, f.value AS [LineNo]  
FROM OPENJSON(@cWebGroup) AS j  
CROSS APPLY OPENJSON(j.value) AS f WHERE ISJSON(@cWebGroup) > 0  
  
UPDATE ScnDtl   
SET WebGroup = wg.WebGroup  
FROM [RDT].[RDTSCNDETAIL] ScnDtl  
INNER JOIN @WebGroupJson wg ON wg.[LineNo] = ScnDtl.YRow  
WHERE ScnDtl.Scn = @nScn   
   AND Lang_Code = @cLang_Code   
  
END  

SET QUOTED_IDENTIFIER OFF

GO