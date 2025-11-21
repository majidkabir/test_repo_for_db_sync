SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************************************/
/* Store procedure: rdt_1764ExtInfo11                                                           */
/* Purpose: For configure on SMSS:                                                              */
/*          Tools->Options->Environment->Keyboard->Query Shortcut->                             */
/*          Ctrl+F1 = EXEC rdt.rdt_helptext                                                     */
/*                                                                                              */
/* Date         Author    Ver.  Purposes                                                        */
/* 2023-03-29   Ung       1.0   Created                                                         */
/************************************************************************************************/

CREATE   PROC [RDT].[rdt_helptext] (
   @cObjName SYSNAME
) AS
BEGIN
   IF OBJECT_ID( 'rdt.' + @cObjName) IS NOT NULL
      SET @cObjName = 'rdt.' + @cObjName
   ELSE IF OBJECT_ID( 'ptl.' + @cObjName) IS NOT NULL
      SET @cObjName = 'ptl.' + @cObjName
   
   EXEC sp_helptext @cObjName
END

GRANT EXEC ON rdt.rdt_helptext TO NSQL

GO