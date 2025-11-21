SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtMsg2Script                                       */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Generate message script from database                       */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2012-04-28 1.0  Ung      Created                                     */
/* 2013-10-01 1.1  Ung      Support multi language                      */
/* 2014-01-08 1.2  KHLim    Use QUOTENAME function (KHLim01)            */
/* 2023-09-27 1.3  JLC042   Add Message Text Long Support               */
/************************************************************************/

CREATE   PROC [RDT].[rdtMsg2Script]
   @nMsgIDStart INT,
   @nMsgIDEnd   INT = 0,
   @nFuncID     INT = 0,
   @cLangCode   NVARCHAR( 3) = N'ENG'
AS
BEGIN
   IF @nMsgIDEnd = 0
      SET @nMsgIDEnd = @nMsgIDStart

   IF @nMsgIDStart <> @nMsgIDEnd
   BEGIN
      PRINT '-- ??'
      PRINT 'exec rdt.rdtDropMsg ' +
         CAST( @nMsgIDStart AS NVARCHAR(10) ) + ', ' +
         CAST( @nMsgIDEnd AS NVARCHAR(10) ) +
         CASE WHEN @cLangCode = 'ENG' THEN '' ELSE ', ''' + @cLangCode + '''' END
      PRINT ''
   END

   DECLARE @cMsgText        NVARCHAR(125)
   DECLARE @cMsgTextLong    NVARCHAR(250)
   DECLARE @nMsgFuncID      INT
   DECLARE @nMsgID          INT

   DECLARE curMsg CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT Message_ID, Message_Text, ISNULL( Func, 0), Message_Text_Long 
      FROM RDT.RDTMSG WITH (NOLOCK)
      WHERE Message_ID >= @nMsgIDStart
         AND Message_ID <= @nMsgIDEnd
         AND Lang_Code = @cLangCode
      ORDER BY Message_ID
   OPEN curMsg
   FETCH NEXT FROM curMsg INTO @nMsgID, @cMsgText, @nMsgFuncID, @cMsgTextLong
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Replace single quote with 2 single quote. Can't use QUOTENAME as it return maximum NVARCHAR( 258)
      IF @cMsgTextLong <> ''
         SET @cMsgTextLong = REPLACE( @cMsgTextLong, '''', '''''')

      IF @cMsgText <> '' OR @cMsgTextLong <> ''
      BEGIN
         PRINT 'execute rdt.rdtAddMsg ' +
            CAST( @nMsgID AS NVARCHAR(10) ) +
            ', 10, ' +
            'N' + QUOTENAME(LEFT( @cMsgText + SPACE(20), 20),'''') + ', ' +   --KHLim01
            'N''' + CASE WHEN @cLangCode = 'ENG' THEN 'us_english' ELSE @cLangCode END + ''' ' +
            CASE WHEN @nMsgFuncID <> 0 THEN ', ' + CAST( @nMsgFuncID AS NVARCHAR( 5))
                 WHEN @nFuncID <> 0 THEN ', ' + CAST( @nFuncID AS NVARCHAR( 5))
                 ELSE ''
            END + 
            ', @cMsgLong = N''' + @cMsgTextLong + ''''
      END
      FETCH NEXT FROM curMsg INTO @nMsgID, @cMsgText, @nMsgFuncID, @cMsgTextLong
   END
   CLOSE curMsg
   DEALLOCATE curMsg
END

GO