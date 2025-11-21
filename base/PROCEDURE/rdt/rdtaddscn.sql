SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtScr2Script                                       */
/* Creation Date  :                                                     */
/* Copyright      : Maersk                                              */
/* Written By     : N/A                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 13-Oct-2023  1.2  JLC042     Add WebGroup                            */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtAddScn]
   @nScn             INT, 
   @cLang_Code       NVARCHAR( 3), 
   @cLine01          NVARCHAR( 125) = NULL, 
   @cLine02          NVARCHAR( 125) = NULL, 
   @cLine03          NVARCHAR( 125) = NULL, 
   @cLine04          NVARCHAR( 125) = NULL, 
   @cLine05          NVARCHAR( 125) = NULL, 
   @cLine06          NVARCHAR( 125) = NULL, 
   @cLine07          NVARCHAR( 125) = NULL, 
   @cLine08          NVARCHAR( 125) = NULL, 
   @cLine09          NVARCHAR( 125) = NULL, 
   @cLine10          NVARCHAR( 125) = NULL, 
   @cLine11          NVARCHAR( 125) = NULL, 
   @cLine12          NVARCHAR( 125) = NULL, 
   @cLine13          NVARCHAR( 125) = NULL, 
   @cLine14          NVARCHAR( 125) = NULL, 
   @cLine15          NVARCHAR( 125) = NULL,
   @nFunc            INT = 0, 
   @cShowOutput      NVARCHAR( 1) = '', 
   @cAutoDisappear   NVARCHAR( 10) = '',
   @cWebGroup        NVARCHAR( 255) = ''
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   -- Drop message to SQL
   IF EXISTS (SELECT Scn FROM rdt.RDTScn WHERE Scn = @nScn AND Lang_Code = @cLang_Code)
   BEGIN
      PRINT 'Screen ' + CAST( @nScn AS NVARCHAR( 5)) + ' already exists'
   END
   ELSE
   BEGIN
      INSERT INTO rdt.RDTScn ( 
         Scn, Lang_Code, Func, AutoDisappear, WebGroup,
         Line01, Line02, Line03, Line04, Line05, 
         Line06, Line07, Line08, Line09, Line10, 
         Line11, Line12, Line13, Line14, Line15) 
      VALUES ( 
         @nScn, @cLang_Code, @nFunc, @cAutoDisappear, @cWebGroup,
         @cLine01, @cLine02, @cLine03, @cLine04, @cLine05, 
         @cLine06, @cLine07, @cLine08, @cLine09, @cLine10, 
         @cLine11, @cLine12, @cLine13, @cLine14, @cLine15)
      
      EXEC [dbo].[isp_Trasnfer2NewScn] 
        @n_Scn = @nScn,
        @n_Func = 0 ,
        @c_ConverAll = '', 
        @c_ShowOutput = @cShowOutput

      EXEC [RDT].[rdtAddScnDetailWebGroup]
        @nScn = @nScn,
        @cLang_Code = @cLang_Code,
        @cWebGroup = @cWebGroup
   END

GO