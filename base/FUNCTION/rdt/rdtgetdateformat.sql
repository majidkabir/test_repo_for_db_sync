SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtGetDateFormat    					                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Get the date format of a SQL login, as per the default      */
/*          language of the login                                       */
/*          Note: it does not consider SET DATEFORMAT                   */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 2.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2005-11-17   dhung         Created                                   */
/* 2009-04-21   Vicky         Get dateformat from RDTUser, if no setup  */
/*                            then get from login (Vicky01)             */
/* 2009-10-09   James         Set default date format if no date        */
/*                            returned (james01)                        */
/* 2014-11-04   Ung           SOS317571 Fix dateformat is null when run */
/*                            from SQL studio without rdt.rdtUser       */
/* 2016-11-02   Ung           Clean up source                           */
/************************************************************************/

CREATE FUNCTION RDT.rdtGetDateFormat (
   @cLogin sysname
) RETURNS NVARCHAR( 3) AS
BEGIN
   DECLARE @cDateFormat NVARCHAR( 3)
   SET @cDateFormat = ''

   -- Parameter checking
   IF @cLogin = '' OR @cLogin IS NULL
      SET @cLogin = SYSTEM_USER -- Current login

   -- Get user date format
   SELECT @cDateFormat = ISNULL( Date_Format, '')
   FROM RDT.RDTUser WITH (NOLOCK)
   WHERE Username = @cLogin

   -- Get system date format
   IF @cDateFormat = ''
   BEGIN
      -- Get the dateformat from the login's default language
      SELECT @cDateFormat = l.dateformat
      FROM master.dbo.syslogins o (NOLOCK)
         INNER JOIN master.dbo.syslanguages l (NOLOCK) ON (o.language LIKE l.alias or o.language like l.name) 
      WHERE o.loginname = @cLogin
   END

   RETURN @cDateFormat
END

GO