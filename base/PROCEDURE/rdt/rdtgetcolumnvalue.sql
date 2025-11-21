SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure: rdtGetColumnValue                                        */
/* Creation Date: 10-Jul-2006                                                 */
/* Copyright: IDS                                                             */
/* Written by: Shong                                                          */
/*                                                                            */
/* Purpose: Is a Recursive SP that was calling by rdtScr2XML to               */
/*          retrieve the value for the column number.                         */
/*                                                                            */
/* Input Parameters: Mobile No                                                */
/*                   Column Name                                              */
/*                                                                            */
/* Output Parameters: Column Value                                            */
/*                                                                            */
/* Data Modifications:                                                        */
/* Date         Rev    Author    Purposes                                     */
/* 15-Aug-2016  1.1    Ung       Performance tuning for Nov 11                */
/******************************************************************************/
CREATE PROC [RDT].[rdtGetColumnValue]( 
   @nMobile    INT, 
   @cColName   NVARCHAR(30), 
   @cColValue  NVARCHAR(60) OUTPUT
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSQL      NVARCHAR( 200)
   DECLARE @cSQLParam NVARCHAR( 100)

   SET @cSQL = 
      ' SELECT @cColValue = ' + @cColName + 
      ' FROM rdt.rdtMobRec WITH (NOLOCK) ' +
      ' WHERE Mobile = @nMobile '

   SET @cSQLParam = 
      ' @nMobile   INT, ' + 
      ' @cColValue NVARCHAR(60) OUTPUT '

   EXEC sp_executesql @cSQL, @cSQLParam, @nMobile, @cColValue OUTPUT


GO