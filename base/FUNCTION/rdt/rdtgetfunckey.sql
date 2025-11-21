SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtGetFuncKey                                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-02-13 1.0  James      Get function key value                    */
/************************************************************************/

CREATE   Function [RDT].[rdtGetFuncKey] ( @cFunctionKey NVARCHAR( 3))
   RETURNS INT
AS
BEGIN
   IF @cFunctionKey = 'F1'
      RETURN 11

   IF @cFunctionKey = 'F2'
      RETURN 12

   IF @cFunctionKey = 'F3'
      RETURN 13

   IF @cFunctionKey = 'F4'
      RETURN 14

   RETURN 99   -- Return other value 1 (ENTER) & 0 (ESC)

END

GO