SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtGetMessage                                       */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2008-08-25 1.0  Shong    Created                                     */
/* 2005-05-19 1.1  Ung      SOS335126 "No Message Setup" include MsgID  */
/* 2016-07-05 1.2  ChewKP   Support MessageID 6 digit (ChewKP01)        */
/************************************************************************/

CREATE FUNCTION [RDT].[rdtGetMessage] (
  @nMsgID   INT, 
  @sLang    NVARCHAR(3) = 'ENG', 
  @sMsgType NVARCHAR(3) = 'DSP' 
) 
RETURNS NVARCHAR(200)
AS
BEGIN
	DECLARE @strout NVARCHAR (200) 

   SELECT @strout = Message_text 
   FROM rdt.rdtmsg WITH (NOLOCK)
   WHERE Message_id = @nMsgID 
      AND Message_type = @sMsgType 
      AND Lang_code = @sLang
   
   IF RTRIM(@strout) IS NULL
   BEGIN
      -- Default Lang Code ENG
      SELECT @strout = Message_text 
      FROM rdt.rdtmsg WITH (NOLOCK)
      WHERE Message_id = @nMsgID 
        AND Message_type = @sMsgType 
        AND Lang_code = 'ENG'
   END	
   
   -- All done
   IF RTRIM( @strout) = NULL OR RTRIM( @strout) = ''
      --SET @strout = 'Msg not setup(' + CAST( @nMsgID AS NVARCHAR(5)) + ')'
      SET @strout = 'Msg not setup(' + RIGHT( CAST( @nMsgID AS NVARCHAR(6)), 5) + ')' -- (ChewKP01)
         
   RETURN @strout
END

GO