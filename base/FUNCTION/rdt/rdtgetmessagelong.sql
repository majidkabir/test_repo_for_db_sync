SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtGetMessageLong                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2023-09-21 1.0  JLC042   Created                                     */
/************************************************************************/

CREATE   FUNCTION [RDT].[rdtGetMessageLong] (
  @nMsgID   INT, 
  @cLang    NVARCHAR(3) = 'ENG', 
  @cMsgType NVARCHAR(3) = 'DSP' 
) 
RETURNS NVARCHAR(250)
AS
BEGIN
	DECLARE @cMsg       NVARCHAR (125) = ''
   DECLARE @cMsgLong   NVARCHAR (250) = ''
   DECLARE @cReturnMsg NVARCHAR(250) = ''

   -- Local lang
   SELECT 
      @cMsg = Message_Text, 
      @cMsgLong = Message_Text_Long 
   FROM rdt.rdtMsg WITH (NOLOCK)
   WHERE Message_ID = @nMsgID 
      AND Message_Type = @cMsgType 
      AND Lang_Code = @cLang
   
   -- Not setup, default to ENG
   IF @@ROWCOUNT = 0 AND @cLang <> 'ENG'
      SELECT 
         @cMsg = Message_Text, 
         @cMsgLong = Message_Text_Long 
      FROM rdt.rdtMsg WITH (NOLOCK)
      WHERE Message_ID = @nMsgID 
         AND Message_Type = @cMsgType 
         AND Lang_Code = 'ENG'
   
   IF @cMsgLong <> ''
      SET @cReturnMsg = @cMsgLong
   ELSE IF @cMsg <> ''
      SET @cReturnMsg = @cMsg
   --ELSE
   --   SET @cReturnMsg = 'Msg not setup (' + CAST( @nMsgID AS NVARCHAR(6)) + ')'
   RETURN @cReturnMsg
END

GO