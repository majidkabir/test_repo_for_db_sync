SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Translate_ScnDiff2Script                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Generate message script from database                       */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2019-12-05 1.0  Chermaine      Created                               */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_Translate_ScnDiff2Script] @nFunc INT AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
@cFunc      NVARCHAR( 10),
@cScn       NVARCHAR( 5),
@clangcode  NVARCHAR( 3),
@cSQL       NVARCHAR( MAX)

--SET @nFunc = 838--867
SET @cFunc = CAST( @nFunc AS NVARCHAR( 10))

IF NOT EXISTS( SELECT 1 FROM rdt.RDTScn WHERE Func = @nFunc)
   BEGIN
      PRINT 'Function ' + @cFunc + ' not found'
      PRINT ''
      RETURN
   END

DECLARE CUR_Scn CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
            SELECT scn,Lang_Code  
            FROM rdt.RDTScn WITH (NOLOCK)   
            WHERE FUNC = @cFunc  
            

OPEN CUR_Scn  
      FETCH NEXT FROM CUR_Scn INTO @cScn,@clangcode 
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
      	SET @cSQL='Exec [RDT].[rdtScr2Script] '+@cScn+',N''' + @clangcode +''''
      	--SELECT @cSQL
      	EXEC sp_ExecuteSQL @cSQL

FETCH NEXT FROM CUR_Scn INTO @cScn,@clangcode 
      END  
      CLOSE CUR_Scn  
      DEALLOCATE CUR_Scn  


GO