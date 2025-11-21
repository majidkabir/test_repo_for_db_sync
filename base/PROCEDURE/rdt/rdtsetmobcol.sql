SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtSetMobCol                                       */
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
/************************************************************************/

CREATE PROC [RDT].[rdtSetMobCol] (
@nMobile    int,
@cInMessage NVARCHAR(1024),
@nErrNo     int  OUTPUT,
@cErrMsg    NVARCHAR(1024) OUTPUT
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF
   
   DECLARE @iDoc int

   -- Create an internal representation of the XML document.
   EXEC sp_xml_preparedocument @iDoc OUTPUT, @cInMessage

   DECLARE @XML_Row Table(Respond NVARCHAR(10),
                          Col     NVARCHAR(20),
                          Value   NVARCHAR(60))

   DECLARE @ColName  NVARCHAR(20),
           @ColValue NVARCHAR(60),
           @cSQL     NVARCHAR(3072)

   -- Execute a SELECT statement that uses the OPENXML rowset provider.
   INSERT INTO @XML_Row
   SELECT  *
   FROM  OPENXML (@iDoc, '/fromRDT/input',2)
         WITH (respond NVARCHAR(10) '../@type',
               Col     NVARCHAR(20)    '@id',
               Value   NVARCHAR(60)   '@value')

   SELECT @ColName = '', @cSQL = ''

   WHILE 1 = 1
   BEGIN
      SET ROWCOUNT 1
   
      SELECT @ColName = Col,
             @ColValue = Value
      FROM   @XML_Row 
      WHERE  Respond = 'YES'
      AND    Col > @ColName
      ORDER BY Col
   
      IF @@ROWCOUNT = 0
         BREAK
   
      SET ROWCOUNT 0
      IF RTRIM(@cSQL) IS NULL OR RTRIM(@cSQL) = ''
         SELECT @cSQL = 'UPDATE RDT.RDTMOBREC SET I_' + RTRIM(@ColName) + ' = N''' + @ColValue + ''''
      ELSE
         SELECT @cSQL = RTRIM(@cSQL) + ', I_' + RTRIM(@ColName) + ' = N''' + @ColValue + ''''
   END


   IF RTRIM(@cSQL) IS NOT NULL AND RTRIM(@cSQL) <> ''
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' WHERE Mobile = ' + CAST(@nMobile as NVARCHAR(5))
   
      EXEC(@cSQL)
   END


   EXEC sp_xml_removedocument @iDoc

   SET ROWCOUNT 0

GO