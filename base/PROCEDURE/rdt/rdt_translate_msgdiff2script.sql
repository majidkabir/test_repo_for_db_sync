SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Translate_MsgDiff2Script                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Generate message script from database                       */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2019-12-05 1.0  Chermaine      Created                               */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_Translate_MsgDiff2Script] 
@nFunc INT
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

SELECT 
   'execute rdt.rdtAddMsg ' + 
   CAST( EngMsg.Message_ID AS NVARCHAR( 10)) +
   ', 10, ' + 
   'N' + QUOTENAME(LEFT( EngMsg.Message_Text + SPACE(20), 20),'''') + ', ' +
   'N''' + CASE WHEN EngMsg.Lang_Code = 'ENG' THEN 'us_english' ELSE EngMsg.Lang_Code END + ''' ' +
   CASE WHEN EngMsg.Func <> 0 THEN ', ' + CAST( EngMsg.Func AS NVARCHAR( 5)) 
   ELSE ''
   END AS EngMsg
   ,OthMsg.OthMsg
FROM rdt.RDTMsg EngMsg (NOLOCK)
LEFT JOIN (SELECT Message_ID,
            'execute rdt.rdtAddMsg ' + 
            CAST( Message_ID AS NVARCHAR( 10)) +
            ', 10, ' + 
            'N' + QUOTENAME(LEFT( Message_Text + SPACE(20), 20),'''') + ', ' +
            'N''' + CASE WHEN Lang_Code = 'ENG' THEN 'us_english' ELSE Lang_Code END + ''' ' +
            CASE WHEN Func <> 0 THEN ', ' + CAST( Func AS NVARCHAR( 5)) 
            ELSE ''
            END AS OthMsg
          FROM rdt.RDTMsg OthMsg (NOLOCK)
           WHERE lang_code <>'ENG'
            AND Func=@nFunc ) OthMsg
on EngMsg.Message_ID = OthMsg.Message_ID
WHERE EngMsg.Func=@nFunc 
AND EngMsg.lang_code ='ENG'


GO