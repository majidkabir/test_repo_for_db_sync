SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtGetExtraAttribute    					         */
/* Creation Date:                                                       */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Add extra paramater + value into XML                        */
/*                                                                      */
/*                                                                      */
/* Called By:      rdtScr2XMLHttp                                       */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Rev  Author     Purposes                                */
/* 2024-09-23   1.0  CYU027     Created                                 */
/* 2025-01-02   1.1  CYU027    FCR-1584                                 */
/************************************************************************/

CREATE   PROC RDT.rdtGetExtraAttribute (
    @nScn    INT
   ,@cY      NVARCHAR(2)
   ,@nMobile INT
   ,@cAttrAndVal NVARCHAR(max) OUTPUT
)
   AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE     @cStorerKey             NVARCHAR(15),
               @cAttribute             NVARCHAR(30),
               @cSValue                NVARCHAR( MAX),
               @cSValueSP              NVARCHAR( MAX),
               @cSQL                   NVARCHAR( Max),
               @cSQLParam              NVARCHAR( Max),
               @currentId              INT,
               @nFunc                  INT,
               @n_cnt                  INT

   -- INITIAL
   SET @cAttrAndVal = ''

   SELECT
      @nScn = Scn,
      @nFunc = Func,
      @cStorerKey = StorerKey
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   DECLARE @attributeAndValue TABLE
   (
      Id          INT IDENTITY(1,1) PRIMARY KEY,
      Attribute   NVARCHAR(30),
      SValue      NVARCHAR( MAX)
   );

   INSERT INTO @attributeAndValue (Attribute, SValue)
   SELECT Attribute, SValue
   FROM RDT.ScreenStorerConfig WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND Scn = @nScn
      AND line = CAST(@cY as INT)
      AND (Function_ID = @nFunc or Function_ID = 0)

   SELECT @n_cnt = @@ROWCOUNT
   IF @n_cnt <= 0
      GOTO Quit

   --Start Loop
   SET @currentId = @n_cnt

   WHILE (@currentId > 0)
   BEGIN

      SELECT @cAttribute   = ISNULL(Attribute,''),
             @cSValue      = ISNULL(SValue,''),
             @currentId    = ISNULL(Id, 0)
      FROM @attributeAndValue
      WHERE ID = @currentId

      SET @currentId = @currentId - 1

      --Nothing found, quit
      IF ISNULL(@cAttribute, '') = '' OR ISNULL(@cSValue, '') = ''
      BEGIN
         CONTINUE
      END

      /***********************************************************************************************
                                           Custom get AttrAndVal
      ***********************************************************************************************/

      -- Extended info

      IF @cSValue <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSValue AND type = 'P')
      BEGIN
         SET @cSValueSP = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSValue) +
                     ' @nMobile, @nFunc, @nScn, @cY, @cStorerKey, @cSValueSP OUTPUT '

         SET @cSQLParam =
                 '@nMobile          INT, ' +
                 '@nFunc            INT, ' +
                 '@nScn             INT, ' +
                 '@cY               NVARCHAR(2), ' +
                 '@cStorerKey       NVARCHAR( 15), '  +
                 '@cSValueSP        NVARCHAR( MAX) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nScn, @cY, @cStorerKey,
              @cSValueSP OUTPUT


         SET @cAttrAndVal = @cAttrAndVal + @cAttribute + '=''' + @cSValueSP + ''' '

      END
      ELSE
      BEGIN

         /***********************************************************************************************
                                   Standard get AttrAndVal
         ***********************************************************************************************/

         SET @cAttrAndVal = @cAttrAndVal + @cAttribute + '=''' + @cSValue + ''' '

      END

   END

   GOTO Quit

Quit:


GO