SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : ispPrimaryKeyColumns                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Finds the name and column id of primary key columns for     */
/*          a table.                                                    */
/*                                                                      */
/* Input Parameters: The name of the table                              */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: nsp_Build_Insert                                          */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*                                                                      */
/************************************************************************/
CREATE PROC [dbo].[ispPrimaryKeyColumns] (	@sysTableName 	sysname )
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
		SELECT  c.name, c.colid
		FROM    sysindexes i
		INNER JOIN dbo.sysobjects t ON i.id = t.id
		INNER JOIN sysindexkeys k ON i.indid = k.indid AND i.id = k.ID
		INNER JOIN syscolumns c ON c.id = t.id AND c.colid = k.colid
		WHERE  i.id = t.id
		 AND   i.indid BETWEEN 1 And 254 
		 AND   (i.status & 2048) = 2048
		 AND   t.id = OBJECT_ID(@sysTableName)
		ORDER BY k.KeyNo

END

GO