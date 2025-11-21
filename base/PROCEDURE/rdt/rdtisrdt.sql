SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtIsRDT                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 26-10-2016   1.0           Changes for new JDBC drivers (ChewKP01)   */
/************************************************************************/

CREATE PROC [RDT].[rdtIsRDT] (
   @nIsRDT INT OUTPUT
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   IF APP_NAME()= 'Microsoft JDBC Driver for SQL Server' OR APP_NAME() = 'JTDS' -- (ChewKP01) 
      SET @nIsRDT = 1
   ELSE
      SET @nIsRDT = 0

   RETURN @nIsRDT
END

GO