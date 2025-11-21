SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1641CaptureInf01                                   */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2019-11-14 1.0  James   WMS-13606. Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_1641CaptureInf01](
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 5),
   @cType        NVARCHAR( 10),
   @cDropID      NVARCHAR( 20),
   @cDropLOC     NVARCHAR( 10),
   @cUCCNo       NVARCHAR( 20), 
   @cParam1      NVARCHAR( 20),
   @cParam2      NVARCHAR( 20),
   @cParam3      NVARCHAR( 20),
   @cParam4      NVARCHAR( 20),
   @cParam5      NVARCHAR( 10),
   @cOption      NVARCHAR( 1),
   @cData1       NVARCHAR( 60),
   @cData2       NVARCHAR( 60),
   @cData3       NVARCHAR( 60),
   @cData4       NVARCHAR( 60),
   @cData5       NVARCHAR( 60),
   @cOutField01  NVARCHAR( 20)  OUTPUT,
   @cOutField02  NVARCHAR( 60)  OUTPUT,
   @cOutField03  NVARCHAR( 20)  OUTPUT,
   @cOutField04  NVARCHAR( 60)  OUTPUT,
   @cOutField05  NVARCHAR( 20)  OUTPUT,
   @cOutField06  NVARCHAR( 60)  OUTPUT,
   @cOutField07  NVARCHAR( 20)  OUTPUT,
   @cOutField08  NVARCHAR( 60)  OUTPUT,
   @cOutField09  NVARCHAR( 20)  OUTPUT,
   @cOutField10  NVARCHAR( 60)  OUTPUT,
   @tCaptureVar  VariableTable  READONLY,
   @nAfterScn    INT            OUTPUT,
   @nAfterStep   INT            OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cNotes      NVARCHAR( 4000)
   DECLARE @cCode       NVARCHAR( 10)
   DECLARE @cLong       NVARCHAR( 20)
   DECLARE @nSeq        INT = 1
   DECLARE @curData     CURSOR
   DECLARE @cSQL        NVARCHAR( MAX) = ''
   DECLARE @cSQL1       NVARCHAR( MAX) = ''
   DECLARE @cSQLParam   NVARCHAR( MAX) = ''
   DECLARE @nTranCount  INT

   
   IF @cType = 'DISPLAY'
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @curData = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT c.Code, c.Notes
      FROM dbo.CODELKUP AS c WITH (NOLOCK)
      WHERE c.LISTNAME = 'RDTExtUpd'
      AND   c.Storerkey = @cStorerKey
      AND   c.code2 = @nFunc
      ORDER BY 1
      OPEN @curData
      FETCH NEXT FROM @curData INTO @cCode, @cNotes
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @nSeq = CAST( @cCode AS INT)
      
         IF ISNULL( @cNotes, '') <> ''
         BEGIN
            IF @nSeq = 1 SET @cOutField01 = SUBSTRING( @cNotes, 1, 20)
            IF @nSeq = 2 SET @cOutField03 = SUBSTRING( @cNotes, 1, 20)
            IF @nSeq = 3 SET @cOutField05 = SUBSTRING( @cNotes, 1, 20)
            IF @nSeq = 4 SET @cOutField07 = SUBSTRING( @cNotes, 1, 20)
            IF @nSeq = 5 SET @cOutField09 = SUBSTRING( @cNotes, 1, 20)
         END
      
         FETCH NEXT FROM @curData INTO @cCode, @cNotes
      END
   END
   
   IF @cType = 'UPDATE'
   BEGIN
      SET @nErrNo = 0

      IF @cData1 NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 153451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Wrong Plt Type 
         GOTO Quit
      END

      SET @cSQL = ' UPDATE dbo.Pallet SET '
      SET @curData = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT c.Code, c.Long
      FROM dbo.CODELKUP AS c WITH (NOLOCK)
      WHERE c.LISTNAME = 'RDTExtUpd'
      AND   c.Storerkey = @cStorerKey
      AND   c.code2 = @nFunc
      ORDER BY 1
      OPEN @curData
      FETCH NEXT FROM @curData INTO @cCode, @cLong
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @nSeq = CAST( @cCode AS INT)
      
         IF ISNULL( @cLong, '') <> ''
         BEGIN
            IF @nSeq = 1 SET @cSQL1 = @cSQL1 + CASE WHEN ISNULL( @cData1, '') = '' THEN '' ELSE RTRIM( @cLong) + ' = ''' + RTRIM( @cData1) + '''' + ', ' END 
            IF @nSeq = 2 SET @cSQL1 = @cSQL1 + CASE WHEN ISNULL( @cData2, '') = '' THEN '' ELSE RTRIM( @cLong) + ' = ''' + RTRIM( @cData2) + '''' + ', ' END
            IF @nSeq = 3 SET @cSQL1 = @cSQL1 + CASE WHEN ISNULL( @cData3, '') = '' THEN '' ELSE RTRIM( @cLong) + ' = ''' + RTRIM( @cData3) + '''' + ', ' END
            IF @nSeq = 4 SET @cSQL1 = @cSQL1 + CASE WHEN ISNULL( @cData4, '') = '' THEN '' ELSE RTRIM( @cLong) + ' = ''' + RTRIM( @cData4) + '''' + ', ' END
            IF @nSeq = 5 SET @cSQL1 = @cSQL1 + CASE WHEN ISNULL( @cData5, '') = '' THEN '' ELSE RTRIM( @cLong) + ' = ''' + RTRIM( @cData5) + '''' + ', ' END
         END
         
         FETCH NEXT FROM @curData INTO @cCode, @cLong
      END
      
      SET @cSQL1 = @cSQL1 + 'EditDate = GETDATE(), ' 
      SET @cSQL1 = @cSQL1 + 'EditWho = sUser_sName() '
         
      SET @cSQL = @cSQL + @cSQL1 + ' WHERE PalletKey = ''' + @cDropID + ''''
      SET @cSQL = @cSQL + ' SET @nErrNo = @@ERROR'
         
      SET @cSQLParam = '@nErrNo      INT = 0 OUTPUT'
      
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nErrNo OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 153452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd PltType Er
         GOTO Quit
      END
      
      IF @cData1 IN ( '1', '2')
         SET @nAfterStep = 5
      ELSE
         SET @nAfterStep = 1
   END
Quit:

END

GO